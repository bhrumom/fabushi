// 条件导出：根据平台选择实现
// 统一使用 llama_cpp_dart 引擎
export 'llm_inference_service_stub.dart'
    if (dart.library.io) 'llm_inference_service_io.dart';

