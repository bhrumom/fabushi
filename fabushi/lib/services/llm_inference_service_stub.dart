/// LLM 推理服务（Web 桩实现）
/// 
/// Web 平台不支持本地 LLM 推理
class LLMInferenceService {
  static LLMInferenceService? _instance;
  static LLMInferenceService get instance => _instance ??= LLMInferenceService._();
  LLMInferenceService._();

  bool get isInitialized => false;
  String? get modelPath => null;

  Future<void> initialize(String modelPath) async {
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }
  
  Stream<String> generateStream(String prompt) {
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }
  
  Future<String> generate(String prompt, {void Function(String token)? onToken}) async {
    throw UnsupportedError('Web 平台不支持本地 LLM 推理');
  }
  
  Future<void> stopGeneration() async {}
  
  Future<void> dispose() async {}
}
