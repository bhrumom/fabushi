import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// Long-lived native bridge to the embedded Mahayana Runtime.
///
/// Runtime creation, commands, streamed events, interrupts, and approvals use
/// one stable C/JSON ABI. No `codex` subprocess or cloud Agent gateway is used.
class MahayanaCodexRuntime {
  MahayanaCodexRuntime._();

  static final MahayanaCodexRuntime instance = MahayanaCodexRuntime._();

  DynamicLibrary? _library;
  bool _loadAttempted = false;
  String? _loadError;
  Future<int>? _runtimeId;

  bool get isAvailable => _loadLibrary() != null;

  String? get loadError {
    _loadLibrary();
    return _loadError;
  }

  Future<Map<String, dynamic>> run(Map<String, dynamic> request) async {
    final prompt = (request['prompt'] ?? request['message'])?.toString().trim();
    if (prompt == null || prompt.isEmpty) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_empty_prompt',
        'Codex prompt must not be empty.',
      );
    }
    return sendAndCollect('codex:agent:assistant', prompt);
  }

  /// Compatibility dispatcher for product commands and the stable runtime ABI.
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final type = request['@type']?.toString() ?? '';
    if (type == 'mahayana.codex.run') return run(request);
    if (type == 'mahayana.miniapp.chat') {
      final miniAppId = request['miniAppId']?.toString().trim() ?? '';
      final message = request['message']?.toString().trim() ?? '';
      if (miniAppId.isEmpty || message.isEmpty) {
        throw const MahayanaCodexRuntimeException(
          'mahayana_invalid_miniapp_request',
          'Mini-app id and message are required.',
        );
      }
      return sendAndCollect('miniapp:$miniAppId', message);
    }
    if (_isRuntimeCommand(type)) return executeRuntime(request);
    return executeProduct(request);
  }

  Future<Map<String, dynamic>> executeRuntime(
    Map<String, dynamic> command, {
    String? token,
  }) async {
    _requireLibrary();
    final runtimeId = await _ensureRuntime();
    return Isolate.run(
      () => _executeRuntimeInWorker(
        runtimeId,
        Map<String, dynamic>.from(command),
      ),
    );
  }

  Future<Map<String, dynamic>> executeProduct(
    Map<String, dynamic> command,
  ) async {
    _requireLibrary();
    return Isolate.run(
      () => _executeProductInWorker(Map<String, dynamic>.from(command)),
    );
  }

  Future<Map<String, dynamic>?> receive({int timeoutMs = 30000}) async {
    _requireLibrary();
    final runtimeId = await _ensureRuntime();
    return Isolate.run(() => _receiveInWorker(runtimeId, timeoutMs));
  }

  Future<void> resolveApproval(
    String approvalId,
    String decision, {
    Map<String, dynamic>? payload,
  }) async {
    _requireLibrary();
    final runtimeId = await _ensureRuntime();
    await Isolate.run(
      () => _resolveApprovalInWorker(runtimeId, {
        'approvalId': approvalId,
        'decision': decision,
        'payload': ?payload,
      }),
    );
  }

  Future<Map<String, dynamic>> sendAndCollect(
    String conversationId,
    String text, {
    String? token,
  }) async {
    final accepted = await executeRuntime({
      '@type': 'mahayana.conversation.send',
      'conversationId': conversationId,
      'text': text,
    });
    final operationId = accepted['operationId']?.toString();
    if (operationId == null || operationId.isEmpty) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_missing_operation_id',
        'Mahayana Runtime did not accept the message.',
      );
    }
    final buffer = StringBuffer();
    Map<String, dynamic>? completedMessage;
    while (true) {
      final event = await receive();
      if (event == null || event['operationId']?.toString() != operationId) {
        continue;
      }
      switch (event['@type']?.toString()) {
        case 'mahayana.message.delta':
          buffer.write(event['delta']?.toString() ?? '');
          break;
        case 'mahayana.message.completed':
          if (event['message'] is Map) {
            final message = Map<String, dynamic>.from(event['message'] as Map);
            if (message['role'] != 'user') completedMessage = message;
          }
          break;
        case 'mahayana.approval.requested':
          // Existing non-interactive callers cannot safely grant privileges.
          // Decline and let the Agent continue; interactive surfaces call
          // resolveApproval themselves when displaying the event stream.
          final approvalId = event['approvalId']?.toString();
          if (approvalId != null && approvalId.isNotEmpty) {
            await resolveApproval(approvalId, 'decline');
          }
          break;
        case 'mahayana.operation.completed':
          final message = completedMessage;
          return {
            'operationId': operationId,
            'conversationId': conversationId,
            'message': message?['text']?.toString() ?? buffer.toString(),
            'data': ?message,
            'embedded': true,
          };
        case 'mahayana.operation.failed':
          throw MahayanaCodexRuntimeException(
            event['code']?.toString() ?? 'mahayana_operation_failed',
            event['message']?.toString() ?? 'Mahayana operation failed.',
            details: event,
          );
      }
    }
  }

  Future<int> _ensureRuntime() {
    return _runtimeId ??= Isolate.run(
      () => _createRuntimeInWorker(const <String, dynamic>{}),
    );
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
        'mahayana_runtime_unavailable',
        'The embedded Mahayana Runtime is not bundled for this platform.',
        details: _loadError,
      );
    }
    return library;
  }
}

