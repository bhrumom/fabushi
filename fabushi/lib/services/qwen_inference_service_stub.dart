// Web 平台的 stub 实现
// llama_cpp_dart 不支持 Web，此文件提供空实现

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Web 平台的 Qwen 推理服务 (禁用状态)
class QwenInferenceService {
  static QwenInferenceService? _instance;
  static QwenInferenceService get instance => _instance ??= QwenInferenceService._();
  QwenInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前模型路径
  String? get modelPath => _modelPath;

  /// 初始化模型 (Web 不支持)
  Future<void> initialize(
    String modelPath, {
    int nCtx = 2048,
  }) async {
    debugPrint('QwenInferenceService: Web 平台不支持本地 LLM 推理');
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }

  /// 生成文本 (Web 不支持)
  Future<String> generate(
    String prompt, {
    void Function(String token)? onToken,
  }) async {
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }
  
  /// 流式生成文本 (Web 不支持)
  Stream<String> generateStream(String prompt) {
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }
  
  /// 停止当前生成
  Future<void> stopGeneration() async {}

  /// 生成语义嵌入向量 (Web 不支持)
  Future<List<double>> getEmbedding(String text) async {
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }

  /// 计算两个文本的语义相似度 (Web 不支持)
  Future<double> calculateSimilarity(String text1, String text2) async {
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }

  /// 释放资源
  Future<void> dispose() async {
    _isInitialized = false;
    _modelPath = null;
  }
}
