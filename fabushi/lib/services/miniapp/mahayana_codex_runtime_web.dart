import 'dart:convert';
import 'dart:js_interop';

@JS('mahayanaWasm.initialize')
external JSPromise<JSAny?> _initializeWasm();

@JS('mahayanaWasm.createRuntime')
external JSPromise<JSNumber> _createWasmRuntime(JSString configJson);

@JS('mahayanaWasm.execute')
external JSPromise<JSString> _executeWasmRuntime(
  JSNumber runtimeId,
  JSString commandJson,
);

@JS('mahayanaWasm.executeProduct')
external JSPromise<JSString> _executeWasmProduct(
  JSNumber runtimeId,
  JSString commandJson,
);

@JS('mahayanaWasm.receive')
external JSPromise<JSAny?> _receiveWasmRuntime(JSNumber runtimeId);

@JS('mahayanaWasm.closeRuntime')
external JSPromise<JSAny?> _closeWasmRuntime(JSNumber runtimeId);

/// Flutter Web bridge to the browser-native Mahayana WebAssembly Runtime.
///
/// Product account/social requests use their normal product APIs. Agent state
/// and the Responses call run through WebAssembly and browser Fetch directly;
/// this bridge never calls a cloud Agent command gateway.
class MahayanaCodexRuntime {
  MahayanaCodexRuntime._();

  static final MahayanaCodexRuntime instance = MahayanaCodexRuntime._();

  Future<void>? _initialization;
  int? _runtimeId;
  String? _runtimeModel;
  String? _runtimeResponsesBaseUrl;
  String? _loadError;

  bool get isAvailable => true;
  String? get loadError => _loadError;

