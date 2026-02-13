import 'dart:io';

// 条件导出：根据平台选择实现
// macOS: llama_cpp_dart (GGUF/Qwen)
// Android/iOS: flutter_gemma (Gemma 3n)
export 'llm_inference_service_stub.dart'
    if (dart.library.io) 'llm_inference_service_io.dart';

/// 判断当前平台是否使用 flutter_gemma
/// 
/// - Android/iOS: true (使用 flutter_gemma)
/// - macOS: false (使用 llama_cpp_dart)
bool get useMediaPipe {
  if (Platform.isAndroid || Platform.isIOS) {
    return true;
  }
  return false;
}