bool _isRuntimeCommand(String type) =>
    type.startsWith('mahayana.runtime.') ||
    type.startsWith('mahayana.conversation.') ||
    type.startsWith('mahayana.operation.') ||
    type.startsWith('mahayana.approval.');

int _createRuntimeInWorker(Map<String, dynamic> config) {
  final library = _openLibraryForWorker();
  final create = library
      .lookup<NativeFunction<_RuntimeCreateNative>>('mahayana_runtime_create')
      .asFunction<_RuntimeCreateDart>();
  final lastError = library
      .lookup<NativeFunction<_RuntimeLastErrorNative>>(
        'mahayana_runtime_last_error',
      )
      .asFunction<_RuntimeLastErrorDart>();
  final free = _freeFunction(library);
  final configPointer = jsonEncode(config).toNativeUtf8();
  try {
    final runtimeId = create(configPointer);
    if (runtimeId == 0) {
      final response = _takeResponse(lastError(), free);
      throw MahayanaCodexRuntimeException(
        'mahayana_runtime_create_failed',
        response['message']?.toString() ?? 'Mahayana Runtime creation failed.',
        details: response,
      );
    }
    return runtimeId;
  } finally {
    malloc.free(configPointer);
  }
}

Map<String, dynamic> _executeRuntimeInWorker(
  int runtimeId,
  Map<String, dynamic> command,
) {
  final library = _openLibraryForWorker();
  final execute = library
      .lookup<NativeFunction<_RuntimeExecuteNative>>('mahayana_runtime_execute')
      .asFunction<_RuntimeExecuteDart>();
  return _callWithJson(
    command,
    (pointer) => execute(runtimeId, pointer),
    _freeFunction(library),
  );
}

Map<String, dynamic> _executeProductInWorker(Map<String, dynamic> command) {
  final library = _openLibraryForWorker();
  final execute = library
      .lookup<NativeFunction<_ProductExecuteNative>>('mahayana_product_execute')
      .asFunction<_ProductExecuteDart>();
  return _callWithJson(command, execute, _freeFunction(library));
}

Map<String, dynamic>? _receiveInWorker(int runtimeId, int timeoutMs) {
  final library = _openLibraryForWorker();
  final receive = library
      .lookup<NativeFunction<_RuntimeReceiveNative>>('mahayana_runtime_receive')
      .asFunction<_RuntimeReceiveDart>();
  final response = _takeResponse(
    receive(runtimeId, timeoutMs),
    _freeFunction(library),
  );
  final data = _unwrapResponse(response);
  return data.isEmpty ? null : data;
}

void _resolveApprovalInWorker(int runtimeId, Map<String, dynamic> approval) {
  final library = _openLibraryForWorker();
  final resolve = library
      .lookup<NativeFunction<_RuntimeResolveNative>>(
        'mahayana_runtime_resolve_approval',
      )
      .asFunction<_RuntimeResolveDart>();
  _callWithJson(
    approval,
    (pointer) => resolve(runtimeId, pointer),
    _freeFunction(library),
  );
}

Map<String, dynamic> _callWithJson(
  Map<String, dynamic> request,
  Pointer<Utf8> Function(Pointer<Utf8>) call,
  _RuntimeFreeDart free,
) {
  final requestPointer = jsonEncode(request).toNativeUtf8();
  try {
    return _unwrapResponse(_takeResponse(call(requestPointer), free));
  } finally {
    malloc.free(requestPointer);
  }
}

