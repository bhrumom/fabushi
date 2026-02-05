import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:global_dharma_sharing/services/qwen_model_manager.dart';
import 'package:global_dharma_sharing/services/qwen_inference_service.dart';

/// 语义优先服务 - Qwen 模型 + 规则引擎混合架构
/// 
/// 跨平台统一架构（替代原 TFLite + macOS Natural Language）：
/// - 所有平台统一使用 Qwen 2.5 1.5B 模型（GGUF 格式）
/// - 模型首次使用时从 HuggingFace 下载
/// - 规则引擎作为模型未就绪时的降级方案
/// 
/// 混合架构：
/// 1. 快速路径：预编译正则表达式 O(n) 匹配
/// 2. 精确路径：Qwen 模型推理（语义相似度）
/// 3. 后台处理：不阻塞UI线程
/// 4. LRU缓存：避免重复计算
class SemanticNlpService {
  static SemanticNlpService? _instance;
  static SemanticNlpService get instance => _instance ??= SemanticNlpService._();
  SemanticNlpService._();

  // Qwen 模型服务
  final _modelManager = QwenModelManager.instance;
  final _inference = QwenInferenceService.instance;
  
  // 模型状态
  bool _qwenModelReady = false;
  bool _isInitializing = false;
  Completer<bool>? _initCompleter;
  
  /// 模型下载进度回调
  void Function(double progress)? onModelDownloadProgress;
  
  /// 是否模型已就绪
  bool get isModelReady => _qwenModelReady;
  
  /// 是否正在下载模型
  bool get isDownloadingModel => _modelManager.isDownloading;
  
