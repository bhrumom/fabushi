import 'llm_inference_service_macos.dart' as macos;

/// LLM 推理服务（IO 平台分发器）
/// 
/// 统一实现：
/// - macOS/Android/iOS 全部使用 llama_cpp_dart 引擎
class LLMInferenceService {
  static LLMInferenceService? _instance;
  static LLMInferenceService get instance => _instance ??= LLMInferenceService._();
  LLMInferenceService._();
  String? _modelPath;
  
  // 统一平台实现（LlamaInferenceService 在 macOS/iOS/Android 通用）
  final _service = macos.LlamaInferenceService.instance;

  /// 是否已初始化
  bool get isInitialized => _service.isInitialized;
  
  /// 当前模型路径
  String? get modelPath => _service.modelPath;

  /// 初始化模型
  /// 
  /// [modelPath] 模型文件的本地路径
  Future<void> initialize(String modelPath) async {
    await _service.initialize(modelPath);
  }
  
  /// 流式生成文本
  Stream<String> generateStream(String prompt) {
    return _service.generateStream(prompt);
  }
  
  /// 同步生成文本
  Future<String> generate(String prompt, {void Function(String token)? onToken}) async {
    return _service.generate(prompt, onToken: onToken);
  }
  
  /// 停止生成
  Future<void> stopGeneration() async {
    await _service.stopGeneration();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _service.dispose();
  }
}
