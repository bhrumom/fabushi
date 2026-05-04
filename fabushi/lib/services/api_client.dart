import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import 'app_settings.dart';
import 'worker_config.dart';

abstract class ApiRequester {
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    String? token,
  });

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  });

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  });

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  });
}

/// 统一的 API 客户端
/// 处理所有与 Cloudflare Worker 的 HTTP 通信
class ApiClient implements ApiRequester {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  final http.Client _httpClient;
  final Future<String> Function() _baseUrlResolver;
  final Duration _timeout;

  ApiClient._({
    http.Client? httpClient,
    Future<String> Function()? baseUrlResolver,
    Duration? timeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrlResolver = baseUrlResolver ?? AppSettings.getBackendUrl,
       _timeout = timeout ?? AppConfig.requestTimeout;

  // 公共构造函数，用于直接实例化
  factory ApiClient({
    http.Client? httpClient,
    Future<String> Function()? baseUrlResolver,
    Duration? timeout,
  }) {
    if (httpClient != null || baseUrlResolver != null || timeout != null) {
      return ApiClient._(
        httpClient: httpClient,
        baseUrlResolver: baseUrlResolver,
        timeout: timeout,
      );
    }
    return instance;
  }

  Future<String> get baseUrl => _baseUrlResolver();

  @override
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    String? token,
  }) async {
    try {
      final uri = await _buildUri(endpoint, queryParams: queryParams);
      final requestHeaders = _buildHeaders(headers: headers, token: token);

      debugPrint('🌐 GET: $uri');

      final response = await _httpClient
          .get(uri, headers: requestHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleTransportError('GET', e);
    }
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final uri = await _buildUri(endpoint);
      final requestHeaders = _buildHeaders(headers: headers, token: token);

      debugPrint('🌐 POST: $uri');
      if (body != null) {
        debugPrint('📤 Body: ${jsonEncode(body)}');
      }

      final response = await _httpClient
          .post(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleTransportError('POST', e);
    }
  }

  @override
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final uri = await _buildUri(endpoint);
      final requestHeaders = _buildHeaders(headers: headers, token: token);

      debugPrint('🌐 PUT: $uri');

      final response = await _httpClient
          .put(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleTransportError('PUT', e);
    }
  }

  @override
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final uri = await _buildUri(endpoint);
      final requestHeaders = _buildHeaders(headers: headers, token: token);

      debugPrint('🌐 DELETE: $uri');

      final response = await _httpClient
          .delete(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleTransportError('DELETE', e);
    }
  }

  Future<Uri> _buildUri(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final url = await baseUrl;
    var uri = Uri.parse('$url$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Map<String, String> _buildHeaders({
    Map<String, String>? headers,
    String? token,
  }) {
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };

    if (token != null && token.isNotEmpty) {
      requestHeaders['Authorization'] = 'Bearer $token';
      debugPrint(
        '🔐 ApiClient: 添加认证头 Authorization: Bearer ${_safeTokenPreview(token)}',
      );
    } else {
      debugPrint('⚠️ ApiClient: 没有token');
    }

    return requestHeaders;
  }

  String _safeTokenPreview(String token) {
    final previewLength = token.length < 20 ? token.length : 20;
    return '${token.substring(0, previewLength)}...';
  }

  Map<String, dynamic> _handleTransportError(String method, Object error) {
    debugPrint('❌ $method 请求失败: $error');

    final details = error is TimeoutException
        ? 'Request timed out after ${_timeout.inSeconds} seconds'
        : error.toString();

    return {
      'success': false,
      'error': WorkerConfig.getErrorMessage('NETWORK_ERROR'),
      'errorKey': 'NETWORK_ERROR',
      'details': details,
    };
  }

  // 处理响应
  Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('📥 Response: ${response.statusCode} ${response.reasonPhrase}');
    debugPrint('📄 原始响应体: ${response.body}');

    if (response.statusCode == 401) {
      debugPrint('❌ 401 认证失败 - 请求头: ${response.request?.headers}');
    }

    final data = _decodeResponseBody(response.body);
    debugPrint('📊 解析后数据: $data');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data == null) {
        return {'success': true, 'statusCode': response.statusCode};
      }

      if (data is Map<String, dynamic>) {
        return {
          ...data,
          if (!data.containsKey('statusCode')) 'statusCode': response.statusCode,
        };
      }

      return {
        'success': true,
        'statusCode': response.statusCode,
        'data': data,
      };
    }

    final error = _extractErrorMessage(data);
    return {
      'success': false,
      'statusCode': response.statusCode,
      'error': error,
      'errorKey': _mapErrorKey(response.statusCode),
      'details': data ?? response.body,
    };
  }

  dynamic _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (e) {
      debugPrint('❌ 解析响应失败: $e');
      debugPrint('📄 原始响应: $body');
      return body;
    }
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return '请求失败';
  }

  String _mapErrorKey(int statusCode) {
    if (statusCode == 401) {
      return 'INVALID_TOKEN';
    }
    if (statusCode == 403) {
      return 'UNAUTHORIZED';
    }
    if (statusCode == 400 || statusCode == 422) {
      return 'VALIDATION_ERROR';
    }
    if (statusCode >= 500) {
      return 'SERVER_ERROR';
    }
    return 'UNKNOWN_ERROR';
  }

  // 认证相关快捷方法
  Future<Map<String, dynamic>> login(String username, String password) {
    return post(
      WorkerConfig.getEndpoint('login'),
      body: {'username': username, 'password': password},
    );
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String verificationCode,
  ) {
    return post(
      WorkerConfig.getEndpoint('register'),
      body: {
        'username': username,
        'email': email,
        'password': password,
        'verificationCode': verificationCode,
      },
    );
  }

  Future<Map<String, dynamic>> sendVerificationCode(
    String email, {
    String type = 'register',
  }) {
    return post(
      WorkerConfig.getEndpoint('sendVerificationCode'),
      body: {'email': email, 'type': type},
    );
  }

  Future<Map<String, dynamic>> verifyToken(String token) {
    return get(WorkerConfig.getEndpoint('verify'), token: token);
  }

  Future<Map<String, dynamic>> getUserInfo(String token) {
    return get(WorkerConfig.getEndpoint('userInfo'), token: token);
  }

  Future<Map<String, dynamic>> getMembershipStatus(String token) {
    return get(WorkerConfig.getEndpoint('membershipStatus'), token: token);
  }

  Future<Map<String, dynamic>> useRedeemCode(String token, String code) {
    return post(
      WorkerConfig.getEndpoint('adminUseRedeemCode'),
      body: {'code': code},
      token: token,
    );
  }
}
