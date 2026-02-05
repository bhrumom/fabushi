// 统一API服务
// 使用统一配置管理所有API调用

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class UnifiedApiService {
  static final UnifiedApiService _instance = UnifiedApiService._internal();
  factory UnifiedApiService() => _instance;
  UnifiedApiService._internal();

  // HTTP客户端
  http.Client? _client;

  // 初始化
  void initialize() {
    if (_client == null) {
      _client = http.Client();
      if (AppConfig.enableApiLogging) {
        AppConfig.printCurrentConfig();
      }
    }
  }

  // 销毁
  void dispose() {
    _client?.close();
    _client = null;
  }

  // ===== 通用请求方法 =====

  // GET请求
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final requestHeaders = _buildHeaders(headers);

    if (AppConfig.enableApiLogging) {
      debugPrint('GET请求: $uri');
      debugPrint('请求头: $requestHeaders');
    }

    return await _executeWithRetry(() async {
      final response = await (_client ?? http.Client())
          .get(uri, headers: requestHeaders)
          .timeout(AppConfig.requestTimeout);

      if (AppConfig.enableApiLogging) {
        debugPrint('GET响应: ${response.statusCode} - ${response.body}');
      }

      return response;
    });
  }

  // POST请求
  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final requestHeaders = _buildHeaders(headers);
    final requestBody = body != null ? jsonEncode(body) : null;

    if (AppConfig.enableApiLogging) {
      debugPrint('POST请求: $uri');
      debugPrint('请求头: $requestHeaders');
      debugPrint('请求体: $requestBody');
    }

    return await _executeWithRetry(() async {
      final response = await (_client ?? http.Client())
          .post(uri, headers: requestHeaders, body: requestBody)
          .timeout(AppConfig.requestTimeout);

      if (AppConfig.enableApiLogging) {
        debugPrint('POST响应: ${response.statusCode} - ${response.body}');
      }

      return response;
    });
  }

  // PUT请求
  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final requestHeaders = _buildHeaders(headers);
    final requestBody = body != null ? jsonEncode(body) : null;

    if (AppConfig.enableApiLogging) {
      debugPrint('PUT请求: $uri');
    }

    return await _executeWithRetry(() async {
      final response = await (_client ?? http.Client())
          .put(uri, headers: requestHeaders, body: requestBody)
          .timeout(AppConfig.requestTimeout);

      if (AppConfig.enableApiLogging) {
        debugPrint('PUT响应: ${response.statusCode}');
      }

      return response;
    });
  }

  // DELETE请求
  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final requestHeaders = _buildHeaders(headers);

    if (AppConfig.enableApiLogging) {
      debugPrint('DELETE请求: $uri');
    }

    return await _executeWithRetry(() async {
      final response = await (_client ?? http.Client())
          .delete(uri, headers: requestHeaders)
          .timeout(AppConfig.requestTimeout);

      if (AppConfig.enableApiLogging) {
        debugPrint('DELETE响应: ${response.statusCode}');
      }

      return response;
    });
  }

  // ===== 认证相关API =====

  // 登录
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await post('/api/auth/login', body: {'email': email, 'password': password});

    return _handleResponse(response);
  }

  // 注册
  Future<Map<String, dynamic>> register(String email, String password) async {
    final response = await post('/api/auth/register', body: {'email': email, 'password': password});

    return _handleResponse(response);
  }

  // 获取用户信息
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    final response = await get('/api/auth/user-info', headers: {'Authorization': 'Bearer $token'});

    return _handleResponse(response);
  }

  // ===== 会员相关API =====

  // 检查会员状态
  Future<Map<String, dynamic>> checkMembershipStatus(String token) async {
    final response = await get(
      '/api/stripe/membership-status',
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  // ===== 支付宝相关API =====

  // 创建支付宝订单
  Future<Map<String, dynamic>> createAlipayOrder(
    String token,
    Map<String, dynamic> orderData,
  ) async {
    final response = await post(
      '/api/alipay/create-order',
      headers: {'Authorization': 'Bearer $token'},
      body: orderData,
    );

    return _handleResponse(response);
  }

  // ===== 管理员相关API =====

  // 检查管理员状态
  Future<Map<String, dynamic>> checkAdminStatus(String token) async {
    final response = await get(
      '/api/admin/check-status',
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  // ===== 私有方法 =====

  // 构建URI
  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final baseUrl = AppConfig.currentBackendUrl;
    final fullUrl = endpoint.startsWith('http') ? endpoint : '$baseUrl$endpoint';

    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(fullUrl).replace(queryParameters: queryParams);
    }

    return Uri.parse(fullUrl);
  }

  // 构建请求头
  Map<String, String> _buildHeaders(Map<String, String>? customHeaders) {
    final headers = Map<String, String>.from(AppConfig.defaultHeaders);

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  // 带重试的请求执行
  Future<http.Response> _executeWithRetry(Future<http.Response> Function() request) async {
    int attempts = 0;

    while (attempts < AppConfig.maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;

        if (AppConfig.enableApiLogging) {
          debugPrint('请求失败 (第 $attempts 次): $e');
        }

        if (attempts >= AppConfig.maxRetries) {
          rethrow;
        }

        // 等待后重试
        await Future.delayed(AppConfig.retryDelay * attempts);
      }
    }

    throw Exception('请求失败，已达到最大重试次数');
  }

  // 处理响应
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return {'success': true, 'data': response.body};
      }
    } else {
      String errorMessage;
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = errorData['message'] ?? errorData['error'] ?? '请求失败';
      } catch (e) {
        errorMessage = '请求失败: HTTP ${response.statusCode}';
      }

      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode,
        response: response.body,
      );
    }
  }

  // ===== 健康检查 =====

  // 检查API健康状态
  Future<bool> checkHealth() async {
    try {
      final response = await get('/health');
      return response.statusCode == 200;
    } catch (e) {
      if (AppConfig.enableApiLogging) {
        debugPrint('健康检查失败: $e');
      }
      return false;
    }
  }

  // 测试所有备用地址
  Future<String?> findWorkingBackend() async {
    for (final url in AppConfig.fallbackUrls) {
      try {
        final response = await http
            .get(Uri.parse('$url/health'), headers: AppConfig.defaultHeaders)
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          if (AppConfig.enableApiLogging) {
            debugPrint('找到可用的后端: $url');
          }
          return url;
        }
      } catch (e) {
        if (AppConfig.enableApiLogging) {
          debugPrint('后端不可用: $url - $e');
        }
        continue;
      }
    }

    return null;
  }
}

// API异常类
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String response;

  ApiException({required this.message, required this.statusCode, required this.response});

  @override
  String toString() {
    return 'ApiException: $message (HTTP $statusCode)';
  }
}
