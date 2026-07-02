class RustMiniAppRuntime {
  RustMiniAppRuntime._();

  static final RustMiniAppRuntime instance = RustMiniAppRuntime._();

  bool get isAvailable => false;

  String? get loadError =>
      'Rust mini app runtime is not available on this platform.';

  int createClient() => _unavailable();

  Future<Map<String, dynamic>> send(
    int clientId,
    Map<String, dynamic> request,
  ) async =>
      _unavailable();

  Future<Map<String, dynamic>?> receive(
    int clientId, {
    Duration timeout = Duration.zero,
  }) async =>
      _unavailable();

  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async =>
      _unavailable();

  Future<Map<String, dynamic>> closeClient(int clientId) async =>
      _unavailable();

  Future<Map<String, dynamic>> httpFetch(Map<String, dynamic> params) async =>
      _unavailable();

  Future<Map<String, dynamic>> udpOpen(Map<String, dynamic> params) async =>
      _unavailable();

  Future<Map<String, dynamic>> udpSend(Map<String, dynamic> params) async =>
      _unavailable();

  Future<Map<String, dynamic>> udpBroadcast(
    Map<String, dynamic> params,
  ) async =>
      _unavailable();

  Future<Map<String, dynamic>> udpClose(Map<String, dynamic> params) async =>
      _unavailable();
}

Never _unavailable() {
  throw const RustMiniAppRuntimeException(
    'rust_runtime_unavailable',
    'Rust mini app runtime is not available on this platform.',
  );
}

class RustMiniAppRuntimeException implements Exception {
  const RustMiniAppRuntimeException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}
