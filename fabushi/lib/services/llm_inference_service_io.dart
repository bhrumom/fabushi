import 'dart:io';

import 'llm_inference_service_macos.dart' as macos;
import 'llm_inference_service_mobile.dart' as mobile;

/// LLM 推理服务（IO 平台分发器）
/// 
/// 根据平台自动选择实现：
/// - macOS: llama_cpp_dart
/// - Android/iOS: flutter_gemma (Gemma 3n)
class LLMInferenceService {
  static LLMInferenceService? _instance;
  static LLMInferenceService get instance => _instance ??= LLMInferenceService._();
  LLMInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;
  
  // 平台实现
  final _macosService = macos.LlamaInferenceService.instance;
  final _mobileService = mobile.GemmaInferenceService.instance;
  
  /// 是否使用 Gemma（Android/iOS）
  bool get _useGemma => Platform.isAndroid || Platform.isIOS;

  /// 是否已初始化
  bool get isInitialized => _useGemma 
      ? _mobileService.isInitialized 
      : _macosService.isInitialized;
  
  /// 当前模型路径
  String? get modelPath => _modelPath;

  /// 初始化模型
  /// 
  /// [modelPath] 模型文件的本地路径
  Future<void> initialize(String modelPath) async {
    if (_useGemma) {
      await _mobileService.initialize(modelPath);
    } else {
      await _macosService.initialize(modelPath);
    }
    _modelPath = modelPath;
    _isInitialized = true;
  }
  
  /// 流式生成文本
  Stream<String> generateStream(String prompt) {
    if (_useGemma) {
      return _mobileService.generateStream(prompt);
    } else {
      return _macosService.generateStream(prompt);
    }
  }
  
  /// 同步生成文本
  Future<String> generate(String prompt, {void Function(String token)? onToken}) async {
    if (_useGemma) {
      return _mobileService.generate(prompt);
    } else {
      return _macosService.generate(prompt, onToken: onToken);
    }
  }
  
  /// 停止生成
  Future<void> stopGeneration() async {
    if (!_useGemma) {
      await _macosService.stopGeneration();
    }
    // flutter_gemma 暂无停止 API
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_useGemma) {
      await _mobileService.dispose();
    } else {
      await _macosService.dispose();
    }
    _isInitialized = false;
    _modelPath = null;
  }
}
