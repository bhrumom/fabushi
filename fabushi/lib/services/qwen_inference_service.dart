import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Qwen 推理服务
/// 
/// 本地 LLM 推理服务（仅支持移动端）。
/// 桌面端提供空实现。
class QwenInferenceService {
  static QwenInferenceService? _instance;
  static QwenInferenceService get instance => _instance ??= QwenInferenceService._();
  QwenInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;

  /// 是否支持本地推理（仅 Android/iOS）
  bool get _isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前模型路径
  String? get modelPath => _modelPath;

  /// 初始化模型
  Future<void> initialize(String modelPath, {int nCtx = 2048}) async {
    if (!_isSupported) {
      debugPrint('QwenInferenceService: 当前平台不支持本地推理');
      return;
    }

    // 移动端的 llama_cpp_dart 初始化需要在原生代码中完成
    debugPrint('QwenInferenceService: 本地推理需要移动端原生代码支持');
    _modelPath = modelPath;
  }

  /// 生成文本
  Future<String> generate(String prompt, {void Function(String token)? onToken}) async {
    if (!_isSupported) {
      throw StateError('QwenInferenceService 当前平台不支持');
    }
    throw StateError('QwenInferenceService 未实现');
  }
  
  /// 流式生成文本
  Stream<String> generateStream(String prompt) {
    if (!_isSupported) {
      throw StateError('QwenInferenceService 当前平台不支持');
    }
    throw StateError('QwenInferenceService 未实现');
  }
  
  /// 停止当前生成
  Future<void> stopGeneration() async {
    // No-op on desktop
  }

  /// 生成语义嵌入向量（占位实现）
  Future<List<double>> getEmbedding(String text) async {
    return _generatePlaceholderEmbedding(text);
  }

  /// 计算相似度
  Future<double> calculateSimilarity(String text1, String text2) async {
    final emb1 = await getEmbedding(text1);
    final emb2 = await getEmbedding(text2);
    return _cosineSimilarity(emb1, emb2);
  }

  /// 释放资源
  Future<void> dispose() async {
    _isInitialized = false;
    _modelPath = null;
  }

  double _cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    
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

  List<double> _generatePlaceholderEmbedding(String text) {
    const meritKeywords = ['功德', '福德', '福报', '福慧', '善根', '善业'];
    const benefitKeywords = ['能除', '能灭', '能消', '能得', '能令', '能使'];
    
    final embedding = List<double>.filled(64, 0.0);
    
    for (int i = 0; i < meritKeywords.length && i < 32; i++) {
      if (text.contains(meritKeywords[i])) embedding[i] = 1.0;
    }
    
    for (int i = 0; i < benefitKeywords.length && i < 32; i++) {
      if (text.contains(benefitKeywords[i])) embedding[32 + i] = 1.0;
    }
    
    double mag = 0.0;
    for (final v in embedding) mag += v * v;
    if (mag > 0) {
      mag = math.sqrt(mag);
      for (int i = 0; i < embedding.length; i++) embedding[i] /= mag;
    }
    
    return embedding;
  }
}
