/// Stub implementation for platforms that don't support llama_cpp_dart (Windows, macOS, Linux, Web)

Future<dynamic> initializeModel(String modelPath, int nCtx) async {
  throw UnsupportedError('本地推理在当前平台不支持');
}

Future<String> generate(dynamic inference, String prompt, void Function(String token)? onToken) async {
  throw UnsupportedError('本地推理在当前平台不支持');
}

Stream<String> generateStream(dynamic inference, String prompt) {
  throw UnsupportedError('本地推理在当前平台不支持');
}

Future<void> stopGeneration(dynamic inference) async {
  // No-op
}

Future<void> disposeInference(dynamic inference) async {
  // No-op
}
