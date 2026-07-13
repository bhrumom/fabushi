// Native implementation selected by rust_miniapp_runtime.dart.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

class RustMiniAppRuntime {
  RustMiniAppRuntime._();

  static final RustMiniAppRuntime instance = RustMiniAppRuntime._();

  DynamicLibrary? _library;
  _NativeAllocator? _allocator;
  bool _loadAttempted = false;
  String? _loadError;

  bool get isAvailable => _loadLibrary() != null;

  String? get loadError {
    _loadLibrary();
    return _loadError;
  }

  int createClient() {
    final library = _requireLoadedLibrary();
    return library
        .lookup<NativeFunction<_RustCreateClientNative>>(
          'fabushi_runtime_create_client',
        )
        .asFunction<_RustCreateClientDart>()();
  }

  Future<Map<String, dynamic>> send(
    int clientId,
    Map<String, dynamic> request,
  ) async {
    return _invokeClientJson('fabushi_runtime_send', clientId, request);
  }

  Future<Map<String, dynamic>?> receive(
    int clientId, {
    Duration timeout = Duration.zero,
  }) async {
    final library = _requireLoadedLibrary();
    final receive = library
        .lookup<NativeFunction<_RustReceiveNative>>('fabushi_runtime_receive')
        .asFunction<_RustReceiveDart>();
    final freeString = _freeString(library);

    Pointer<Char> responsePtr = nullptr;
    try {
      responsePtr = receive(
        clientId,
        timeout.inMicroseconds / Duration.microsecondsPerSecond,
      );
      if (responsePtr == nullptr) return null;
      return _decodeJsonObject('fabushi_runtime_receive', responsePtr);
    } finally {
      if (responsePtr != nullptr) freeString(responsePtr);
    }
  }

  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    return _invoke('fabushi_runtime_execute', request);
  }

  Future<Map<String, dynamic>> closeClient(int clientId) async {
    final library = _requireLoadedLibrary();
    final close = library
        .lookup<NativeFunction<_RustCloseClientNative>>(
          'fabushi_runtime_close',
        )
        .asFunction<_RustCloseClientDart>();
    final freeString = _freeString(library);

    Pointer<Char> responsePtr = nullptr;
    try {
      responsePtr = close(clientId);
      return _decodeWrappedResponse('fabushi_runtime_close', responsePtr);
    } finally {
      if (responsePtr != nullptr) freeString(responsePtr);
    }
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
      if (Platform.isAndroid || Platform.isLinux) 'libmahayana_wrapper.so',
      if (Platform.isMacOS || Platform.isIOS) 'libmahayana_wrapper.dylib',
      if (Platform.isWindows) 'mahayana_wrapper.dll',
      if (Platform.isWindows) 'libmahayana_wrapper.dll',
      if (Platform.isAndroid || Platform.isLinux) 'libfabushi_miniapp_runtime.so',
      if (Platform.isMacOS || Platform.isIOS) 'libfabushi_miniapp_runtime.dylib',
      if (Platform.isWindows) 'fabushi_miniapp_runtime.dll',
      if (Platform.isWindows) 'libfabushi_miniapp_runtime.dll',
    ];

    final errors = <String>[];
    for (final candidate in candidates) {
      try {
        _library = DynamicLibrary.open(candidate);
        _allocator = _NativeAllocator.load();
        return _library;
      } catch (error) {
        errors.add('$candidate: $error');
      }
    }

    _loadError = errors.join('\n');
    return null;
  }

  DynamicLibrary _requireLoadedLibrary() {
    final library = _loadLibrary();
    if (library == null) {
      throw RustMiniAppRuntimeException(
        'rust_runtime_unavailable',
        'Rust mini app runtime is not bundled for this platform yet.',
        details: _loadError,
      );
    }
    return library;
  }

  _NativeAllocator _requireAllocator() {
    final allocator = _allocator;
    if (allocator == null) {
      throw const RustMiniAppRuntimeException(
        'rust_runtime_unavailable',
        'Rust mini app runtime allocator is not ready.',
      );
    }
    return allocator;
  }

  Map<String, dynamic> _invoke(String symbol, Map<String, dynamic> params) {
    final library = _requireLoadedLibrary();
    final allocator = _requireAllocator();

    final invoke = library
        .lookup<NativeFunction<_RustJsonFnNative>>(symbol)
        .asFunction<_RustJsonFnDart>();
    final freeString = _freeString(library);

    final requestPtr = allocator.toNativeUtf8(jsonEncode(params));
    Pointer<Char> responsePtr = nullptr;
    try {
      responsePtr = invoke(requestPtr);
      return _decodeWrappedResponse(symbol, responsePtr);
    } finally {
      allocator.free(requestPtr.cast<Void>());
      if (responsePtr != nullptr) freeString(responsePtr);
    }
  }

  Map<String, dynamic> _invokeClientJson(
    String symbol,
    int clientId,
    Map<String, dynamic> params,
  ) {
    final library = _requireLoadedLibrary();
    final allocator = _requireAllocator();
    final invoke = library
        .lookup<NativeFunction<_RustClientJsonFnNative>>(symbol)
        .asFunction<_RustClientJsonFnDart>();
    final freeString = _freeString(library);

    final requestPtr = allocator.toNativeUtf8(jsonEncode(params));
    Pointer<Char> responsePtr = nullptr;
    try {
      responsePtr = invoke(clientId, requestPtr);
      return _decodeWrappedResponse(symbol, responsePtr);
    } finally {
      allocator.free(requestPtr.cast<Void>());
      if (responsePtr != nullptr) freeString(responsePtr);
    }
  }

  _RustFreeStringDart _freeString(DynamicLibrary library) {
    return library
        .lookup<NativeFunction<_RustFreeStringNative>>(
          'fabushi_runtime_free_string',
        )
        .asFunction<_RustFreeStringDart>();
  }

  Map<String, dynamic> _decodeWrappedResponse(
    String symbol,
    Pointer<Char> responsePtr,
  ) {
    final response = _decodeJsonObject(symbol, responsePtr);
    if (response['ok'] == true) {
      return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
    }
    throw RustMiniAppRuntimeException(
      response['errorCode']?.toString() ?? 'rust_runtime_error',
      response['message']?.toString() ?? '$symbol failed.',
      details: response,
    );
  }

  Map<String, dynamic> _decodeJsonObject(
    String symbol,
    Pointer<Char> responsePtr,
  ) {
    if (responsePtr == nullptr) {
      throw RustMiniAppRuntimeException(
        'rust_runtime_null_response',
        '$symbol returned a null response pointer.',
      );
    }
    final decoded = jsonDecode(_NativeAllocator.fromNativeUtf8(responsePtr));
    if (decoded is! Map) {
      throw RustMiniAppRuntimeException(
        'rust_runtime_invalid_response',
        '$symbol returned a non-object response.',
      );
    }
    return Map<String, dynamic>.from(decoded);
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

class _NativeAllocator {
  _NativeAllocator._(this._malloc, this._free);

  final Pointer<Void> Function(int size) _malloc;
  final void Function(Pointer<Void> pointer) _free;

  static _NativeAllocator load() {
    final library = Platform.isWindows
        ? DynamicLibrary.open('msvcrt.dll')
        : DynamicLibrary.process();
    return _NativeAllocator._(
      library
          .lookup<NativeFunction<_MallocNative>>('malloc')
          .asFunction<_MallocDart>(),
      library
          .lookup<NativeFunction<_FreeNative>>('free')
          .asFunction<_FreeDart>(),
    );
  }

  Pointer<Char> toNativeUtf8(String value) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    final pointer = _malloc(bytes.length + 1).cast<Uint8>();
    for (var i = 0; i < bytes.length; i += 1) {
      (pointer + i).value = bytes[i];
    }
    (pointer + bytes.length).value = 0;
    return pointer.cast<Char>();
  }

  void free(Pointer<Void> pointer) => _free(pointer);

  static String fromNativeUtf8(Pointer<Char> pointer) {
    final bytes = <int>[];
    final bytePointer = pointer.cast<Uint8>();
    var offset = 0;
    while (true) {
      final byte = (bytePointer + offset).value;
      if (byte == 0) break;
      bytes.add(byte);
      offset += 1;
    }
    return utf8.decode(bytes);
  }
}

