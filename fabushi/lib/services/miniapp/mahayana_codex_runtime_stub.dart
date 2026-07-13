class MahayanaCodexRuntime {
  MahayanaCodexRuntime._();

  static final MahayanaCodexRuntime instance = MahayanaCodexRuntime._();

  bool get isAvailable => false;

  String? get loadError =>
      'The embedded Mahayana Codex Rust SDK is not available on this platform.';

  Future<Map<String, dynamic>> run(Map<String, dynamic> request) =>
      _unavailable();
}

Future<Map<String, dynamic>> _unavailable() {
  throw const MahayanaCodexRuntimeException(
    'mahayana_codex_runtime_unavailable',
    'The embedded Mahayana Codex Rust SDK is not available on this platform.',
  );
}

class MahayanaCodexRuntimeException implements Exception {
  const MahayanaCodexRuntimeException(
    this.code,
    this.message, {
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}
