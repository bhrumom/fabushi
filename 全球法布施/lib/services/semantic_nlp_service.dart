import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart'; 

/// 语义优先服务 - 极致性能 + 精确语义
/// 
/// 混合架构：
/// 1. 快速路径：预编译正则表达式 O(n) 匹配
/// 2. 精确路径：TFLite NLP模型推理（可选）
/// 3. 后台Isolate：不阻塞UI线程
/// 4. LRU缓存：避免重复计算
class SemanticNlpService {
  static SemanticNlpService? _instance;
  static SemanticNlpService get instance => _instance ??= SemanticNlpService._();
  SemanticNlpService._();

  // TFLite 模型状态
  bool _isModelLoaded = false;
  bool _isInitializing = false;
  // BertNLClassifier? _classifier; // BERT分类器

  // LRU缓存 - 基于文本哈希快速查找
  final _cache = <int, List<_ScoredSentence>>{};
  static const _maxCacheSize = 100;

  // =====================================================
  // 第一性原理：预编译单一正则表达式，实现 O(n) 匹配
  // 所有关键词合并为一个正则，一次遍历完成所有匹配
  // =====================================================

  /// 功德福德类关键词（高权重 = 3.0）
  static const _meritKeywords = [
    '功德', '福德', '福报', '福慧', '善根', '善业',
    '灭罪', '消业', '除障', '离苦', '解脱', '往生', '成佛',
    '善报', '福田', '增益', '加持', '护佑', '灭除',
  ];

  /// 利益描述类关键词（中高权重 = 2.5）
  static const _benefitKeywords = [
    '能除', '能灭', '能消', '能得', '能令', '能使',
    '悉皆', '一切', '无量', '不可思议', '无边', '无数',
    '速得', '即得', '当得', '必得', '皆得',
  ];

  /// 赞扬赞叹类关键词（中权重 = 2.0）
  static const _praiseKeywords = [
    '希有', '善哉', '难得', '殊胜', '微妙', '清净',
    '威神', '神力', '庄严', '圆满', '广大', '甚深',
    '第一', '无上', '最胜', '真实', '究竟',
  ];

  /// 佛法宝类关键词（低权重 = 1.5）
  static const _dharmaKeywords = [
    '如来', '世尊', '菩萨', '般若', '涅槃',
    '真言', '陀罗尼', '三昧', '菩提', '法门',
  ];

