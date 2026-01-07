import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:global_dharma_sharing/services/nlp/bert_tokenizer.dart';

// TFLite (iOS/Android)
import 'package:tflite_flutter/tflite_flutter.dart';

/// 语义优先服务 - 极致性能 + 精确语义
/// 
/// 跨平台架构：
/// - iOS/Android: TFLite 模型推理 + 规则引擎
/// - macOS: 原生 Natural Language 框架（通过 MethodChannel）+ 规则引擎
/// 
/// 混合架构：
/// 1. 快速路径：预编译正则表达式 O(n) 匹配
/// 2. 精确路径：模型推理（语义相似度）
/// 3. 后台Isolate：不阻塞UI线程
/// 4. LRU缓存：避免重复计算
class SemanticNlpService {
  static SemanticNlpService? _instance;
  static SemanticNlpService get instance => _instance ??= SemanticNlpService._();
  SemanticNlpService._();

  // 模型状态
  bool _useModel = false;
  bool _isInitializing = false;
  
  // macOS MethodChannel
  static const _macOsChannel = MethodChannel('com.fabushi.app/semantic_nlp');
  bool _macOsNlpInitialized = false;
  
  /// 是否是 macOS 平台
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  
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

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      if (_isMacOS) {
        // macOS: 使用原生 Natural Language 框架
        await _initializeMacOsNlp();
      } else {
        // iOS/Android: 使用 TFLite
        await _initializeTFLite();
      }
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 初始化异常: $e');
      _useModel = false;
    } finally {
      _isInitializing = false;
    }
  }
  
  /// 初始化 macOS 原生 NLP
  Future<void> _initializeMacOsNlp() async {
    try {
      final result = await _macOsChannel.invokeMethod<bool>('initialize');
      _macOsNlpInitialized = result ?? false;
      _useModel = _macOsNlpInitialized;
      debugPrint('📖 SemanticNlpService: macOS 原生 NLP 初始化${_macOsNlpInitialized ? "成功" : "失败"}');
    } catch (e) {
      debugPrint('📖 SemanticNlpService: macOS NLP 初始化失败: $e');
      _macOsNlpInitialized = false;
      _useModel = false;
    }
  }
  
  /// 初始化 TFLite (iOS/Android)
  Future<void> _initializeTFLite() async {
    try {
      await rootBundle.load('assets/models/mobilebert_quant_chinese.tflite');
      await rootBundle.load('assets/models/vocab.txt');
      _useModel = true;
      debugPrint('📖 SemanticNlpService: TFLite 模型文件检查通过');
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 未找到 TFLite 模型文件，降级为规则引擎模式');
      _useModel = false;
    }
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
    
    if (_isMacOS && _macOsNlpInitialized) {
      // macOS: 使用原生 Natural Language 框架
      scored = await _analyzeSentencesWithMacOsNlp(sentences);
    } else {
      // iOS/Android: 使用 Isolate + TFLite
      final params = _ComputeParams(
        sentences: sentences,
        useModel: _useModel && !_isMacOS,
      );
      scored = await compute(_analyzeSentencesInIsolate, params);
    }

    _updateCache(hash, scored);

    debugPrint('📖 SemanticNlpService: 排序完成，高优先句数: ${scored.where((s) => s.score > 2.0).length}/${scored.length}');

    return scored.map((s) => s.text).toList();
  }
  
  /// 使用 macOS 原生 NLP 分析句子
  Future<List<_ScoredSentence>> _analyzeSentencesWithMacOsNlp(List<String> sentences) async {
    try {
      final result = await _macOsChannel.invokeMethod<List>('analyzeSentences', {
        'sentences': sentences,
      });
      
      if (result != null) {
        return result.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return _ScoredSentence(
            text: map['text'] as String,
            score: (map['score'] as num).toDouble(),
            originalIndex: map['originalIndex'] as int,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('📖 SemanticNlpService: macOS NLP 分析失败: $e');
    }
    
    // 降级：使用纯规则引擎
    final scored = <_ScoredSentence>[];
    for (int i = 0; i < sentences.length; i++) {
      scored.add(_ScoredSentence(
        text: sentences[i],
        score: _calculateRuleScore(sentences[i]),
        originalIndex: i,
      ));
    }
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
    if (_isMacOS && _macOsNlpInitialized) {
      _macOsChannel.invokeMethod('dispose');
      _macOsNlpInitialized = false;
    }
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

class _ComputeParams {
  final List<String>? sentences;
  final String? rawText;
  final bool useModel;

  _ComputeParams({this.sentences, this.rawText, required this.useModel});
}

// -----------------------------------------------------------
// Isolate 逻辑 (仅用于 iOS/Android TFLite)
// -----------------------------------------------------------

Future<List<_ScoredSentence>> _analyzeSentencesInIsolate(_ComputeParams params) async {
  final sentences = params.sentences ?? [];
  final scored = <_ScoredSentence>[];

  Interpreter? interpreter;
  BertTokenizer? tokenizer;
  List<double>? meritAnchorEmbedding;

  // 如果启用模型，尝试加载
  if (params.useModel) {
    try {
      interpreter = await Interpreter.fromAsset('assets/models/mobilebert_quant_chinese.tflite');
      tokenizer = await BertTokenizer.fromAsset('assets/models/vocab.txt');
      
      if (interpreter != null && tokenizer != null) {
         meritAnchorEmbedding = _getEmbedding(interpreter, tokenizer, "获得无量功德福报，消除一切业障");
      }
    } catch (e) {
      debugPrint('Isolate NLP Load Error: $e');
    }
  }

  for (int i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    
    // 基础分：规则引擎
    double score = _calculateRuleScore(sentence);

    // 进阶分：模型语义
    if (interpreter != null && tokenizer != null && meritAnchorEmbedding != null) {
      try {
        final embedding = _getEmbedding(interpreter, tokenizer, sentence);
        if (embedding != null) {
           final similarity = _cosineSimilarityStatic(embedding, meritAnchorEmbedding);
           if (similarity > 0.7) score += 2.0;
           if (similarity > 0.8) score += 1.0;
        }
      } catch (e) {
        // ignore inference errors
      }
    }

    scored.add(_ScoredSentence(
      text: sentence,
      score: score,
      originalIndex: i,
    ));
  }

  // 清理资源
  interpreter?.close();

  // 排序
  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.originalIndex.compareTo(b.originalIndex);
  });

  return scored;
}

List<double>? _getEmbedding(Interpreter interpreter, BertTokenizer tokenizer, String text) {
  try {
    final inputObj = tokenizer.encode(text, maxLen: 128);
    
    final inputIds = [inputObj];
    
    while (inputIds[0].length < 128) {
      inputIds[0].add(0);
    }
    
    final inputMask = [List.filled(128, 0)];
    for(int i=0; i<inputObj.length; i++) inputMask[0][i] = 1;
    
    final segmentIds = [List.filled(128, 0)];
    
    final inputs = [inputIds, inputMask, segmentIds]; 
    
    final output0 = List.filled(1 * 128 * 512, 0.0).reshape([1, 128, 512]);
    final output1 = List.filled(1 * 512, 0.0).reshape([1, 512]);
    
    final outputs = {0: output0, 1: output1};
    
    interpreter.runForMultipleInputs(inputs, outputs);
    
    final out1 = outputs[1] as List;
    if (out1.isNotEmpty && out1[0][0] != 0.0) {
       return List<double>.from(out1[0]);
    }
    
    // Fallback: Mean pooling of output 0
    final out0 = outputs[0] as List;
    final seqLen = inputObj.length;
    final hiddenSize = 512;
    
    final embedding = List<double>.filled(hiddenSize, 0.0);
    for (int i=0; i<seqLen; i++) {
       for (int h=0; h<hiddenSize; h++) {
         embedding[h] += out0[0][i][h];
       }
    }
    for (int h=0; h<hiddenSize; h++) {
      embedding[h] /= seqLen;
    }
    return embedding;
    
  } catch (e) {
    return null;
  }
}

double _cosineSimilarityStatic(List<double> v1, List<double> v2) {
  if (v1.length != v2.length) return 0.0;
  double dot = 0.0;
  double mag1 = 0.0;
  double mag2 = 0.0;
  for (int i = 0; i < v1.length; i++) {
    dot += v1[i] * v2[i];
    mag1 += v1[i] * v1[i];
    mag2 += v2[i] * v2[i];
  }
  return dot / (math.sqrt(mag1) * math.sqrt(mag2));
}

double _calculateRuleScore(String sentence) {
  double score = 0.0;
  int matchCount = 0;

  final matches = SemanticNlpService._semanticPattern.allMatches(sentence);
  for (final match in matches) {
    final keyword = match.group(0)!;
    matchCount++;
    if (SemanticNlpService._meritSet.contains(keyword)) score += 3.0;
    else if (SemanticNlpService._benefitSet.contains(keyword)) score += 2.5;
    else if (SemanticNlpService._praiseSet.contains(keyword)) score += 2.0;
    else if (SemanticNlpService._dharmaSet.contains(keyword)) score += 1.5;
  }

  if (matchCount > 1) score *= 1.0 + (matchCount - 1) * 0.2;
  
  final length = sentence.length;
  if (length < 10) score *= 0.8;
  else if (length > 50) score *= 0.9;

  return score;
}
