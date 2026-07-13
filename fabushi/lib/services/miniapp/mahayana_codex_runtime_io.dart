import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// Native bridge for the one shared Mahayana Rust kernel. A turn is executed
/// in an isolate because the Rust SDK waits for the Codex CLI JSONL process.
class MahayanaCodexRuntime {
  MahayanaCodexRuntime._();

  static final MahayanaCodexRuntime instance = MahayanaCodexRuntime._();

  DynamicLibrary? _library;
  bool _loadAttempted = false;
  String? _loadError;

  bool get isAvailable => _loadLibrary() != null;

  String? get loadError {
    _loadLibrary();
    return _loadError;
  }

  Future<Map<String, dynamic>> run(Map<String, dynamic> request) async {
    _requireLibrary();
    return Isolate.run(() => _runCodexInWorker(Map<String, dynamic>.from(request)));
  }

  DynamicLibrary? _loadLibrary() {
    if (_library != null) return _library;
    if (_loadAttempted) return null;
    _loadAttempted = true;

    final errors = <String>[];
    if (Platform.isIOS) {
      try {
        final library = DynamicLibrary.process();
        _verifySymbols(library);
        _library = library;
        return library;
      } catch (error) {
        errors.add('iOS process symbols: $error');
      }
    }

    for (final candidate in _libraryCandidates()) {
      try {
        final library = DynamicLibrary.open(candidate);
        _verifySymbols(library);
        _library = library;
        return library;
      } catch (error) {
        errors.add('$candidate: $error');
      }
    }
    _loadError = errors.join('\n');
    return null;
  }

  DynamicLibrary _requireLibrary() {
    final library = _loadLibrary();
    if (library == null) {
      throw MahayanaCodexRuntimeException(
        'mahayana_codex_runtime_unavailable',
        'The embedded Mahayana Codex Rust SDK is not bundled for this platform.',
        details: _loadError,
      );
    }
    return library;
  }
}

Map<String, dynamic> _runCodexInWorker(Map<String, dynamic> request) {
  final library = _openLibraryForWorker();
  final run = library
      .lookup<NativeFunction<_MahayanaCodexRunNative>>('mahayana_codex_run')
      .asFunction<_MahayanaCodexRunDart>();
  final freeString = library
      .lookup<NativeFunction<_MahayanaFreeStringNative>>('mahayana_free_string')
      .asFunction<_MahayanaFreeStringDart>();
  final requestPointer = jsonEncode(request).toNativeUtf8();
  Pointer<Utf8> responsePointer = nullptr;
  try {
    responsePointer = run(requestPointer);
    if (responsePointer == nullptr) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_codex_null_response',
        'Mahayana Codex Rust SDK returned a null response.',
      );
    }
    final decoded = jsonDecode(responsePointer.toDartString());
    if (decoded is! Map) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_codex_invalid_response',
        'Mahayana Codex Rust SDK returned a non-object response.',
      );
    }
    final response = Map<String, dynamic>.from(decoded);
    if (response['ok'] == true) {
      final data = response['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const MahayanaCodexRuntimeException(
        'mahayana_codex_invalid_response',
        'Mahayana Codex Rust SDK returned no turn data.',
      );
    }
    throw MahayanaCodexRuntimeException(
      response['errorCode']?.toString() ?? 'mahayana_codex_sdk_error',
      response['message']?.toString() ?? 'Mahayana Codex Rust SDK failed.',
      details: response,
    );
  } finally {
    malloc.free(requestPointer);
    if (responsePointer != nullptr) freeString(responsePointer);
  }
}

DynamicLibrary _openLibraryForWorker() {
  if (Platform.isIOS) {
    final library = DynamicLibrary.process();
    _verifySymbols(library);
    return library;
  }
  final errors = <String>[];
  for (final candidate in _libraryCandidates()) {
    try {
      final library = DynamicLibrary.open(candidate);
      _verifySymbols(library);
      return library;
    } catch (error) {
      errors.add('$candidate: $error');
    }
  }
  throw MahayanaCodexRuntimeException(
    'mahayana_codex_runtime_unavailable',
    'The embedded Mahayana Codex Rust SDK is not bundled for this platform.',
    details: errors.join('\n'),
  );
}

List<String> _libraryCandidates() => <String>[
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
    ];

void _verifySymbols(DynamicLibrary library) {
  library.lookup<NativeFunction<_MahayanaCodexRunNative>>('mahayana_codex_run');
  library.lookup<NativeFunction<_MahayanaFreeStringNative>>(
    'mahayana_free_string',
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

typedef _MahayanaCodexRunNative = Pointer<Utf8> Function(Pointer<Utf8> request);
typedef _MahayanaCodexRunDart = Pointer<Utf8> Function(Pointer<Utf8> request);
typedef _MahayanaFreeStringNative = Void Function(Pointer<Utf8> pointer);
typedef _MahayanaFreeStringDart = void Function(Pointer<Utf8> pointer);
