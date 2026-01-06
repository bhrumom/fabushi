import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/merit_benefit.dart';
import '../models/sutra_table_of_contents.dart';
import 'semantic_nlp_service.dart';

/// 功德利益识别服务
/// 
/// 封装 SemanticNlpService，提供经文功德利益句子提取功能
class MeritBenefitService {
  static MeritBenefitService? _instance;
  static MeritBenefitService get instance => _instance ??= MeritBenefitService._();
  MeritBenefitService._();

  final SemanticNlpService _nlpService = SemanticNlpService.instance;
  
  // 结果缓存（避免重复分析）
  final _cache = <int, MeritBenefitData>{};
  
  /// 功德利益相关的核心关键词（用于句子筛选）
  static const _meritKeywords = [
    '功德', '福德', '福报', '福慧', '善根', '善业',
    '灭罪', '消业', '除障', '离苦', '解脱', '往生', '成佛',
    '善报', '福田', '增益', '加持', '护佑', '灭除',
    '能除', '能灭', '能消', '能得', '能令', '能使',
    '悉皆', '一切', '无量', '不可思议', '无边', '无数',
    '速得', '即得', '当得', '必得', '皆得',
  ];
  
  static final _meritPattern = RegExp(_meritKeywords.join('|'));
  
  /// 分数阈值：只有得分高于此值的句子才被视为功德利益句
  static const _scoreThreshold = 2.0;

  /// 初始化服务
  Future<void> initialize() async {
    await _nlpService.initialize();
  }

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
    
    debugPrint('📿 MeritBenefitService: 开始提取功德利益句子...');
    
    // 1. 分句（与 SemanticNlpService 保持一致）
    final paragraphs = fullText.split(RegExp(r'[\n]+'));
    final sentences = <_RawSentence>[];
    
    for (int pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final paragraph = paragraphs[pIdx].trim();
      if (paragraph.isEmpty) continue;
      
      // 按句号、感叹号、问号分割
      final parts = paragraph.split(RegExp(r'[。！？]'));
      for (final part in parts) {
        final text = part.trim();
        if (text.isEmpty) continue;
        
        // 预筛选：只保留包含功德关键词的句子
        if (_meritPattern.hasMatch(text)) {
          sentences.add(_RawSentence(text: text, paragraphIndex: pIdx));
        }
      }
    }
    
    debugPrint('📿 MeritBenefitService: 预筛选得到 ${sentences.length} 个候选句子');
    
    if (sentences.isEmpty) {
      final result = MeritBenefitData.empty;
      _cache[hash] = result;
      return result;
    }
    
    // 2. 使用 NLP 服务排序
    final textList = sentences.map((s) => s.text).toList();
    final sortedTexts = await _nlpService.sortBySemanticPriority(textList);
    
    // 3. 计算每个句子的分数（基于排序位置）
    final textToScore = <String, double>{};
    for (int i = 0; i < sortedTexts.length; i++) {
      // 排名越靠前分数越高
      final score = (sortedTexts.length - i) / sortedTexts.length * 5.0;
      textToScore[sortedTexts[i]] = score;
    }
    
    // 4. 构建功德利益句子列表
    final meritSentences = <MeritBenefitSentence>[];
    for (final raw in sentences) {
      final score = textToScore[raw.text] ?? 0.0;
      if (score < _scoreThreshold) continue;
      
      // 查找所属章节
      final chapter = toc.getCurrentChapter(raw.paragraphIndex);
      
      meritSentences.add(MeritBenefitSentence(
        text: raw.text,
        score: score,
        paragraphIndex: raw.paragraphIndex,
        chapter: chapter,
      ));
    }
    
    // 5. 按分数降序排序
    meritSentences.sort((a, b) => b.score.compareTo(a.score));
    
    // 6. 按章节分组
    final byChapter = <SutraChapter?, List<MeritBenefitSentence>>{};
    for (final sentence in meritSentences) {
      byChapter.putIfAbsent(sentence.chapter, () => []).add(sentence);
    }
    
    debugPrint('📿 MeritBenefitService: 提取完成，共 ${meritSentences.length} 个功德利益句子，分布在 ${byChapter.length} 个章节');
    
    final result = MeritBenefitData(
      sentences: meritSentences,
      byChapter: byChapter,
    );
    
    _cache[hash] = result;
    return result;
  }
  
  /// 清除缓存
  void clearCache() {
    _cache.clear();
    _nlpService.clearCache();
  }
}

/// 原始句子（内部使用）
class _RawSentence {
  final String text;
  final int paragraphIndex;
  
  const _RawSentence({
    required this.text,
    required this.paragraphIndex,
  });
}