  /// 等待模型就绪
  /// 
  /// 返回 true 表示模型已就绪，false 表示初始化失败
  Future<bool> waitForReady() async {
    if (_qwenModelReady) return true;
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return await _initCompleter!.future;
    }
    return false;
  }
  
  // LRU缓存
  final _cache = <int, List<_ScoredSentence>>{};
  static const _maxCacheSize = 100;

  // =====================================================
  // 第一性原理：预编译单一正则表达式，实现 O(n) 匹配
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

  // 预编译正则表达式
  static final _semanticPattern = RegExp(
    '(${[
      ..._meritKeywords,
      ..._benefitKeywords,
      ..._praiseKeywords,
      ..._dharmaKeywords,
    ].join('|')})',
  );

  static final _meritSet = Set<String>.from(_meritKeywords);
  static final _benefitSet = Set<String>.from(_benefitKeywords);
  static final _praiseSet = Set<String>.from(_praiseKeywords);
  static final _dharmaSet = Set<String>.from(_dharmaKeywords);
  
  /// 功德利益锚点句（用于计算语义相似度）
  static const _meritAnchorSentence = '获得无量功德福报，消除一切业障罪障，速得解脱成佛';

  /// 初始化服务
  /// 
  /// [downloadModelIfNeeded] 是否在初始化时下载模型（默认 true）
  Future<void> initialize({bool downloadModelIfNeeded = true}) async {
    if (_isInitializing) {
      // 如果正在初始化，等待完成
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        await _initCompleter!.future;
      }
      return;
    }
    _isInitializing = true;
    _initCompleter = Completer<bool>();

    try {
      debugPrint('📖 SemanticNlpService: 开始初始化 Qwen 模型...');
      
      // 检查模型是否已下载
      final modelAvailable = await _modelManager.isModelAvailable();
      
      if (modelAvailable) {
        // 模型已存在，直接加载
        await _loadQwenModel();
        _initCompleter!.complete(_qwenModelReady);
      } else if (downloadModelIfNeeded) {
        // 模型不存在，需要下载并等待完成
        debugPrint('📖 SemanticNlpService: 模型未下载，开始下载...');
        await _downloadAndLoadModel();
        _initCompleter!.complete(_qwenModelReady);
      } else {
        debugPrint('📖 SemanticNlpService: 模型未下载，使用规则引擎模式');
        _qwenModelReady = false;
        _initCompleter!.complete(false);
      }
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 初始化异常: $e');
      _qwenModelReady = false;
      _initCompleter!.complete(false);
    } finally {
      _isInitializing = false;
    }
  }
  
  /// 下载并加载模型（后台执行）
  Future<void> _downloadAndLoadModel() async {
    try {
      final modelPath = await _modelManager.ensureModelAvailable(
        onProgress: (progress) {
          onModelDownloadProgress?.call(progress);
          if ((progress * 100).toInt() % 10 == 0) {
            debugPrint('📖 SemanticNlpService: 模型下载进度 ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
      );
      
      await _inference.initialize(modelPath);
      _qwenModelReady = true;
      debugPrint('📖 SemanticNlpService: Qwen 模型加载成功');
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 模型下载/加载失败: $e');
      _qwenModelReady = false;
    }
  }
  
  /// 加载 Qwen 模型
  Future<void> _loadQwenModel() async {
    try {
      final modelPath = await _modelManager.modelPath;
      await _inference.initialize(modelPath);
      _qwenModelReady = true;
      debugPrint('📖 SemanticNlpService: Qwen 模型加载成功');
    } catch (e) {
      debugPrint('📖 SemanticNlpService: Qwen 模型加载失败: $e');
      _qwenModelReady = false;
    }
  }
  
  /// 手动触发模型下载
  Future<void> downloadModel({void Function(double)? onProgress}) async {
    await _modelManager.ensureModelAvailable(onProgress: onProgress);
    await _loadQwenModel();
  }

  /// 语义优先排序（异步后台执行）
  Future<List<String>> sortBySemanticPriority(List<String> sentences) async {
    if (sentences.isEmpty) return sentences;
    if (sentences.length == 1) return sentences;

    final hash = sentences.join().hashCode;
    if (_cache.containsKey(hash)) {
      debugPrint('📖 SemanticNlpService: 缓存命中');
      return _cache[hash]!.map((s) => s.text).toList();
    }

    List<_ScoredSentence> scored;
    
    if (_qwenModelReady) {
      // 使用 Qwen 模型进行语义分析
      scored = await _analyzeSentencesWithQwen(sentences);
    } else {
      // 降级：使用纯规则引擎
      scored = await compute(_analyzeSentencesWithRules, sentences);
    }

    _updateCache(hash, scored);

    debugPrint('📖 SemanticNlpService: 排序完成，高优先句数: ${scored.where((s) => s.score > 2.0).length}/${scored.length}');

    return scored.map((s) => s.text).toList();
  }
  
  /// 使用 Qwen 模型分析句子
  Future<List<_ScoredSentence>> _analyzeSentencesWithQwen(List<String> sentences) async {
    final scored = <_ScoredSentence>[];
    
    // 获取锚点句的嵌入向量
    List<double>? anchorEmbedding;
    try {
      anchorEmbedding = await _inference.getEmbedding(_meritAnchorSentence);
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 获取锚点嵌入失败: $e');
    }
    
    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      
      // 基础分：规则引擎
      double score = _calculateRuleScore(sentence);
      
      // 进阶分：Qwen 语义相似度
      if (anchorEmbedding != null) {
        try {
          final embedding = await _inference.getEmbedding(sentence);
          final similarity = _cosineSimilarity(embedding, anchorEmbedding);
          
          // 根据相似度加分
          if (similarity > 0.8) {
            score += 3.0;
          } else if (similarity > 0.7) {
            score += 2.0;
          } else if (similarity > 0.6) {
            score += 1.0;
          }
        } catch (e) {
          // 忽略推理错误，使用规则分数
        }
      }
      
      scored.add(_ScoredSentence(
        text: sentence,
        score: score,
        originalIndex: i,
      ));
    }
    
    // 排序
    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.originalIndex.compareTo(b.originalIndex);
    });
    
    return scored;
  }

  /// 处理并排序超长文本
  Future<List<String>> processAndSortLargeText(String rawText) async {
    if (rawText.isEmpty) return [];

    final hash = rawText.hashCode;
    if (_cache.containsKey(hash)) {
      return _cache[hash]!.map((s) => s.text).toList();
    }

    debugPrint('📖 SemanticNlpService: 开始处理大文本...');
    
    // 分句
    final parts = rawText.split(RegExp(r'[。！？\n]+'));
    final sentences = <String>[];
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty && RegExp(r'[\u4e00-\u9fff\u3400-\u4dbfa-zA-Z0-9]').hasMatch(t)) {
        sentences.add(t);
      }
    }
    
    return sortBySemanticPriority(sentences);
  }

  Future<List<String>> getPrioritySentences(List<String> sentences, {int limit = 5}) async {
    final sorted = await sortBySemanticPriority(sentences);
    return sorted.take(limit).toList();
  }

  void _updateCache(int hash, List<_ScoredSentence> scored) {
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[hash] = scored;
  }

  void clearCache() {
    _cache.clear();
  }
  
  /// 释放资源
  void dispose() {
    _inference.dispose();
    _qwenModelReady = false;
  }
  
  /// 计算余弦相似度
  double _cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) return 0.0;
    double dot = 0.0;
    double mag1 = 0.0;
    double mag2 = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dot += v1[i] * v2[i];
      mag1 += v1[i] * v1[i];
      mag2 += v2[i] * v2[i];
    }
    if (mag1 == 0 || mag2 == 0) return 0.0;
    return dot / (math.sqrt(mag1) * math.sqrt(mag2));
  }
  
  /// 规则引擎计算分数
  double _calculateRuleScore(String sentence) {
    double score = 0.0;
    int matchCount = 0;

    final matches = _semanticPattern.allMatches(sentence);
    for (final match in matches) {
      final keyword = match.group(0)!;
      matchCount++;
      if (_meritSet.contains(keyword)) {
        score += 3.0;
      } else if (_benefitSet.contains(keyword)) {
        score += 2.5;
      } else if (_praiseSet.contains(keyword)) {
        score += 2.0;
      } else if (_dharmaSet.contains(keyword)) {
        score += 1.5;
      }
    }

    if (matchCount > 1) score *= 1.0 + (matchCount - 1) * 0.2;
    
    final length = sentence.length;
    if (length < 10) score *= 0.8;
    else if (length > 50) score *= 0.9;

    return score;
  }
}

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

