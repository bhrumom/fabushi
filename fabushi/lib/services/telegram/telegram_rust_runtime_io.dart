import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class TelegramRustRuntime {
  TelegramRustRuntime._();

  static final TelegramRustRuntime instance = TelegramRustRuntime._();

  DynamicLibrary? _library;
  bool _loadAttempted = false;
  String? _loadError;

  bool get isAvailable => _loadLibrary() != null;

  String? get loadError {
    _loadLibrary();
    return _loadError;
  }

  Future<void> initialize() async {
    _requireLibrary();
  }

  int createClient() {
    final library = _requireLibrary();
    return library
        .lookup<NativeFunction<_CreateClientNative>>(
          'fabushi_telegram_create_client',
        )
        .asFunction<_CreateClientDart>()();
  }

  int createPersistentClient({
    required String databasePath,
    required List<int> storageKey,
  }) {
    if (storageKey.length != 32) {
      throw const TelegramRustRuntimeException(
        'telegram_storage_key_invalid',
        'Telegram storage key must contain exactly 32 bytes.',
      );
    }
    final library = _requireLibrary();
    final create = library
        .lookup<NativeFunction<_CreatePersistentClientNative>>(
          'fabushi_telegram_create_persistent_client',
        )
        .asFunction<_CreatePersistentClientDart>();
    final freeString = library
        .lookup<NativeFunction<_FreeStringNative>>(
          'fabushi_telegram_free_string',
        )
        .asFunction<_FreeStringDart>();
    final pathPointer = databasePath.toNativeUtf8();
    final keyPointer = malloc<Uint8>(storageKey.length);
    keyPointer.asTypedList(storageKey.length).setAll(0, storageKey);
    Pointer<Utf8> responsePointer = nullptr;
    try {
      responsePointer = create(pathPointer, keyPointer, storageKey.length);
      final response = _decodeResponse(responsePointer);
      if (response['ok'] != true) {
        throw TelegramRustRuntimeException(
          response['errorCode']?.toString() ?? 'telegram_storage_open_error',
          response['message']?.toString() ??
              'Failed to open Telegram encrypted storage.',
          details: response,
        );
      }
      final data = Map<String, dynamic>.from(
        response['data'] as Map? ?? const <String, dynamic>{},
      );
      final clientId = data['clientId'];
      if (clientId is! num) {
        throw const TelegramRustRuntimeException(
          'telegram_rust_invalid_response',
          'Persistent client response did not contain a client id.',
        );
      }
      return clientId.toInt();
    } finally {
      keyPointer
          .asTypedList(storageKey.length)
          .fillRange(0, storageKey.length, 0);
      malloc.free(keyPointer);
      malloc.free(pathPointer);
      if (responsePointer != nullptr) {
        freeString(responsePointer);
      }
    }
  }

  Future<Map<String, dynamic>> execute(
    int clientId,
    Map<String, dynamic> request,
  ) async {
    final library = _requireLibrary();
    final execute = library
        .lookup<NativeFunction<_ExecuteNative>>('fabushi_telegram_execute')
        .asFunction<_ExecuteDart>();
    final freeString = library
        .lookup<NativeFunction<_FreeStringNative>>(
          'fabushi_telegram_free_string',
        )
        .asFunction<_FreeStringDart>();
    final requestPointer = jsonEncode(request).toNativeUtf8();
    Pointer<Utf8> responsePointer = nullptr;
    try {
      responsePointer = execute(clientId, requestPointer);
      final response = _decodeResponse(responsePointer);
      if (response['ok'] == true) {
        return Map<String, dynamic>.from(
          response['data'] as Map? ?? const <String, dynamic>{},
        );
      }
      throw TelegramRustRuntimeException(
        response['errorCode']?.toString() ?? 'telegram_rust_error',
        response['message']?.toString() ?? 'Telegram Rust request failed.',
        details: response,
      );
    } finally {
      malloc.free(requestPointer);
      if (responsePointer != nullptr) {
        freeString(responsePointer);
      }
    }
  }

  Future<void> closeClient(int clientId) async {
    final library = _requireLibrary();
    final close = library
        .lookup<NativeFunction<_CloseClientNative>>(
          'fabushi_telegram_close_client',
        )
        .asFunction<_CloseClientDart>();
    final freeString = library
        .lookup<NativeFunction<_FreeStringNative>>(
          'fabushi_telegram_free_string',
        )
        .asFunction<_FreeStringDart>();
    final responsePointer = close(clientId);
    try {
      final response = _decodeResponse(responsePointer);
      if (response['ok'] != true) {
        throw TelegramRustRuntimeException(
          response['errorCode']?.toString() ?? 'telegram_rust_close_error',
          response['message']?.toString() ??
              'Failed to close Telegram Rust client.',
          details: response,
        );
      }
    } finally {
      if (responsePointer != nullptr) {
        freeString(responsePointer);
      }
    }
  }

  DynamicLibrary? _loadLibrary() {
    if (_library != null) return _library;
    if (_loadAttempted) return null;
    _loadAttempted = true;

    final attempts = <String>[];
    if (Platform.isIOS) {
      try {
        final library = DynamicLibrary.process();
        _verifySymbols(library);
        _library = library;
        return library;
      } catch (error) {
        attempts.add('iOS process symbols: $error');
      }
    }

    final candidates = <String>[
      if (Platform.isAndroid) 'libmahayana_wrapper.so',
      if (Platform.isLinux)
        '${File(Platform.resolvedExecutable).parent.path}/lib/libmahayana_wrapper.so',
      if (Platform.isLinux) 'libmahayana_wrapper.so',
      if (Platform.isMacOS)
        '${File(Platform.resolvedExecutable).parent.parent.path}/Frameworks/libmahayana_wrapper.dylib',
      if (Platform.isMacOS) 'libmahayana_wrapper.dylib',
      if (Platform.isWindows)
        '${File(Platform.resolvedExecutable).parent.path}\\mahayana_wrapper.dll',
      if (Platform.isWindows) 'mahayana_wrapper.dll',
      if (Platform.isWindows) 'libmahayana_wrapper.dll',
      if (Platform.isAndroid) 'libfabushi_telegram_runtime.so',
      if (Platform.isLinux)
        '${File(Platform.resolvedExecutable).parent.path}/lib/libfabushi_telegram_runtime.so',
      if (Platform.isLinux) 'libfabushi_telegram_runtime.so',
      if (Platform.isMacOS)
        '${File(Platform.resolvedExecutable).parent.parent.path}/Frameworks/libfabushi_telegram_runtime.dylib',
      if (Platform.isMacOS) 'libfabushi_telegram_runtime.dylib',
      if (Platform.isWindows)
        '${File(Platform.resolvedExecutable).parent.path}\\fabushi_telegram_runtime.dll',
      if (Platform.isWindows) 'fabushi_telegram_runtime.dll',
      if (Platform.isWindows) 'libfabushi_telegram_runtime.dll',
    ];
    for (final candidate in candidates) {
      try {
        final library = DynamicLibrary.open(candidate);
        _verifySymbols(library);
        _library = library;
        return library;
      } catch (error) {
        attempts.add('$candidate: $error');
      }
    }
    _loadError = attempts.isEmpty
        ? 'No Telegram Rust runtime candidate exists for this platform.'
        : attempts.join('\n');
    return null;
  }

  void _verifySymbols(DynamicLibrary library) {
    library.lookup<NativeFunction<_CreateClientNative>>(
      'fabushi_telegram_create_client',
    );
    library.lookup<NativeFunction<_ExecuteNative>>('fabushi_telegram_execute');
    library.lookup<NativeFunction<_CreatePersistentClientNative>>(
      'fabushi_telegram_create_persistent_client',
    );
    library.lookup<NativeFunction<_CloseClientNative>>(
      'fabushi_telegram_close_client',
    );
    library.lookup<NativeFunction<_FreeStringNative>>(
      'fabushi_telegram_free_string',
    );
  }

  DynamicLibrary _requireLibrary() {
    final library = _loadLibrary();
    if (library == null) {
      throw TelegramRustRuntimeException(
        'telegram_rust_runtime_unavailable',
        'Telegram Rust runtime is not bundled for this platform yet.',
        details: _loadError,
      );
    }
    return library;
  }

  Map<String, dynamic> _decodeResponse(Pointer<Utf8> pointer) {
    if (pointer == nullptr) {
      throw const TelegramRustRuntimeException(
        'telegram_rust_null_response',
        'Telegram Rust runtime returned a null response pointer.',
      );
    }
    final decoded = jsonDecode(pointer.toDartString());
    if (decoded is! Map) {
      throw const TelegramRustRuntimeException(
        'telegram_rust_invalid_response',
        'Telegram Rust runtime returned a non-object response.',
      );
    }
    return Map<String, dynamic>.from(decoded);
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

typedef _CreateClientNative = Uint64 Function();
typedef _CreateClientDart = int Function();
typedef _CreatePersistentClientNative =
    Pointer<Utf8> Function(
      Pointer<Utf8> databasePath,
      Pointer<Uint8> storageKey,
      IntPtr storageKeyLength,
    );
typedef _CreatePersistentClientDart =
    Pointer<Utf8> Function(
      Pointer<Utf8> databasePath,
      Pointer<Uint8> storageKey,
      int storageKeyLength,
    );
typedef _ExecuteNative =
    Pointer<Utf8> Function(Uint64 clientId, Pointer<Utf8> requestJson);
typedef _ExecuteDart =
    Pointer<Utf8> Function(int clientId, Pointer<Utf8> requestJson);
typedef _CloseClientNative = Pointer<Utf8> Function(Uint64 clientId);
typedef _CloseClientDart = Pointer<Utf8> Function(int clientId);
typedef _FreeStringNative = Void Function(Pointer<Utf8> pointer);
typedef _FreeStringDart = void Function(Pointer<Utf8> pointer);
