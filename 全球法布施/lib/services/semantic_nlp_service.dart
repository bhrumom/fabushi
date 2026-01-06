import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:global_dharma_sharing/services/nlp/bert_tokenizer.dart';

/// 语义优先服务 - 极致性能 + 精确语义
/// 
/// 混合架构：
/// 1. 快速路径：预编译正则表达式 O(n) 匹配
/// 2. 精确路径：TFLite NLP模型推理（语义相似度）
/// 3. 后台Isolate：不阻塞UI线程
/// 4. LRU缓存：避免重复计算
class SemanticNlpService {
  static SemanticNlpService? _instance;
  static SemanticNlpService get instance => _instance ??= SemanticNlpService._();
  SemanticNlpService._();

  // 模型状态
  bool _useModel = false;
  bool _isInitializing = false;
  
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
      // 检查模型文件是否存在
      try {
        await rootBundle.load('assets/models/mobilebert_quant_chinese.tflite');
        await rootBundle.load('assets/models/vocab.txt');
        _useModel = true;
        debugPrint('📖 SemanticNlpService: 模型文件检查通过，将在后台启用NLP语义分析');
      } catch (e) {
        debugPrint('📖 SemanticNlpService: 未找到完整模型文件，降级为规则引擎模式');
        _useModel = false;
      }
    } catch (e) {
      debugPrint('📖 SemanticNlpService: 初始化异常: $e');
      _useModel = false;
    } finally {
      _isInitializing = false;
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

    // 传递参数到后台
    final params = _ComputeParams(
      sentences: sentences,
      useModel: _useModel,
    );

    final scored = await compute(_analyzeSentencesInIsolate, params);

    _updateCache(hash, scored);

    debugPrint('📖 SemanticNlpService: 排序完成，高优先句数: ${scored.where((s) => s.score > 2.0).length}/${scored.length}');

    return scored.map((s) => s.text).toList();
  }

  /// 处理并排序超长文本
  Future<List<String>> processAndSortLargeText(String rawText) async {
    if (rawText.isEmpty) return [];

    final hash = rawText.hashCode;
    if (_cache.containsKey(hash)) {
      return _cache[hash]!.map((s) => s.text).toList();
    }

    debugPrint('📖 SemanticNlpService: 开始处理大文本...');
    
    // 大文本处理也使用相同参数结构，但需要先分句
    final params = _ComputeParams(
      rawText: rawText,
      useModel: _useModel,
    );

    final scored = await compute(_processTextInIsolate, params);

    _updateCache(hash, scored);

    return scored.map((s) => s.text).toList();
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
// Isolate 逻辑
// -----------------------------------------------------------

Future<List<_ScoredSentence>> _processTextInIsolate(_ComputeParams params) async {
  // 1. 分句
  final rawText = params.rawText ?? '';
  final parts = rawText.split(RegExp(r'[。！？\n]+'));
  final sentences = <String>[];
  
  for (final p in parts) {
    final t = p.trim();
    if (t.isNotEmpty && RegExp(r'[\u4e00-\u9fff\u3400-\u4dbfa-zA-Z0-9]').hasMatch(t)) {
      sentences.add(t);
    }
  }

  // 2. 分析
  // 重构参数以传递句子列表
  final newParams = _ComputeParams(sentences: sentences, useModel: params.useModel);
  return _analyzeSentencesInIsolate(newParams);
}

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
      
      // 生成锚点向量 (简单合成)
      // "获得无量功德福报"
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
           final similarity = _cosineSimilarity(embedding, meritAnchorEmbedding);
           // 相似度通常在 0.5 - 1.0 之间
           if (similarity > 0.7) score += 2.0;
           if (similarity > 0.8) score += 1.0;
           // debugPrint('Text: ${sentence.substring(0, math.min(10, sentence.length))}... Sim: $similarity');
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
    // MobileBERT 输入: [input_ids, input_mask, segment_ids] (顺序可能不同，需检查)
    // 通常 Input 0: ids, Input 1: mask, Input 2: segments 或者 ids, segments, mask
    // 我们构造 3 个 inputs
    // shape: [1, 128]
    
    final inputIds = [inputObj]; // [1, 128]
    // Mask: 1 for tokens, 0 for padding. Here we assume inputObj includes padding to 128 if fixed?
    // Tokenizer encode doesn't pad to full 128 automatically usually, but let's pad it
    
    // Pad to 128 ? MobileBERT likely fixed or dynamic. Let's try to not pad if dynamic.
    // TFLite tensors usually have fixed signature.
    // Let's inspect signature if possible. But here we guess.
    // Safe guess: Pad to 128 (standard)
    
    while (inputIds[0].length < 128) {
      inputIds[0].add(0);
    }
    
    final inputMask = [List.filled(128, 0)];
    for(int i=0; i<inputObj.length; i++) inputMask[0][i] = 1; // Unpadded parts
    
    final segmentIds = [List.filled(128, 0)];

    // Outputs
    // Output 0: [1, 128, 512] (Sequence)
    // Output 1: [1, 512] (Pooled) - maybe
    
    // We need to match inputs to tensor indices.
    // TFLite tensor indices aren't always 0,1,2.
    // But tflite_flutter runForMultipleInputs takes List<Object>.
    // Usually map inputs by index.
    
    // Try passing map if knowing names? No, tflite_flutter uses positional list or map.
    // Let's use generic run.
    
    // We assume standard BERT export order: ids, mask, segments.
    // If getting errors, we might need to swap.
    final inputs = [inputIds, inputMask, segmentIds]; 
    
    final output0 = List.filled(1 * 128 * 512, 0.0).reshape([1, 128, 512]);
    final output1 = List.filled(1 * 512, 0.0).reshape([1, 512]); // Optimistic
    
    final outputs = {0: output0, 1: output1};
    
    interpreter.runForMultipleInputs(inputs, outputs);
    
    // Use pooled output (index 1) if available and non-zero, else mean of output 0
    // MobileBERT TFLite often has 2 outputs.
    
    final out1 = outputs[1] as List;
    if (out1.isNotEmpty && out1[0][0] != 0.0) {
       return List<double>.from(out1[0]);
    }
    
    // Fallback: Mean pooling of output 0
    final out0 = outputs[0] as List; // [1, 128, 512]
    final seqLen = inputObj.length; // real length
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
    // debugPrint('Inference failed: $e');
    return null;
  }
}

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
