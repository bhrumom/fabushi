import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class RustMiniAppRuntime {
  RustMiniAppRuntime._();

  static final RustMiniAppRuntime instance = RustMiniAppRuntime._();

  DynamicLibrary? _library;
  bool _loadAttempted = false;
  String? _loadError;

  bool get isAvailable => _loadLibrary() != null;

  String? get loadError {
    _loadLibrary();
    return _loadError;
  }

  Future<Map<String, dynamic>> httpFetch(Map<String, dynamic> params) async {
    return _invoke('fabushi_runtime_http_fetch_json', params);
  }

  Future<Map<String, dynamic>> udpOpen(Map<String, dynamic> params) async {
    return _invoke('fabushi_runtime_udp_open_json', params);
  }

  Future<Map<String, dynamic>> udpSend(Map<String, dynamic> params) async {
    return _invoke('fabushi_runtime_udp_send_json', params);
  }

  Future<Map<String, dynamic>> udpBroadcast(Map<String, dynamic> params) async {
    return _invoke('fabushi_runtime_udp_broadcast_json', params);
  }

  Future<Map<String, dynamic>> udpClose(Map<String, dynamic> params) async {
    return _invoke('fabushi_runtime_udp_close_json', params);
  }

  DynamicLibrary? _loadLibrary() {
    if (_library != null) return _library;
    if (_loadAttempted) return null;
    _loadAttempted = true;

    final candidates = <String>[
      if (Platform.isAndroid || Platform.isLinux) 'libfabushi_miniapp_runtime.so',
      if (Platform.isMacOS || Platform.isIOS) 'libfabushi_miniapp_runtime.dylib',
      if (Platform.isWindows) 'fabushi_miniapp_runtime.dll',
      if (Platform.isWindows) 'libfabushi_miniapp_runtime.dll',
    ];

    final errors = <String>[];
    for (final candidate in candidates) {
      try {
        _library = DynamicLibrary.open(candidate);
        return _library;
      } catch (error) {
        errors.add('$candidate: $error');
      }
    }

    _loadError = errors.join('\n');
    return null;
  }

  Map<String, dynamic> _invoke(String symbol, Map<String, dynamic> params) {
    final library = _loadLibrary();
    if (library == null) {
      throw RustMiniAppRuntimeException(
        'rust_runtime_unavailable',
        'Rust mini app runtime is not bundled for this platform yet.',
        details: _loadError,
      );
    }

    final invoke = library
        .lookup<NativeFunction<_RustJsonFnNative>>(symbol)
        .asFunction<_RustJsonFnDart>();
    final freeString = library
        .lookup<NativeFunction<_RustFreeStringNative>>(
          'fabushi_runtime_free_string',
        )
        .asFunction<_RustFreeStringDart>();

    final requestPtr = jsonEncode(params).toNativeUtf8();
    Pointer<Utf8> responsePtr = nullptr;
    try {
      responsePtr = invoke(requestPtr);
      if (responsePtr == nullptr) {
        throw RustMiniAppRuntimeException(
          'rust_runtime_null_response',
          '$symbol returned a null response pointer.',
        );
      }
      final decoded = jsonDecode(responsePtr.toDartString());
      if (decoded is! Map) {
        throw RustMiniAppRuntimeException(
          'rust_runtime_invalid_response',
          '$symbol returned a non-object response.',
        );
      }
      final response = Map<String, dynamic>.from(decoded as Map);
      if (response['ok'] == true) {
        return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
      }
      throw RustMiniAppRuntimeException(
        response['errorCode']?.toString() ?? 'rust_runtime_error',
        response['message']?.toString() ?? '$symbol failed.',
        details: response,
      );
    } finally {
      malloc.free(requestPtr);
      if (responsePtr != nullptr) freeString(responsePtr);
    }
  }
}

class RustMiniAppRuntimeException implements Exception {
  const RustMiniAppRuntimeException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}

typedef _RustJsonFnNative = Pointer<Utf8> Function(Pointer<Utf8> requestJson);
typedef _RustJsonFnDart = Pointer<Utf8> Function(Pointer<Utf8> requestJson);
typedef _RustFreeStringNative = Void Function(Pointer<Utf8> value);
typedef _RustFreeStringDart = void Function(Pointer<Utf8> value);
