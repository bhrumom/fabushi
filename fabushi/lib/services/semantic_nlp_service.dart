import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:global_dharma_sharing/services/llm_model_manager.dart';
import 'package:global_dharma_sharing/services/llm_inference_service.dart';
import 'package:global_dharma_sharing/services/llm_model_config.dart';
import 'package:global_dharma_sharing/services/app_settings.dart';

/// 语义优先服务 - AI问书共用 LLM 模型 + 规则引擎混合架构
///
/// 跨平台统一架构：
/// - 与 AI 问书共用用户选择的 LLM 模型
/// - 规则引擎作为模型未就绪时的降级方案
///
/// 混合架构：
/// 1. 快速路径：预编译正则表达式 O(n) 匹配
/// 2. 精确路径：模型推理（基于占位或模型的语义相似度）
/// 3. 后台处理：不阻塞UI线程
/// 4. LRU缓存：避免重复计算
class SemanticNlpService {
  static SemanticNlpService? _instance;
  static SemanticNlpService get instance =>
      _instance ??= SemanticNlpService._();
  SemanticNlpService._();

  // 统一 LLM 模型服务
  final _modelManager = LLMModelManager.instance;
  final _inference = LLMInferenceService.instance;

  // 模型状态
  bool _llmModelReady = false;
  bool _isInitializing = false;
  Completer<bool>? _initCompleter;

  /// 模型下载进度回调
  void Function(double progress)? onModelDownloadProgress;

  /// 是否模型已就绪
  bool get isModelReady => _llmModelReady;

  /// 是否正在下载模型
  bool get isDownloadingModel => _modelManager.isDownloading;

  /// 获取当前选择的模型类型（与 AI 问书一致）
  Future<LLMModelType?> _getSelectedModelType() async {
    final downloadedModels = await _modelManager.getDownloadedModels();
    final savedModelName = await AppSettings.getSelectedModelName();

    if (savedModelName != null) {
      try {
        final type = LLMModelType.values.firstWhere(
          (t) => t.name == savedModelName,
        );
        if (downloadedModels.contains(type)) {
          return type;
        }
      } catch (_) {}
    }

    final isMobile = Platform.isAndroid || Platform.isIOS;
    final platformModels = LLMModelConfig.getChatModelsForPlatform(
      isMobile: isMobile,
    );
    final platformModelTypes = platformModels.map((c) => c.type).toSet();

    final chatModels = downloadedModels
        .where((t) => platformModelTypes.contains(t))
        .toList();
    if (chatModels.isNotEmpty) {
      return chatModels.first;
    }

    return platformModels.isNotEmpty ? platformModels.first.type : null;
  }

  /// 等待模型就绪
  ///
  /// 返回 true 表示模型已就绪，false 表示初始化失败
  Future<bool> waitForReady() async {
    if (_llmModelReady) return true;
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
    '功德',
    '福德',
    '福报',
    '福慧',
    '善根',
    '善业',
    '灭罪',
    '消业',
    '除障',
    '离苦',
    '解脱',
    '往生',
    '成佛',
    '善报',
    '福田',
    '增益',
    '加持',
    '护佑',
    '灭除',
  ];

  /// 利益描述类关键词（中高权重 = 2.5）
  static const _benefitKeywords = [
    '能除',
    '能灭',
    '能消',
    '能得',
    '能令',
    '能使',
    '悉皆',
    '一切',
    '无量',
    '不可思议',
    '无边',
    '无数',
    '速得',
    '即得',
    '当得',
    '必得',
    '皆得',
  ];

  /// 赞扬赞叹类关键词（中权重 = 2.0）
  static const _praiseKeywords = [
    '希有',
    '善哉',
    '难得',
    '殊胜',
    '微妙',
    '清净',
    '威神',
    '神力',
    '庄严',
    '圆满',
    '广大',
    '甚深',
    '第一',
    '无上',
    '最胜',
    '真实',
    '究竟',
  ];

  /// 佛法宝类关键词（低权重 = 1.5）
  static const _dharmaKeywords = [
    '如来',
    '世尊',
    '菩萨',
    '般若',
    '涅槃',
    '真言',
    '陀罗尼',
    '三昧',
    '菩提',
    '法门',
  ];