// -----------------------------------------------------------
// Isolate 逻辑（纯规则引擎，用于降级模式）
// -----------------------------------------------------------

List<_ScoredSentence> _analyzeSentencesWithRules(List<String> sentences) {
  final scored = <_ScoredSentence>[];

  for (int i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    double score = 0.0;
    int matchCount = 0;

    final matches = SemanticNlpService._semanticPattern.allMatches(sentence);
    for (final match in matches) {
      final keyword = match.group(0)!;
      matchCount++;
      if (SemanticNlpService._meritSet.contains(keyword)) {
        score += 3.0;
      } else if (SemanticNlpService._benefitSet.contains(keyword)) {
        score += 2.5;
      } else if (SemanticNlpService._praiseSet.contains(keyword)) {
        score += 2.0;
      } else if (SemanticNlpService._dharmaSet.contains(keyword)) {
        score += 1.5;
      }
    }

    if (matchCount > 1) score *= 1.0 + (matchCount - 1) * 0.2;
    
    final length = sentence.length;
    if (length < 10) score *= 0.8;
    else if (length > 50) score *= 0.9;

    scored.add(_ScoredSentence(
      text: sentence,
      score: score,
      originalIndex: i,
    ));
  }

  // 排序
  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.originalIndex.compareTo(b.originalIndex);
  });

  return scored;
}