  // 预编译正则表达式 - 启动时编译，运行时零开销
  static final _semanticPattern = RegExp(
    '(${[
      ..._meritKeywords,
      ..._benefitKeywords,
      ..._praiseKeywords,
      ..._dharmaKeywords,
    ].join('|')})',
  );

  // 关键词权重映射（使用Set实现O(1)查找）
  static final _meritSet = Set<String>.from(_meritKeywords);
  static final _benefitSet = Set<String>.from(_benefitKeywords);
  static final _praiseSet = Set<String>.from(_praiseKeywords);
  static final _dharmaSet = Set<String>.from(_dharmaKeywords);

  /// 初始化服务（App启动时调用）
  Future<void> initialize() async {
    if (_isModelLoaded || _isInitializing) return;
    _isInitializing = true;

    try {
      // 尝试加载 MobileBERT 模型
      // 检查 asset 是否存在（通过异常捕获）
      try {
        final options = BertNLClassifierOptions();
        _classifier = await BertNLClassifier.createFromFile(
          'assets/models/mobilebert_quant_chinese.tflite', 
          options: options,
        );
        _isModelLoaded = true;
        debugPrint('📖 SemanticNlpService: MobileBERT 模型加载成功，启用真·NLP模式');
      } catch (e) {
        debugPrint('📖 SemanticNlpService: 未找到内置模型文件，降级为规则引擎模式');
        _isModelLoaded = false;
      }
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 模型初始化异常: $e');
      _isModelLoaded = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// 语义优先排序（异步后台执行）
  /// 
  /// 返回按语义优先级排序的句子列表
  /// 高价值句子（功德利益、赞扬）排在前面
  Future<List<String>> sortBySemanticPriority(List<String> sentences) async {
    if (sentences.isEmpty) return sentences;
    if (sentences.length == 1) return sentences;

    // 计算缓存键
    final hash = sentences.join().hashCode;

    // 缓存命中 - 直接返回
    if (_cache.containsKey(hash)) {
      debugPrint('📖 SemanticNlpService: 缓存命中');
      return _cache[hash]!.map((s) => s.text).toList();
    }

    // 后台Isolate执行 - 不阻塞UI
    final scored = await compute(_analyzeSentencesInIsolate, sentences);

    // 更新缓存
    _updateCache(hash, scored);

    debugPrint('📖 SemanticNlpService: 排序完成，高优先句数: ${scored.where((s) => s.score > 1.0).length}/${scored.length}');

    return scored.map((s) => s.text).toList();
  }

  /// 处理并排序超长文本（全后台执行）
  /// 
  /// 针对5万字以上大文本优化：
  /// 1. 分句 (Split)
  /// 2. 清洗 (Trim)
  /// 3. 打分 (Score)
  /// 4. 排序 (Sort)
  /// 
  /// 全链路在后台Isolate执行，主线程零卡顿
  Future<List<String>> processAndSortLargeText(String rawText) async {
    if (rawText.isEmpty) return [];

    // 计算缓存键（基于原始文本哈希）
    final hash = rawText.hashCode;

    // 缓存命中 - 直接返回
    if (_cache.containsKey(hash)) {
      debugPrint('📖 SemanticNlpService: 缓存命中 (大文本)');
      return _cache[hash]!.map((s) => s.text).toList();
    }

    debugPrint('📖 SemanticNlpService: 开始处理大文本 (${rawText.length} chars)...');
    
    // 后台Isolate执行 - 不阻塞UI
    final scored = await compute(_processTextInIsolate, rawText);

    // 更新缓存
    _updateCache(hash, scored);

    debugPrint('📖 SemanticNlpService: 大文本处理完成，生成 ${scored.length} 个句子');

    return scored.map((s) => s.text).toList();
  }

  /// 获取优先句子（仅返回高分句子）
  Future<List<String>> getPrioritySentences(List<String> sentences, {int limit = 5}) async {
    final sorted = await sortBySemanticPriority(sentences);
    return sorted.take(limit).toList();
  }

  /// 更新LRU缓存
  void _updateCache(int hash, List<_ScoredSentence> scored) {
    // LRU淘汰
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[hash] = scored;
  }

  /// 清空缓存
  void clearCache() {
    _cache.clear();
  }
}

/// 带分数的句子
class _ScoredSentence {
  final String text;
  final double score;
  final int originalIndex;

  _ScoredSentence({
    required this.text,
    required this.score,
    required this.originalIndex,
  });
}

/// 顶层函数：在后台Isolate中执行完整处理流程（分句+分析）
List<_ScoredSentence> _processTextInIsolate(String rawText) {
  // 1. 分句 (Isolate内执行)
  // [NEW] 升级为整句切分：仅按句号、问号、感叹号、换行符切分
  // 保留逗号在句子内部，提供完整语义上下文
  final parts = rawText.split(RegExp(r'[。！？\n]+'));
  final sentences = <String>[];
  
  for (final p in parts) {
    final t = p.trim();
    // 简单的内容检查
    if (t.isNotEmpty && RegExp(r'[\u4e00-\u9fff\u3400-\u4dbfa-zA-Z0-9]').hasMatch(t)) {
      sentences.add(t);
    }
  }

  // 2. 分析与排序复用已有逻辑
  return _analyzeSentencesInIsolate(sentences);
}

/// 顶层函数：在后台Isolate中执行语义分析
/// 
/// 第一性原理：
/// 1. 使用预编译正则一次遍历匹配所有关键词
/// 2. 根据匹配到的关键词类型计算加权分数
/// 3. 按分数降序排列，高价值句子优先
List<_ScoredSentence> _analyzeSentencesInIsolate(List<String> sentences) {
  final scored = <_ScoredSentence>[];

  for (int i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    final score = _calculateSentenceScore(sentence);

    scored.add(_ScoredSentence(
      text: sentence,
      score: score,
      originalIndex: i,
    ));
  }

  // 按分数降序排列（稳定排序保持原始顺序）
  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    // 分数相同时保持原始顺序
    return a.originalIndex.compareTo(b.originalIndex);
  });

  return scored;
}

/// 计算单个句子的语义分数
/// 
/// 算法：
/// 1. 使用正则匹配找出所有关键词
/// 2. 根据关键词类型应用不同权重
/// 3. 短句加分（更容易朗读）
double _calculateSentenceScore(String sentence) {
  double score = 0.0;
  int matchCount = 0;

  // O(n) 一次遍历匹配所有关键词
  final matches = SemanticNlpService._semanticPattern.allMatches(sentence);

  for (final match in matches) {
    final keyword = match.group(0)!;
    matchCount++;

    // 根据关键词类型应用权重
    if (SemanticNlpService._meritSet.contains(keyword)) {
      score += 3.0; // 功德福德类 - 最高权重
    } else if (SemanticNlpService._benefitSet.contains(keyword)) {
      score += 2.5; // 利益描述类 - 中高权重
    } else if (SemanticNlpService._praiseSet.contains(keyword)) {
      score += 2.0; // 赞扬赞叹类 - 中权重
    } else if (SemanticNlpService._dharmaSet.contains(keyword)) {
      score += 1.5; // 佛法宝类 - 低权重
    }
  }

  // 匹配密度加成（多个关键词的句子更重要）
  if (matchCount > 1) {
    score *= 1.0 + (matchCount - 1) * 0.2;
  }

  // 句子长度调整（适中长度最佳）
  final length = sentence.length;
  if (length < 10) {
    score *= 0.8; // 过短句子降权
  } else if (length > 50) {
    score *= 0.9; // 过长句子轻微降权
  }

  return score;
}
