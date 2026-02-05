// 条件导出：Web 平台使用 stub，其他平台使用真实实现
export 'sherpa_stt_service_native.dart'
    if (dart.library.html) 'sherpa_stt_service_stub.dart';
