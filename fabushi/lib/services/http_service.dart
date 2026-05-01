// HTTP服务
// 统一处理HTTP请求，包括认证、错误处理、重试等

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

class HttpService {
  // 单例模式
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  // HTTP客户端
  static final http.Client _client = http.Client();

  // 获取认证头
  static Future<Map<String, String>> _getHeaders({bool useAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (useAuth) {
      final token = await _getStoredToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        print(
          '🔐 HttpService: 添加认证头 Authorization: Bearer ${token.substring(0, 20)}...',
        );
      } else {
        print('⚠️ HttpService: useAuth=true 但没有token');
      }
    }

    return headers;
  }

  // 获取存储的token
  static Future<String?> _getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConfig.tokenStorageKey);
      if (token != null) {
        print('🔑 HttpService: 成功获取token: ${token.substring(0, 20)}...');
      } else {
        print('⚠️ HttpService: SharedPreferences中没有token');
      }
      return token;
    } catch (e) {
      print('❌ HttpService: 获取存储的token失败: $e');
      return null;
    }
  }

  // 处理HTTP响应
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (AppConfig.enableApiLogging) {
      print('HTTP ${response.request?.method} ${response.request?.url}');
      print('Status: ${response.statusCode}');
      print(
        'Response: ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}',
      );
    }

    return {
      'statusCode': response.statusCode,
      'body': response.body,
      'headers': response.headers,
    };
  }

  // 处理HTTP错误
  static Exception _handleError(dynamic error, String method, String url) {
    String errorMessage;

    if (error is SocketException) {
      errorMessage = AppConfig.errorMessages['network_error'] ?? '网络连接失败';
    } else if (error is HttpException) {
      errorMessage = AppConfig.errorMessages['server_error'] ?? '服务器错误';
    } else if (error.toString().contains('TimeoutException')) {
      errorMessage = AppConfig.errorMessages['timeout_error'] ?? '请求超时';
    } else {
      errorMessage = '请求失败: ${error.toString()}';
    }

    if (AppConfig.enableApiLogging) {
      print('HTTP $method $url 失败: $errorMessage');
      print('错误详情: $error');
    }

    return Exception(errorMessage);
  }

  // 重试逻辑
  static Future<http.Response> _retryRequest(
    Future<http.Response> Function() request,
    String method,
    String url,
  ) async {
    int attempts = 0;

    while (attempts < AppConfig.maxRetries) {
      try {
        final response = await request();
        return response;
      } catch (e) {
        attempts++;

        if (attempts >= AppConfig.maxRetries) {
          throw _handleError(e, method, url);
        }

        // 等待后重试
        await Future.delayed(AppConfig.retryDelay * attempts);

        if (AppConfig.enableApiLogging) {
          print('重试 $method $url (第 $attempts 次)');
        }
      }
    }

    throw Exception('重试次数已达上限');
  }

  // GET请求
  static Future<http.Response> get(
    String url, {
    Map<String, String>? queryParams,
    bool useAuth = false,
  }) async {
    try {
      final uri = Uri.parse(url);
      final finalUri = queryParams != null
          ? uri.replace(
              queryParameters: {...uri.queryParameters, ...queryParams},
            )
          : uri;

      final headers = await _getHeaders(useAuth: useAuth);

      return await _retryRequest(
        () => _client
            .get(finalUri, headers: headers)
            .timeout(AppConfig.requestTimeout),
        'GET',
        url,
      );
    } catch (e) {
      throw _handleError(e, 'GET', url);
    }
  }

  // POST请求
  static Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(useAuth: useAuth);
      final jsonBody = body != null ? jsonEncode(body) : null;

      return await _retryRequest(
        () => _client
            .post(Uri.parse(url), headers: headers, body: jsonBody)
            .timeout(AppConfig.requestTimeout),
        'POST',
        url,
      );
    } catch (e) {
      throw _handleError(e, 'POST', url);
    }
  }

  // PUT请求
  static Future<http.Response> put(
    String url, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(useAuth: useAuth);
      final jsonBody = body != null ? jsonEncode(body) : null;

      return await _retryRequest(
        () => _client
            .put(Uri.parse(url), headers: headers, body: jsonBody)
            .timeout(AppConfig.requestTimeout),
        'PUT',
        url,
      );
    } catch (e) {
      throw _handleError(e, 'PUT', url);
    }
  }

  // DELETE请求
  static Future<http.Response> delete(
    String url, {
    bool useAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(useAuth: useAuth);

      return await _retryRequest(
        () => _client
            .delete(Uri.parse(url), headers: headers)
            .timeout(AppConfig.requestTimeout),
        'DELETE',
        url,
      );
    } catch (e) {
      throw _handleError(e, 'DELETE', url);
    }
  }

  // PATCH请求
  static Future<http.Response> patch(
    String url, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(useAuth: useAuth);
      final jsonBody = body != null ? jsonEncode(body) : null;

      return await _retryRequest(
        () => _client
            .patch(Uri.parse(url), headers: headers, body: jsonBody)
            .timeout(AppConfig.requestTimeout),
        'PATCH',
        url,
      );
    } catch (e) {
      throw _handleError(e, 'PATCH', url);
    }
  }

  // 文件上传
  static Future<http.StreamedResponse> uploadFile(
    String url,
    String filePath,
    String fieldName, {
    Map<String, String>? fields,
    bool useAuth = false,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));

      // 添加认证头
      if (useAuth) {
        final token = await _getStoredToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      // 添加文件
      final file = await http.MultipartFile.fromPath(fieldName, filePath);
      request.files.add(file);

      // 添加其他字段
      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (AppConfig.enableApiLogging) {
        print('上传文件: $filePath 到 $url');
      }

      return await request.send().timeout(AppConfig.requestTimeout);
    } catch (e) {
      throw _handleError(e, 'UPLOAD', url);
    }
  }

  // 下载文件
  static Future<List<int>> downloadFile(
    String url, {
    bool useAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(useAuth: useAuth);

      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw _handleError(e, 'DOWNLOAD', url);
    }
  }

  // 检查网络连接
  static Future<bool> checkConnectivity() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.currentBackendUrl}/api/auth/verify'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  // 解析JSON响应
  static Map<String, dynamic> parseJsonResponse(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('响应格式错误: 无法解析JSON');
    }
  }

  // 检查响应是否成功
  static bool isSuccessResponse(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  // 获取错误消息
  static String getErrorMessage(http.Response response) {
    try {
      final data = parseJsonResponse(response);
      return data['error'] ?? data['message'] ?? '未知错误';
    } catch (e) {
      return '服务器响应格式错误';
    }
  }

  // 处理API响应的通用方法
  static Map<String, dynamic> handleApiResponse(http.Response response) {
    if (isSuccessResponse(response)) {
      return {
        'success': true,
        'data': parseJsonResponse(response),
        'statusCode': response.statusCode,
      };
    } else {
      return {
        'success': false,
        'error': getErrorMessage(response),
        'statusCode': response.statusCode,
      };
    }
  }

  // 关闭HTTP客户端
  static void dispose() {
    _client.close();
  }
}
