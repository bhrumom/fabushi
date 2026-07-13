import 'dart:convert';
import 'dart:js_interop';

import 'package:http/http.dart' as http;

@JS('mahayanaWasm.initialize')
external JSPromise<JSAny?> _initializeWasm();

@JS('mahayanaWasm.createRuntime')
external JSPromise<JSNumber> _createWasmRuntime(JSString configJson);

@JS('mahayanaWasm.execute')
external JSPromise<JSString> _executeWasmRuntime(
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
  String? _runtimeToken;
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
    return sendAndCollect(
      'codex:agent:assistant',
      prompt,
      token: _token(request),
    );
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
        token: _token(request),
      );
    }
    if (_isRuntimeCommand(type)) {
      return executeRuntime(request, token: _token(request));
    }
    return executeProduct(request);
  }

  Future<Map<String, dynamic>> executeRuntime(
    Map<String, dynamic> command, {
    String? token,
  }) async {
    final runtimeId = await _ensureRuntime(token);
    final normalized = Map<String, dynamic>.from(command)..remove('token');
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
    final type = command['@type']?.toString() ?? '';
    final token = _token(command);
    switch (type) {
      case 'mahayana.auth.status':
        if (token == null) {
          return const {
            '@type': 'mahayana.auth.status',
            'loggedIn': false,
            'provider': 'alipay',
          };
        }
        try {
          final user = await _productRequest(
            'GET',
            '/api/auth/user-info',
            token: token,
          );
          return {
            '@type': 'mahayana.auth.status',
            'loggedIn': true,
            'provider': 'alipay',
            'user': user['user'] ?? user['data'] ?? user,
          };
        } catch (_) {
          return const {
            '@type': 'mahayana.auth.status',
            'loggedIn': false,
            'provider': 'alipay',
            'expired': true,
          };
        }
      case 'mahayana.auth.logout':
        await _closeExistingRuntime();
        return const {
          '@type': 'mahayana.auth.loggedOut',
          'loggedIn': false,
          'provider': 'alipay',
        };
      case 'mahayana.auth.alipay.start':
        return _productRequest(
          'GET',
          '/api/auth/alipay/login-url',
          query: {'platform': command['platform']?.toString() ?? 'web'},
        );
      case 'mahayana.auth.alipay.complete':
        return _productRequest(
          'POST',
          '/api/auth/alipay/login',
          body: {
            'auth_code': _required(command, 'authCode'),
            'state': ?_optional(command, 'state'),
          },
        );
      case 'mahayana.auth.alipay.poll':
        return _productRequest(
          'GET',
          '/api/auth/alipay/cli-session',
          query: {'state': _required(command, 'state')},
        );
      case 'mahayana.auth.alipay.sdk.start':
        return _productRequest('GET', '/api/auth/alipay/auth-string');
      case 'mahayana.auth.alipay.sdk.complete':
        return _productRequest(
          'POST',
          '/api/auth/alipay/sdk-login',
          body: {
            'auth_code': _required(command, 'authCode'),
            'target_id': ?_optional(command, 'targetId'),
          },
        );
      case 'mahayana.contacts.list':
        return _productRequest('GET', '/api/social/friends', token: token);
      case 'mahayana.contacts.search':
        return _productRequest(
          'GET',
          '/api/social/users/search',
          token: token,
          query: {'q': _required(command, 'query')},
        );
      case 'mahayana.contacts.add':
        return _productRequest(
          'POST',
          '/api/social/friend-requests',
          token: token,
          body: {
            'targetUserId': _required(command, 'contact'),
            'message': ?_optional(command, 'message'),
          },
        );
      case 'mahayana.contacts.requests':
        return _productRequest(
          'GET',
          '/api/social/friend-requests/incoming',
          token: token,
        );
      case 'mahayana.contacts.accept':
        final requestId = Uri.encodeComponent(_required(command, 'requestId'));
        return _productRequest(
          'POST',
          '/api/social/friend-requests/$requestId/accept',
          token: token,
          body: const {},
        );
      case 'mahayana.messages.list':
        return _productRequest(
          'GET',
          '/api/social/messages',
          token: token,
          query: {
            'contactId': _required(command, 'contact'),
            if (command['limit'] != null) 'limit': command['limit'].toString(),
          },
        );
      case 'mahayana.messages.send':
        return _productRequest(
          'POST',
          '/api/social/messages',
          token: token,
          body: {
            'contactId': _required(command, 'contact'),
            'text': _required(command, 'text'),
            'clientRequestId': ?_optional(command, 'clientRequestId'),
          },
        );
      default:
        throw MahayanaCodexRuntimeException(
          'mahayana_unsupported_product_command',
          'Unsupported Mahayana product command: $type',
        );
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
    await executeRuntime({
      '@type': 'mahayana.approval.resolve',
      'approvalId': approvalId,
      'decision': decision,
      'payload': ?payload,
    }, token: _runtimeToken);
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
    }, token: token);
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

  Future<int> _ensureRuntime(String? token) async {
    final normalized = token?.trim();
    if (_runtimeId != null && _runtimeToken == normalized) return _runtimeId!;
    await _initialize();
    return _replaceRuntime(normalized);
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

  Future<int> _replaceRuntime(String? token) async {
    await _closeExistingRuntime();
    _runtimeToken = token;
    try {
      final runtimeId = (await _createWasmRuntime(
        jsonEncode({
          'productSessionToken': ?token,
          'model': 'deepseek-chat',
          'responsesBaseUrl': 'https://api.ombhrum.com/codex-deepseek/v1',
        }).toJS,
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
    _runtimeToken = null;
  }
}

bool _isRuntimeCommand(String type) =>
    type.startsWith('mahayana.runtime.') ||
    type.startsWith('mahayana.conversation.') ||
    type.startsWith('mahayana.operation.') ||
    type.startsWith('mahayana.approval.');

String? _token(Map<String, dynamic> request) {
  final token = request['token']?.toString().trim();
  return token == null || token.isEmpty ? null : token;
}

String _required(Map<String, dynamic> request, String key) {
  final value = _optional(request, key);
  if (value == null) {
    throw MahayanaCodexRuntimeException(
      'mahayana_invalid_product_command',
      'Mahayana product command requires $key.',
    );
  }
  return value;
}

String? _optional(Map<String, dynamic> request, String key) {
  final value = request[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

Future<Map<String, dynamic>> _productRequest(
  String method,
  String path, {
  String? token,
  Map<String, String>? query,
  Map<String, dynamic>? body,
}) async {
  final uri = Uri.base.resolve(path).replace(queryParameters: query);
  final headers = <String, String>{
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    if (body != null) 'Content-Type': 'application/json',
  };
  final response = method == 'GET'
      ? await http.get(uri, headers: headers)
      : await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
  Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    decoded = null;
  }
  final payload = decoded is Map
      ? Map<String, dynamic>.from(decoded)
      : <String, dynamic>{};
  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      payload['success'] == false ||
      payload['error'] != null) {
    throw MahayanaCodexRuntimeException(
      'mahayana_product_http_error',
      (payload['error'] ??
              payload['message'] ??
              'Product API returned HTTP ${response.statusCode}')
          .toString(),
      details: {'status': response.statusCode},
    );
  }
  return payload;
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
