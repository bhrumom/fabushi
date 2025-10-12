import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'app_settings.dart';

/// 支付宝认证服务
/// 处理支付宝登录授权相关功能
class AlipayAuthService {
  
  // 获取后端URL
  Future<String> get baseUrl async {
    return await AppSettings.getBackendUrl();
  }

  /// 获取支付宝登录授权URL
  Future<Map<String, dynamic>> getAlipayLoginUrl({String? platform}) async {
    try {
      final url = await baseUrl;
      
      // 构建请求URL，添加平台参数
      String requestUrl = '$url/api/auth/alipay/login-url';
      if (platform != null) {
        requestUrl += '?platform=$platform';
      }
      
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'loginUrl': data['authUrl'], // 注意：前端期望的是loginUrl而不是authUrl
          'state': data['state'],
          'appId': data['appId'],
          'platform': data['platform'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? '获取支付宝登录URL失败',
        };
      }
    } catch (e) {
      debugPrint('获取支付宝登录URL失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }

  /// 支付宝登录回调处理
  Future<Map<String, dynamic>> alipayLogin(String authCode, String? state) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/alipay/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'authCode': authCode,
          'state': state,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'username': data['username'],
          'email': data['email'],
          'isNewUser': data['isNewUser'] ?? false,
          'needsBinding': data['needsBinding'] ?? false,
          'alipayUser': data['alipayUser'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? '支付宝登录失败',
        };
      }
    } catch (e) {
      debugPrint('支付宝登录失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }

  /// 绑定支付宝账号到现有邮箱账户
  Future<Map<String, dynamic>> bindAlipay(String alipayUserId, [String? email, String? password]) async {
    try {
      final url = await baseUrl;
      
      // 构建请求体，只包含必要的alipayUserId参数
      final Map<String, String> requestBody = {'alipayUserId': alipayUserId};
      
      // 如果提供了邮箱和密码，则添加到请求体中
      if (email != null && email.isNotEmpty) {
        requestBody['email'] = email;
      }
      if (password != null && password.isNotEmpty) {
        requestBody['password'] = password;
      }
      
      final response = await http.post(
        Uri.parse('$url/api/auth/alipay/bind'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'username': data['username'],
          'message': data['message'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? '支付宝绑定失败',
        };
      }
    } catch (e) {
      debugPrint('支付宝绑定失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }

  /// 支付宝账号注册（新用户）
  Future<Map<String, dynamic>> alipayRegister({
    required String alipayUserId,
    required String username,
    required String password,
    String? nickname,
    String? avatar,
    String? email,
  }) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/alipay/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'alipayUserId': alipayUserId,
          'username': username,
          'password': password,
          'nickname': nickname,
          'avatar': avatar,
          'email': email,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'username': data['username'],
          'message': data['message'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? '支付宝注册失败',
        };
      }
    } catch (e) {
      debugPrint('支付宝注册失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }

  /// 解绑支付宝账号
  Future<Map<String, dynamic>> unbindAlipay(String token) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/alipay/unbind'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? '支付宝解绑失败',
        };
      }
    } catch (e) {
      debugPrint('支付宝解绑失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }
}