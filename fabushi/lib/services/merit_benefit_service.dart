import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/merit_benefit.dart';
import '../models/sutra_table_of_contents.dart';
import 'merit_benefit_llm_service.dart';

/// 功德利益识别服务
/// 
/// 封装 MeritBenefitLLMService，提供经文功德利益句子提取功能。
/// 使用 LLM 模型识别功德利益句子，返回带位置信息的结果。
class MeritBenefitService {
  static MeritBenefitService? _instance;
  static MeritBenefitService get instance => _instance ??= MeritBenefitService._();
  MeritBenefitService._();

  final MeritBenefitLLMService _llmService = MeritBenefitLLMService.instance;
  
  // 结果缓存（避免重复分析）
  final _cache = <int, MeritBenefitData>{};
  
  /// 是否模型已就绪
  bool get isModelReady => _llmService.isModelReady;

  /// 从经文全文中提取功德利益句子
  /// 
  /// [fullText] 经文全文
  /// [toc] 经文目录结构
  Future<MeritBenefitData> extractFromText(
    String fullText,
    SutraTableOfContents toc,
  ) async {
    final hash = fullText.hashCode;
    
    // 检查缓存
    if (_cache.containsKey(hash)) {
      debugPrint('📿 MeritBenefitService: 缓存命中');
      return _cache[hash]!;
    }
    
    // 检查模型状态
    if (!_llmService.isModelReady) {
      debugPrint('📿 MeritBenefitService: 模型未就绪，返回空结果');
      return MeritBenefitData.empty;
    }
    
    debugPrint('📿 MeritBenefitService: 开始使用 LLM 提取功德利益句子...');
    
    // 1. 分段
    final paragraphs = fullText.split(RegExp(r'[\n]+'));
    final validParagraphs = <_IndexedParagraph>[];
    
    for (int pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final paragraph = paragraphs[pIdx].trim();
      if (paragraph.isNotEmpty) {
        validParagraphs.add(_IndexedParagraph(text: paragraph, index: pIdx));
      }
    }
    
    debugPrint('📿 MeritBenefitService: 共 ${validParagraphs.length} 个段落待分析');
    
    // 2. 使用 LLM 服务识别每个段落
    final allSentences = <MeritBenefitSentence>[];
    
    for (final para in validParagraphs) {
      final sentences = await _llmService.recognizeParagraph(para.text, para.index);
      
      // 为每个句子添加章节信息
      for (final sentence in sentences) {
        final chapter = toc.getCurrentChapter(para.index);
        allSentences.add(MeritBenefitSentence(
          text: sentence.text,
          paragraphIndex: sentence.paragraphIndex,
          startOffset: sentence.startOffset,
          endOffset: sentence.endOffset,
          chapter: chapter,
        ));
      }
    }
    
    // 3. 按章节分组
    final byChapter = <SutraChapter?, List<MeritBenefitSentence>>{};
    for (final sentence in allSentences) {
      byChapter.putIfAbsent(sentence.chapter, () => []).add(sentence);
    }
    
    debugPrint('📿 MeritBenefitService: LLM 提取完成，共 ${allSentences.length} 个功德利益句子，分布在 ${byChapter.length} 个章节');
    
    final result = MeritBenefitData(
      sentences: allSentences,
      byChapter: byChapter,
    );
    
    _cache[hash] = result;
    return result;
  }
  
  /// 清除缓存
  void clearCache() {
    _cache.clear();
    _llmService.clearCache();
  }
}

/// 带索引的段落（内部使用）
class _IndexedParagraph {
  final String text;
  final int index;
  
  const _IndexedParagraph({
    required this.text,
    required this.index,
  });
}

