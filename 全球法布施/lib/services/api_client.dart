import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'app_settings.dart';
import 'worker_config.dart';

/// 统一的 API 客户端
/// 处理所有与 Cloudflare Worker 的 HTTP 通信
class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  ApiClient._();

  // 公共构造函数，用于直接实例化
  factory ApiClient() => instance;

  // 获取后端URL
  Future<String> get baseUrl async {
    // 优先使用统一配置，如果用户有自定义设置则使用自定义设置
    return await AppSettings.getBackendUrl();
  }

  // 通用 GET 请求
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    String? token,
  }) async {
    try {
      final url = await baseUrl;
      var uri = Uri.parse('$url$endpoint');

      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      debugPrint('🌐 GET: $uri');

      final response = await http.get(uri, headers: requestHeaders);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ GET 请求失败: $e');
      return {
        'success': false,
        'error': WorkerConfig.getErrorMessage('NETWORK_ERROR'),
        'details': e.toString(),
      };
    }
  }

  // 通用 POST 请求
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final url = await baseUrl;
      final uri = Uri.parse('$url$endpoint');

      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      debugPrint('🌐 POST: $uri');
      if (body != null) {
        debugPrint('📤 Body: ${jsonEncode(body)}');
      }

      final response = await http.post(
        uri,
        headers: requestHeaders,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ POST 请求失败: $e');
      return {
        'success': false,
        'error': WorkerConfig.getErrorMessage('NETWORK_ERROR'),
        'details': e.toString(),
      };
    }
  }

  // 通用 PUT 请求
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final url = await baseUrl;
      final uri = Uri.parse('$url$endpoint');

      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      debugPrint('🌐 PUT: $uri');

      final response = await http.put(
        uri,
        headers: requestHeaders,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ PUT 请求失败: $e');
      return {
        'success': false,
        'error': WorkerConfig.getErrorMessage('NETWORK_ERROR'),
        'details': e.toString(),
      };
    }
  }

  // 通用 DELETE 请求
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final url = await baseUrl;
      final uri = Uri.parse('$url$endpoint');

      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      debugPrint('🌐 DELETE: $uri');

      final response = await http.delete(
        uri,
        headers: requestHeaders,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ DELETE 请求失败: $e');
      return {
        'success': false,
        'error': WorkerConfig.getErrorMessage('NETWORK_ERROR'),
        'details': e.toString(),
      };
    }
  }

  // 处理响应
  Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('📥 Response: ${response.statusCode} ${response.reasonPhrase}');
    debugPrint('📄 原始响应体: ${response.body}');

    try {
      final data = jsonDecode(response.body);
      debugPrint('📊 解析后数据: $data');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 确保数据不为空
        if (data == null) {
          return {
            'success': false,
            'statusCode': response.statusCode,
            'error': '服务器返回空数据',
            'details': response.body,
          };
        }

        // 如果数据是 Map，直接合并；否则包装在 data 字段中
        if (data is Map<String, dynamic>) {
          return {'success': true, 'statusCode': response.statusCode, ...data};
        } else {
          return {
            'success': true,
            'statusCode': response.statusCode,
            'data': data,
          };
        }
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data is Map
              ? (data['error'] ?? data['message'] ?? '请求失败')
              : '请求失败',
          'details': data,
        };
      }
    } catch (e) {
      debugPrint('❌ 解析响应失败: $e');
      debugPrint('📄 原始响应: ${response.body}');

      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': response.statusCode >= 500
            ? WorkerConfig.getErrorMessage('SERVER_ERROR')
            : '响应格式错误',
        'details': response.body,
      };
    }
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
