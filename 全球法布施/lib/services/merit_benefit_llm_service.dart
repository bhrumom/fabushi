import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/merit_benefit.dart';
import 'qwen_inference_service.dart';

/// 功德利益 LLM 识别服务
/// 
/// 使用 Qwen 模型直接识别经文中的功德利益句子。
/// 模型输出位置索引，程序根据索引提取原文。
/// 
/// 核心优势：
/// - 减少 token 输出：`[[0,45],[120,180]]` 比完整句子文本短 10 倍
/// - 避免文本变形：模型不需要复述原文，用索引精确提取
/// - 程序易解析：标准 JSON 格式
class MeritBenefitLLMService {
  static MeritBenefitLLMService? _instance;
  static MeritBenefitLLMService get instance => _instance ??= MeritBenefitLLMService._();
  MeritBenefitLLMService._();

  final _inference = QwenInferenceService.instance;
  
  // 结果缓存（基于段落哈希）
  final _cache = <int, List<MeritBenefitSentence>>{};
  static const _maxCacheSize = 200;

  /// 是否模型已就绪
  bool get isModelReady => _inference.isInitialized;

  /// Prompt 模板 - 要求模型输出位置索引
  static const _systemPrompt = '''你是佛经专家。分析经文段落，找出描述功德利益的句子位置。
功德利益句是描述修行、诵经、持咒等能获得的好处、福报、功德的句子。

严格按以下 JSON 格式输出：
- 如果找到功德利益句，输出: [[起始字符索引,结束字符索引],[起始,结束],...]
- 如果没有找到，输出: null

示例输入: "南无阿弥陀佛。诵此咒能灭无量罪业。观音菩萨慈悲。"
示例输出: [[7,16]]

只输出 JSON，不要其他文字。''';

  /// 识别单个段落的功德利益句（带缓存）
  /// 
  /// [paragraph] 段落文本
  /// [paragraphIndex] 段落在全文中的索引
  /// 
  /// 返回该段落中的功德利益句子列表
  Future<List<MeritBenefitSentence>> recognizeParagraph(
    String paragraph, 
    int paragraphIndex,
  ) async {
    if (paragraph.trim().isEmpty) return [];
    
    final hash = paragraph.hashCode;
    
    // 检查缓存
    if (_cache.containsKey(hash)) {
      debugPrint('📿 MeritBenefitLLM: 缓存命中 paragraph=$paragraphIndex');
      return _cache[hash]!;
    }
    
    // 检查模型状态
    if (!_inference.isInitialized) {
      debugPrint('📿 MeritBenefitLLM: 模型未就绪，跳过识别');
      return [];
    }
    
    try {
      debugPrint('📿 MeritBenefitLLM: 开始识别段落 $paragraphIndex (${paragraph.length}字)');
      
      final prompt = '$_systemPrompt\n\n经文段落:\n$paragraph';
      final response = await _inference.generate(prompt);
      
      // 解析模型输出的位置索引
      final sentences = _parsePositions(response.trim(), paragraph, paragraphIndex);
      
      // 更新缓存
      _updateCache(hash, sentences);
      
      debugPrint('📿 MeritBenefitLLM: 段落 $paragraphIndex 识别完成，找到 ${sentences.length} 个功德利益句');
      return sentences;
    } catch (e) {
      debugPrint('📿 MeritBenefitLLM: 识别失败: $e');
      return [];
    }
  }

  /// 解析模型输出的位置索引
  List<MeritBenefitSentence> _parsePositions(
    String output, 
    String paragraph, 
    int paragraphIndex,
  ) {
    // 清理输出（移除可能的 markdown 代码块标记）
    String cleanOutput = output.trim();
    if (cleanOutput.startsWith('```')) {
      cleanOutput = cleanOutput.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleanOutput = cleanOutput.replaceFirst(RegExp(r'\n?```$'), '');
      cleanOutput = cleanOutput.trim();
    }
    
    // 处理 null 或空输出
    if (cleanOutput == 'null' || cleanOutput.isEmpty || cleanOutput == '无') {
      return [];
    }
    
    try {
      // 解析 JSON 数组 [[start,end],[start,end],...]
      final dynamic positions = jsonDecode(cleanOutput);
      if (positions == null) return [];
      if (positions is! List) return [];
      
      final sentences = <MeritBenefitSentence>[];
      for (final pos in positions) {
        if (pos is List && pos.length >= 2) {
          final start = (pos[0] as num).toInt();
          final end = (pos[1] as num).toInt();
          
          // 边界校验
          if (start >= 0 && end <= paragraph.length && start < end) {
            final text = paragraph.substring(start, end);
            sentences.add(MeritBenefitSentence(
              text: text,
              paragraphIndex: paragraphIndex,
              startOffset: start,
              endOffset: end,
            ));
          } else {
            debugPrint('📿 MeritBenefitLLM: 位置越界 [$start,$end], 段落长度=${paragraph.length}');
          }
        }
      }
      return sentences;
    } catch (e) {
      debugPrint('📿 MeritBenefitLLM: JSON解析失败: $e, output="$cleanOutput"');
      return [];
    }
  }

  /// 批量识别多个段落（懒加载用）
  /// 
  /// 返回一个 Stream，每识别完一个段落就 yield 结果
  Stream<MeritBenefitParagraphResult> recognizeParagraphsStream(
    List<String> paragraphs, {
    int startIndex = 0,
  }) async* {
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraphIndex = startIndex + i;
      
      // 先 yield loading 状态
      yield MeritBenefitParagraphResult(
        paragraphIndex: paragraphIndex,
        sentences: const [],
        isLoading: true,
        isReady: false,
      );
      
      // 识别
      final sentences = await recognizeParagraph(paragraphs[i], paragraphIndex);
      
      // yield 完成状态
      yield MeritBenefitParagraphResult(
        paragraphIndex: paragraphIndex,
        sentences: sentences,
        isLoading: false,
        isReady: true,
      );
    }
  }

  /// 预热：提前识别指定段落
  Future<void> prefetch(List<String> paragraphs, {int startIndex = 0}) async {
    for (int i = 0; i < paragraphs.length; i++) {
      await recognizeParagraph(paragraphs[i], startIndex + i);
    }
  }

  /// 更新缓存（LRU）
  void _updateCache(int hash, List<MeritBenefitSentence> sentences) {
    if (_cache.length >= _maxCacheSize) {
      // 移除最老的缓存
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[hash] = sentences;
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
    debugPrint('📿 MeritBenefitLLM: 缓存已清除');
  }
}
