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
      token: _token(request),
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
        token: _token(request),
        model: _model(request),
        responsesBaseUrl: _responsesBaseUrl(request),
      );
    }
    if (_isRuntimeCommand(type)) {
      return executeRuntime(
        request,
        token: _token(request),
        model: _model(request),
        responsesBaseUrl: _responsesBaseUrl(request),
      );
    }
    return executeProduct(request);
  }

  Future<Map<String, dynamic>> executeRuntime(
    Map<String, dynamic> command, {
    String? token,
    String? model,
    String? responsesBaseUrl,
  }) async {
    final runtimeId = await _ensureRuntime(token, model, responsesBaseUrl);
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
    final type = command['@type']?.toString() ?? '';
    final token = _token(command);
    switch (type) {
      case 'mahayana.auth.session.sync':
        await _closeExistingRuntime();
        return {
          '@type': 'mahayana.auth.session',
          'loggedIn': token != null,
          'sessionStored': false,
          'inMemory': true,
          'provider': command['provider']?.toString() ?? 'app',
        };
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
      case 'mahayana.auth.password.login':
        return _productRequest(
          'POST',
          '/api/auth/login',
          body: {
            'username': _required(command, 'username'),
            'password': _required(command, 'password'),
          },
        );
      case 'mahayana.auth.register':
        return _productRequest(
          'POST',
          '/api/auth/register',
          body: {
            'username': _required(command, 'username'),
            'email': _required(command, 'email'),
            'password': _required(command, 'password'),
            'verificationCode': _required(command, 'verificationCode'),
          },
        );
      case 'mahayana.auth.verification.send':
        return _productRequest(
          'POST',
          '/api/auth/send-verification-code',
          body: {
            'email': _required(command, 'email'),
            'type': _required(command, 'type'),
          },
        );
      case 'mahayana.auth.password.forgot':
        return _productRequest(
          'POST',
          '/api/auth/forgot-password',
          body: {'email': _required(command, 'email')},
        );
      case 'mahayana.auth.password.reset':
        return _productRequest(
          'POST',
          '/api/auth/reset-password',
          body: {
            'email': _required(command, 'email'),
            'token': _required(command, 'resetToken'),
            'newPassword': _required(command, 'newPassword'),
          },
        );
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
      case 'mahayana.auth.alipay.register':
        return _productRequest(
          'POST',
          '/api/auth/alipay/register',
          body: {
            'alipayProviderSubject': _required(
              command,
              'alipayProviderSubject',
            ),
            'alipaySubjectType': ?_optional(command, 'alipaySubjectType'),
            'username': ?_optional(command, 'username'),
            'password': ?_optional(command, 'password'),
            'nickname': ?_optional(command, 'nickname'),
            'avatar': ?_optional(command, 'avatar'),
            'email': ?_optional(command, 'email'),
            'alipayNickname': ?_optional(command, 'alipayNickname'),
            'alipayAvatar': ?_optional(command, 'alipayAvatar'),
            if (command['oneClick'] == true) 'oneClick': true,
          },
        );
      case 'mahayana.auth.apple.complete':
        return _productRequest(
          'POST',
          '/api/auth/apple-login',
          body: {
            'identityToken': _required(command, 'identityToken'),
            'authorizationCode': _required(command, 'authorizationCode'),
            'email': ?_optional(command, 'email'),
            'givenName': ?_optional(command, 'givenName'),
            'familyName': ?_optional(command, 'familyName'),
          },
        );
      case 'mahayana.auth.firebase.phone.complete':
        return _productRequest(
          'POST',
          '/api/auth/firebase-phone-login',
          body: {
            'idToken': _required(command, 'idToken'),
            'phoneNumber': _required(command, 'phoneNumber'),
            'firebaseUid': _required(command, 'firebaseUid'),
            'isNewUser': command['isNewUser'] == true,
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
      case 'mahayana.miniapps.registry':
        return _productRequest('GET', '/api/miniapps/registry', token: token);
      case 'mahayana.miniapp.sandbox.publish':
        return _publishMiniApp(command, token: token);
      case 'mahayana.miniapp.review.submit':
        final miniAppId = Uri.encodeComponent(_required(command, 'miniAppId'));
        return _productRequest(
          'POST',
          '/api/miniapps/$miniAppId/submit-review',
          token: token,
          body: const {},
        );
      default:
        throw MahayanaCodexRuntimeException(
          'mahayana_unsupported_product_command',
          'Unsupported Mahayana product command: $type',
        );
    }
  }

  Future<Map<String, dynamic>> _publishMiniApp(
    Map<String, dynamic> command, {
    String? token,
  }) async {
    final title = _required(command, 'title');
    final sourceHtml = _required(command, 'sourceHtml');
    final subtitle = _optional(command, 'subtitle') ?? '大乘 Web SDK 生成的个人沙箱小程序';
    final prompt = _optional(command, 'prompt') ?? title;
    final permissions = command['permissions'] is List
        ? List<dynamic>.from(command['permissions'] as List)
        : <String>['app.context', 'bot.chat'];
    final created = await _productRequest(
      'POST',
      '/api/miniapps/dev/create',
      token: token,
      body: {
        'title': title,
        'subtitle': subtitle,
        'prompt': prompt,
        'permissions': permissions,
      },
    );
    final miniApp = created['miniApp'];
    final rawMiniAppId = miniApp is Map
        ? miniApp['miniAppId']?.toString()
        : null;
    if (rawMiniAppId == null || rawMiniAppId.trim().isEmpty) {
      throw const MahayanaCodexRuntimeException(
        'mahayana_missing_miniapp_id',
        'Sandbox create response has no miniAppId.',
      );
    }
    final miniAppId = Uri.encodeComponent(rawMiniAppId.trim());
    final updated = await _productRequest(
      'POST',
      '/api/miniapps/dev/$miniAppId/version',
      token: token,
      body: {
        'title': title,
        'subtitle': subtitle,
        'prompt': prompt,
        'sourceHtml': sourceHtml,
        'permissions': permissions,
        'version': _optional(command, 'version') ?? '0.0.1',
      },
    );
    Map<String, dynamic>? review;
    if (command['submitReview'] == true) {
      review = await _productRequest(
        'POST',
        '/api/miniapps/$miniAppId/submit-review',
        token: token,
        body: const {},
      );
    }
    return {
      '@type': 'mahayana.miniapp.published',
      'success': true,
      'authenticated': token != null,
      'miniAppId': rawMiniAppId,
      'miniApp': updated['miniApp'],
      'bot': updated['bot'],
      'scan': updated['scan'],
      'review': review,
    };
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
      token: _runtimeToken,
      model: _runtimeModel,
      responsesBaseUrl: _runtimeResponsesBaseUrl,
    );
  }

  Future<Map<String, dynamic>> sendAndCollect(
    String conversationId,
    String text, {
    String? token,
    String? model,
    String? responsesBaseUrl,
  }) async {
    final accepted = await executeRuntime(
      {
        '@type': 'mahayana.conversation.send',
        'conversationId': conversationId,
        'text': text,
      },
      token: token,
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

  Future<int> _ensureRuntime(
    String? token,
    String? model,
    String? responsesBaseUrl,
  ) async {
    final normalizedToken = _normalize(token);
    final normalizedModel = _normalize(model) ?? 'deepseek-chat';
    final normalizedBaseUrl =
        _normalize(responsesBaseUrl) ??
        'https://api.ombhrum.com/codex-deepseek/v1';
    if (_runtimeId != null &&
        _runtimeToken == normalizedToken &&
        _runtimeModel == normalizedModel &&
        _runtimeResponsesBaseUrl == normalizedBaseUrl) {
      return _runtimeId!;
    }
    await _initialize();
    return _replaceRuntime(normalizedToken, normalizedModel, normalizedBaseUrl);
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

  Future<int> _replaceRuntime(
    String? token,
    String model,
    String responsesBaseUrl,
  ) async {
    await _closeExistingRuntime();
    _runtimeToken = token;
    _runtimeModel = model;
    _runtimeResponsesBaseUrl = responsesBaseUrl;
    try {
      final runtimeId = (await _createWasmRuntime(
        jsonEncode({
          'productSessionToken': ?token,
          'model': model,
          'responsesBaseUrl': responsesBaseUrl,
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
    _runtimeModel = null;
    _runtimeResponsesBaseUrl = null;
  }
}

bool _isRuntimeCommand(String type) =>
    type.startsWith('mahayana.runtime.') ||
    type.startsWith('mahayana.conversation.') ||
    type.startsWith('mahayana.operation.') ||
    type.startsWith('mahayana.approval.');

String? _token(Map<String, dynamic> request) {
  return _normalize(request['token']?.toString());
}

String? _model(Map<String, dynamic> request) =>
    _normalize(request['model']?.toString());

String? _responsesBaseUrl(Map<String, dynamic> request) =>
    _normalize(request['responsesBaseUrl']?.toString());

String? _normalize(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
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
