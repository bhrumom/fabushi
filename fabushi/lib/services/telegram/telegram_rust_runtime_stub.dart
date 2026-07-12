class TelegramRustRuntime {
  TelegramRustRuntime._();

  static final TelegramRustRuntime instance = TelegramRustRuntime._();

  bool get isAvailable => false;

  String? get loadError =>
      'Telegram Rust runtime is not available on this platform yet.';

  Future<void> initialize() async => _unavailable();

  int createClient() => _unavailable();

  int createPersistentClient({
    required String databasePath,
    required List<int> storageKey,
  }) => _unavailable();

  Future<Map<String, dynamic>> execute(
    int clientId,
    Map<String, dynamic> request,
  ) async => _unavailable();

  Future<void> closeClient(int clientId) async => _unavailable();
}

Never _unavailable() {
  throw const TelegramRustRuntimeException(
    'telegram_rust_runtime_unavailable',
    'Telegram Rust runtime is not bundled for this platform yet.',
  );
}

class TelegramRustRuntimeException implements Exception {
  const TelegramRustRuntimeException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}