Map<String, dynamic> _takeResponse(
  Pointer<Utf8> pointer,
  _RuntimeFreeDart free,
) {
  if (pointer == nullptr) {
    throw const MahayanaCodexRuntimeException(
      'mahayana_runtime_null_response',
      'Mahayana Runtime returned a null response.',
    );
  }
  try {
    final decoded = jsonDecode(pointer.toDartString());
    if (decoded is! Map) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_runtime_invalid_response',
        'Mahayana Runtime returned a non-object response.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  } finally {
    free(pointer);
  }
}

Map<String, dynamic> _unwrapResponse(Map<String, dynamic> response) {
  if (response['ok'] == true) {
    final data = response['data'];
    if (data == null) return <String, dynamic>{};
    if (data is Map) return Map<String, dynamic>.from(data);
  }
  throw MahayanaCodexRuntimeException(
    response['errorCode']?.toString() ?? 'mahayana_runtime_error',
    response['message']?.toString() ?? 'Mahayana Runtime failed.',
    details: response,
  );
}

_RuntimeFreeDart _freeFunction(DynamicLibrary library) => library
    .lookup<NativeFunction<_RuntimeFreeNative>>('mahayana_runtime_free_string')
    .asFunction<_RuntimeFreeDart>();

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
    'mahayana_runtime_unavailable',
    'The embedded Mahayana Runtime is not bundled for this platform.',
    details: errors.join('\n'),
  );
}

List<String> _libraryCandidates() => <String>[
  if (Platform.isAndroid) 'libmahayana_runtime.so',
  if (Platform.isLinux)
    '${File(Platform.resolvedExecutable).parent.path}/lib/libmahayana_runtime.so',
  if (Platform.isLinux) 'libmahayana_runtime.so',
  if (Platform.isMacOS)
    '${File(Platform.resolvedExecutable).parent.parent.path}/Frameworks/libmahayana_runtime.dylib',
  if (Platform.isMacOS) 'libmahayana_runtime.dylib',
  if (Platform.isWindows)
    '${File(Platform.resolvedExecutable).parent.path}\\mahayana_runtime.dll',
  if (Platform.isWindows) 'mahayana_runtime.dll',
];

void _verifySymbols(DynamicLibrary library) {
  library.lookup<NativeFunction<_RuntimeCreateNative>>(
    'mahayana_runtime_create',
  );
  library.lookup<NativeFunction<_RuntimeExecuteNative>>(
    'mahayana_runtime_execute',
  );
  library.lookup<NativeFunction<_RuntimeReceiveNative>>(
    'mahayana_runtime_receive',
  );
  library.lookup<NativeFunction<_RuntimeResolveNative>>(
    'mahayana_runtime_resolve_approval',
  );
  library.lookup<NativeFunction<_ProductExecuteNative>>(
    'mahayana_product_execute',
  );
  library.lookup<NativeFunction<_RuntimeFreeNative>>(
    'mahayana_runtime_free_string',
  );
}

class MahayanaCodexRuntimeException implements Exception {
  const MahayanaCodexRuntimeException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}

typedef _RuntimeCreateNative = Uint64 Function(Pointer<Utf8> config);
typedef _RuntimeCreateDart = int Function(Pointer<Utf8> config);
typedef _RuntimeExecuteNative =
    Pointer<Utf8> Function(Uint64 runtimeId, Pointer<Utf8> request);
typedef _RuntimeExecuteDart =
    Pointer<Utf8> Function(int runtimeId, Pointer<Utf8> request);
typedef _RuntimeReceiveNative =
    Pointer<Utf8> Function(Uint64 runtimeId, Uint64 timeoutMs);
typedef _RuntimeReceiveDart =
    Pointer<Utf8> Function(int runtimeId, int timeoutMs);
typedef _RuntimeResolveNative =
    Pointer<Utf8> Function(Uint64 runtimeId, Pointer<Utf8> request);
typedef _RuntimeResolveDart =
    Pointer<Utf8> Function(int runtimeId, Pointer<Utf8> request);
typedef _RuntimeLastErrorNative = Pointer<Utf8> Function();
typedef _RuntimeLastErrorDart = Pointer<Utf8> Function();
typedef _ProductExecuteNative = Pointer<Utf8> Function(Pointer<Utf8> request);
typedef _ProductExecuteDart = Pointer<Utf8> Function(Pointer<Utf8> request);
typedef _RuntimeFreeNative = Void Function(Pointer<Utf8> pointer);
typedef _RuntimeFreeDart = void Function(Pointer<Utf8> pointer);
