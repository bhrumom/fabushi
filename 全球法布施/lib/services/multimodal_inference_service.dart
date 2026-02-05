// 条件导出：Web 平台使用 stub，其他平台使用真实实现
export 'multimodal_inference_service_native.dart'
    if (dart.library.html) 'multimodal_inference_service_stub.dart';