  Future<Map<String, dynamic>> run(Map<String, dynamic> request) async {
    final prompt = (request['prompt'] ?? request['message'])?.toString().trim();
    if (prompt == null || prompt.isEmpty) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_empty_prompt',
        'Codex prompt must not be empty.',
      );
    }
    final result = await sendAndCollect(
      'codex:agent:assistant',
      prompt,
      model: _model(request),
      responsesBaseUrl: _responsesBaseUrl(request),
    );
    return {
      ...result,
      '@type': 'mahayana.codex.turn',
      'finalResponse': result['message'],
    };
  }

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
      return sendAndCollect(
        'miniapp:$miniAppId',
        message,
        model: _model(request),
        responsesBaseUrl: _responsesBaseUrl(request),
      );
    }
    if (_isRuntimeCommand(type)) {
      return executeRuntime(
        request,
        model: _model(request),
        responsesBaseUrl: _responsesBaseUrl(request),
      );
    }
    return executeProduct(request);
  }

  Future<Map<String, dynamic>> executeRuntime(
    Map<String, dynamic> command, {
    String? model,
    String? responsesBaseUrl,
  }) async {
    final runtimeId = await _ensureRuntime(model, responsesBaseUrl);
    final normalized = Map<String, dynamic>.from(command)
      ..remove('token')
      ..remove('model')
      ..remove('responsesBaseUrl')
      ..remove('telegramClientId')
      ..remove('telegramSelfUserId');
    try {
      final response = await _executeWasmRuntime(
        runtimeId.toJS,
        jsonEncode(normalized).toJS,
      ).toDart;
      return _unwrapWasm(response.toDart);
    } catch (error) {
      if (error is MahayanaCodexRuntimeException) rethrow;
      throw _wasmError('mahayana_web_execute_failed', error);
    }
  }

  Future<Map<String, dynamic>> executeProduct(
    Map<String, dynamic> command,
  ) async {
    final runtimeId = await _ensureRuntime(
      _runtimeModel,
      _runtimeResponsesBaseUrl,
    );
    try {
      final response = await _executeWasmProduct(
        runtimeId.toJS,
        jsonEncode(command).toJS,
      ).toDart;
      return _unwrapWasm(response.toDart);
    } catch (error) {
      if (error is MahayanaCodexRuntimeException) rethrow;
      throw _wasmError('mahayana_web_product_failed', error);
    }
  }

  Future<Map<String, dynamic>?> receive({int timeoutMs = 30000}) async {
    final runtimeId = _runtimeId;
    if (runtimeId == null) return null;
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (true) {
      final raw = await _receiveWasmRuntime(runtimeId.toJS).toDart;
      if (raw != null) return _unwrapWasm((raw as JSString).toDart);
      if (DateTime.now().isAfter(deadline)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> resolveApproval(
    String approvalId,
    String decision, {
    Map<String, dynamic>? payload,
  }) async {
    await executeRuntime(
      {
        '@type': 'mahayana.approval.resolve',
        'approvalId': approvalId,
        'decision': decision,
        'payload': ?payload,
      },
      model: _runtimeModel,
      responsesBaseUrl: _runtimeResponsesBaseUrl,
    );
  }

  Future<Map<String, dynamic>> sendAndCollect(
    String conversationId,
    String text, {
    String? model,
    String? responsesBaseUrl,
  }) async {
    final accepted = await executeRuntime(
      {
        '@type': 'mahayana.conversation.send',
        'conversationId': conversationId,
        'text': text,
      },
      model: model,
      responsesBaseUrl: responsesBaseUrl,
    );
    final operationId = accepted['operationId']?.toString();
    if (operationId == null || operationId.isEmpty) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_missing_operation_id',
        'Mahayana Web Runtime did not accept the message.',
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
            completedMessage = Map<String, dynamic>.from(
              event['message'] as Map,
            );
          }
          break;
        case 'mahayana.operation.completed':
          return {
            'operationId': operationId,
            'conversationId': conversationId,
            'message':
                completedMessage?['text']?.toString() ?? buffer.toString(),
            'data': ?completedMessage,
            'embedded': true,
            'platform': 'web-wasm',
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

  Future<int> _ensureRuntime(String? model, String? responsesBaseUrl) async {
    final normalizedModel = _normalize(model) ?? 'deepseek-chat';
    final normalizedBaseUrl =
        _normalize(responsesBaseUrl) ??
        'https://api.ombhrum.com/codex-deepseek/v1';
    if (_runtimeId != null) return _runtimeId!;
    await _initialize();
    return _replaceRuntime(normalizedModel, normalizedBaseUrl);
  }

  Future<void> _initialize() {
    return _initialization ??= () async {
      try {
        await _initializeWasm().toDart;
        _loadError = null;
      } catch (error) {
        _loadError = error.toString();
        throw _wasmError('mahayana_web_initialize_failed', error);
      }
    }();
  }

  Future<int> _replaceRuntime(String model, String responsesBaseUrl) async {
    await _closeExistingRuntime();
    _runtimeModel = model;
    _runtimeResponsesBaseUrl = responsesBaseUrl;
    try {
      final runtimeId = (await _createWasmRuntime(
        jsonEncode({'model': model, 'responsesBaseUrl': responsesBaseUrl}).toJS,
      ).toDart).toDartInt;
      _runtimeId = runtimeId;
      return runtimeId;
    } catch (error) {
      throw _wasmError('mahayana_web_create_failed', error);
    }
  }

  Future<void> _closeExistingRuntime() async {
    final existing = _runtimeId;
    if (existing != null) await _closeWasmRuntime(existing.toJS).toDart;
    _runtimeId = null;
    _runtimeModel = null;
    _runtimeResponsesBaseUrl = null;
  }
}

bool _isRuntimeCommand(String type) =>
    type.startsWith('mahayana.runtime.') ||
    type.startsWith('mahayana.conversation.') ||
    type.startsWith('mahayana.plugin.') ||
    type.startsWith('mahayana.operation.') ||
    type.startsWith('mahayana.approval.');

String? _model(Map<String, dynamic> request) =>
    _normalize(request['model']?.toString());

String? _responsesBaseUrl(Map<String, dynamic> request) =>
    _normalize(request['responsesBaseUrl']?.toString());

String? _normalize(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Map<String, dynamic> _unwrapWasm(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const MahayanaCodexRuntimeException(
      'mahayana_web_invalid_response',
      'Mahayana WebAssembly returned a non-object response.',
    );
  }
  final response = Map<String, dynamic>.from(decoded);
  if (response['ok'] == true && response['data'] is Map) {
    return Map<String, dynamic>.from(response['data'] as Map);
  }
  throw MahayanaCodexRuntimeException(
    response['errorCode']?.toString() ?? 'mahayana_web_error',
    response['message']?.toString() ?? 'Mahayana WebAssembly failed.',
    details: response,
  );
}

MahayanaCodexRuntimeException _wasmError(String code, Object error) =>
    MahayanaCodexRuntimeException(
      code,
      'Mahayana WebAssembly Runtime failed.',
      details: error,
    );

class MahayanaCodexRuntimeException implements Exception {
  const MahayanaCodexRuntimeException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}