  // 预编译正则表达式
  static final _semanticPattern = RegExp(
    '(${[..._meritKeywords, ..._benefitKeywords, ..._praiseKeywords, ..._dharmaKeywords].join('|')})',
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
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        await _initCompleter!.future;
      }
      return;
    }
    _isInitializing = true;
    _initCompleter = Completer<bool>();

    try {
      debugPrint('📖 SemanticNlpService: 开始初始化 LLM 模型...');

      final modelType = await _getSelectedModelType();
      if (modelType == null) {
        debugPrint('📖 SemanticNlpService: 无法确定模型类型，降级为规则引擎');
        _llmModelReady = false;
        _initCompleter!.complete(false);
        return;
      }

      final modelAvailable = await _modelManager.isModelAvailable(modelType);

      if (modelAvailable) {
        await _loadLLMModel(modelType);
        _initCompleter!.complete(_llmModelReady);
      } else if (downloadModelIfNeeded) {
        debugPrint('📖 SemanticNlpService: 模型未下载，开始下载...');
        await _downloadAndLoadModel(modelType);
        _initCompleter!.complete(_llmModelReady);
      } else {
        debugPrint('📖 SemanticNlpService: 模型未下载，使用规则引擎模式');
        _llmModelReady = false;
        _initCompleter!.complete(false);
      }
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 初始化异常: $e');
      _llmModelReady = false;
      _initCompleter!.complete(false);
    } finally {
      _isInitializing = false;
    }
  }

  /// 下载并加载模型（后台执行）
  Future<void> _downloadAndLoadModel(LLMModelType type) async {
    try {
      final modelPath = await _modelManager.ensureModelAvailable(
        type,
        onProgress: (progress, stage) {
          onModelDownloadProgress?.call(progress);
          if ((progress * 100).toInt() % 10 == 0) {
            debugPrint(
              '📖 SemanticNlpService: 模型下载进度 ${(progress * 100).toStringAsFixed(0)}% [$stage]',
            );
          }
        },
      );

      await _inference.initialize(modelPath);
      _llmModelReady = true;
      debugPrint('📖 SemanticNlpService: LLM 模型加载成功');
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 模型下载/加载失败: $e');
      _llmModelReady = false;
    }
  }

  /// 加载 LLM 模型
  Future<void> _loadLLMModel(LLMModelType type) async {
    try {
      if (_inference.isInitialized) {
        _llmModelReady = true;
        return;
      }
      final modelPath = await _modelManager.getModelPath(type);
      await _inference.initialize(modelPath);
      _llmModelReady = true;
      debugPrint('📖 SemanticNlpService: LLM 模型加载成功');
    } catch (e) {
      debugPrint('📖 SemanticNlpService: LLM 模型加载失败: $e');
      _llmModelReady = false;
    }
  }

  /// 手动触发模型下载
  Future<void> downloadModel({void Function(double)? onProgress}) async {
    final modelType = await _getSelectedModelType();
    if (modelType == null) return;
    await _modelManager.ensureModelAvailable(
      modelType,
      onProgress: (progress, stage) => onProgress?.call(progress),
    );
    await _loadLLMModel(modelType);
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

    if (_llmModelReady) {
      scored = await _analyzeSentencesWithLLM(sentences);
    } else {
      scored = await compute(_analyzeSentencesWithRules, sentences);
    }

    _updateCache(hash, scored);

    debugPrint(
      '📖 SemanticNlpService: 排序完成，高优先句数: ${scored.where((s) => s.score > 2.0).length}/${scored.length}',
    );

    return scored.map((s) => s.text).toList();
  }

  /// 获取占位语义嵌入向量
  List<double> _getEmbedding(String text) {
    return _generatePlaceholderEmbedding(text);
  }

  /// 占位嵌入生成（基于关键词的简单向量）
  List<double> _generatePlaceholderEmbedding(String text) {
    // 生成简单的特征向量（64维）
    final embedding = List<double>.filled(64, 0.0);

    // 关键词特征
    for (int i = 0; i < _meritKeywords.length && i < 32; i++) {
      if (text.contains(_meritKeywords[i])) {
        embedding[i] = 1.0;
      }
    }

    for (int i = 0; i < _benefitKeywords.length && i < 32; i++) {
      if (text.contains(_benefitKeywords[i])) {
        embedding[32 + i] = 1.0;
      }
    }

    // 归一化
    double mag = 0.0;
    for (final v in embedding) {
      mag += v * v;
    }
    if (mag > 0) {
      mag = math.sqrt(mag);
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= mag;
      }
    }

    return embedding;
  }

  /// 使用 LLM 模型分析句子
  Future<List<_ScoredSentence>> _analyzeSentencesWithLLM(
    List<String> sentences,
  ) async {
    final scored = <_ScoredSentence>[];

    // 获取锚点句的嵌入向量
    List<double>? anchorEmbedding;
    try {
      anchorEmbedding = _getEmbedding(_meritAnchorSentence);
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 获取锚点嵌入失败: $e');
    }

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];

      // 基础分：规则引擎
      double score = _calculateRuleScore(sentence);

      // 进阶分：伪语义相似度
      if (anchorEmbedding != null) {
        try {
          final embedding = _getEmbedding(sentence);
          final similarity = _cosineSimilarity(embedding, anchorEmbedding);

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

      scored.add(
        _ScoredSentence(text: sentence, score: score, originalIndex: i),
      );
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
      if (t.isNotEmpty &&
          RegExp(r'[\u4e00-\u9fff\u3400-\u4dbfa-zA-Z0-9]').hasMatch(t)) {
        sentences.add(t);
      }
    }

    return sortBySemanticPriority(sentences);
  }

  Future<List<String>> getPrioritySentences(
    List<String> sentences, {
    int limit = 5,
  }) async {
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
    _llmModelReady = false;
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
    if (length < 10)
      score *= 0.8;
    else if (length > 50)
      score *= 0.9;

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
    if (length < 10)
      score *= 0.8;
    else if (length > 50)
      score *= 0.9;

    scored.add(_ScoredSentence(text: sentence, score: score, originalIndex: i));
  }

  // 排序
  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.originalIndex.compareTo(b.originalIndex);
  });

  return scored;
}