typedef _RustJsonFnNative = Pointer<Char> Function(Pointer<Char> requestJson);
typedef _RustJsonFnDart = Pointer<Char> Function(Pointer<Char> requestJson);
typedef _RustCreateClientNative = Uint64 Function();
typedef _RustCreateClientDart = int Function();
typedef _RustClientJsonFnNative = Pointer<Char> Function(
  Uint64 clientId,
  Pointer<Char> requestJson,
);
typedef _RustClientJsonFnDart = Pointer<Char> Function(
  int clientId,
  Pointer<Char> requestJson,
);
typedef _RustReceiveNative = Pointer<Char> Function(
  Uint64 clientId,
  Double timeoutSeconds,
);
typedef _RustReceiveDart = Pointer<Char> Function(
  int clientId,
  double timeoutSeconds,
);
typedef _RustCloseClientNative = Pointer<Char> Function(Uint64 clientId);
typedef _RustCloseClientDart = Pointer<Char> Function(int clientId);
typedef _RustFreeStringNative = Void Function(Pointer<Char> value);
typedef _RustFreeStringDart = void Function(Pointer<Char> value);
typedef _MallocNative = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);
typedef _FreeNative = Void Function(Pointer<Void> pointer);
typedef _FreeDart = void Function(Pointer<Void> pointer);
