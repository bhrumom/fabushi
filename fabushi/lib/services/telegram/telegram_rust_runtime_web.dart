import 'dart:convert';
import 'dart:js_interop';

@JS('fabushiTelegramWasm.initialize')
external JSPromise<JSAny?> _initializeWasm();

@JS('fabushiTelegramWasm.createClient')
external JSNumber _createWasmClient();

@JS('fabushiTelegramWasm.execute')
external JSString _executeWasmClient(JSNumber clientId, JSString requestJson);

@JS('fabushiTelegramWasm.closeClient')
external void _closeWasmClient(JSNumber clientId);

class TelegramRustRuntime {
  TelegramRustRuntime._();

  static final TelegramRustRuntime instance = TelegramRustRuntime._();

  bool _initialized = false;
  String? _loadError;

  bool get isAvailable => _initialized;
  String? get loadError => _loadError;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _initializeWasm().toDart;
      _initialized = true;
      _loadError = null;
    } catch (error) {
      _loadError = error.toString();
      throw TelegramRustRuntimeException(
        'telegram_wasm_initialize_failed',
        'Telegram Rust WebAssembly runtime could not be initialized.',
        details: error,
      );
    }
  }

  int createClient() {
    _requireInitialized();
    return _createWasmClient().toDartInt;
  }

  int createPersistentClient({
    required String databasePath,
    required List<int> storageKey,
  }) {
    throw const TelegramRustRuntimeException(
      'telegram_wasm_persistence_pending',
      'Encrypted IndexedDB persistence is not connected yet.',
    );
  }

  Future<Map<String, dynamic>> execute(
    int clientId,
    Map<String, dynamic> request,
  ) async {
    _requireInitialized();
    final decoded = jsonDecode(
      _executeWasmClient(clientId.toJS, jsonEncode(request).toJS).toDart,
    );
    if (decoded is! Map) {
      throw const TelegramRustRuntimeException(
        'telegram_wasm_invalid_response',
        'Telegram WebAssembly runtime returned a non-object response.',
      );
    }
    final response = Map<String, dynamic>.from(decoded);
    if (response['ok'] == true) {
      return Map<String, dynamic>.from(
        response['data'] as Map? ?? const <String, dynamic>{},
      );
    }
    throw TelegramRustRuntimeException(
      response['errorCode']?.toString() ?? 'telegram_wasm_error',
      response['message']?.toString() ?? 'Telegram WebAssembly request failed.',
      details: response,
    );
  }

  Future<void> closeClient(int clientId) async {
    _requireInitialized();
    _closeWasmClient(clientId.toJS);
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw TelegramRustRuntimeException(
        'telegram_wasm_not_initialized',
        'Call TelegramRustRuntime.initialize() before using the Web runtime.',
        details: _loadError,
      );
    }
  }
}

class TelegramRustRuntimeException implements Exception {
  const TelegramRustRuntimeException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}
