import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'mock_auth_service.dart';
import 'app_settings.dart';
import 'api_client.dart';
import 'worker_config.dart';

class AuthService {
  // 模拟服务实例
  final MockAuthService _mockService = MockAuthService();
  
  // API 客户端实例
  late final ApiClient _apiClient;
  
  AuthService() {
    _apiClient = ApiClient();
  }
  
  // 获取后端URL
  Future<String> get baseUrl async {
    return await AppSettings.getBackendUrl();
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.login(username, password);
    }
    
    try {
      final response = await _apiClient.post('/api/auth/login', body: {
        'username': username,
        'password': password,
      });
      
      if (response['success'] == true) {
        // 安全地访问响应数据
        final data = response['data'] ?? response;
        return {
          'success': true,
          'token': data['token'],
          'user': {
            'username': data['username'] ?? username,
            'email': data['email'] ?? '',
            'membershipType': data['membershipType'],
            'membershipExpiry': data['membershipExpiry'],
            'isAdmin': data['isAdmin'] ?? false,
          }
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? response['error'] ?? '登录失败',
        };
      }
    } catch (e) {
      debugPrint('登录请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败，请检查网络设置',
      };
    }
  }

  Future<Map<String, dynamic>> register(String username, String email, String password, String verificationCode) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.register(username, email, password, verificationCode);
    }
    
    try {
      final response = await _apiClient.post('/api/auth/register', body: {
        'username': username,
        'email': email,
        'password': password,
        'verificationCode': verificationCode,
      });
      
      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? (response['success'] ? '注册成功' : '注册失败'),
      };
    } catch (e) {
      debugPrint('注册请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败，请检查网络设置',
      };
    }
  }

  Future<Map<String, dynamic>> sendVerificationCode(String email, {String type = 'register'}) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.sendVerificationCode(email, type: type);
    }
    
    try {
      final response = await _apiClient.post('/api/auth/send-verification-code', body: {
        'email': email,
        'type': type,
      });
      
      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? (response['success'] ? '验证码已发送' : '发送验证码失败'),
      };
    } catch (e) {
      debugPrint('发送验证码请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败，请检查网络设置',
      };
    }
  }

  Future<bool> verifyToken(String token) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.verifyToken(token);
    }
    
    try {
      final response = await _apiClient.get('/api/auth/verify', token: token);
      return response['success'] == true;
    } catch (e) {
      debugPrint('验证token失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String token) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.getUserInfo(token);
    }
    
    try {
      final response = await _apiClient.get('/api/auth/verify', token: token);
      
      if (response['success'] == true) {
        return {
          'success': true,
          'user': {
            'username': response['data']['username'] ?? '',
            'email': response['data']['email'] ?? '',
            'membershipType': response['data']['membershipType'],
            'membershipExpiry': response['data']['membershipExpiry'],
            'isAdmin': response['data']['isAdmin'] ?? false,
          }
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? '获取用户信息失败',
        };
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }

  Future<Map<String, dynamic>> logout(String token) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.logout(token);
    }
    
    try {
      final response = await _apiClient.post('/api/auth/logout', body: {}, token: token);
      
      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? (response['success'] ? '登出成功' : '登出失败'),
      };
    } catch (e) {
      debugPrint('登出请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.forgotPassword(email);
    }
    
    try {
      final response = await _apiClient.post('/api/auth/forgot-password', body: {
        'email': email,
      });
      
      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? (response['success'] ? '重置邮件已发送' : '发送重置邮件失败'),
      };
    } catch (e) {
      debugPrint('忘记密码请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败，请检查网络设置',
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String token, String newPassword) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.resetPassword(email, token, newPassword);
    }
    
    try {
      final response = await _apiClient.post('/api/auth/reset-password', body: {
        'email': email,
        'token': token,
        'newPassword': newPassword,
      });
      
      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? (response['success'] ? '密码重置成功' : '密码重置失败'),
      };
    } catch (e) {
      debugPrint('重置密码请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败，请检查网络设置',
      };
    }
  }

  // 会员相关API
  Future<Map<String, dynamic>> getMembershipStatus(String token) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.getMembershipStatus(token);
    }
    
    try {
      final response = await _apiClient.get('/api/stripe/membership-status', token: token);
      
      if (response['success'] == true) {
        return {
          'success': true,
          'membership': response['data'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? '获取会员状态失败',
        };
      }
    } catch (e) {
      debugPrint('获取会员状态失败: $e');
      return {
        'success': false,
        'message': '网络连接失败',
      };
    }
  }

  Future<Map<String, dynamic>> redeemCode(String token, String code) async {
    // 检查是否使用测试模式
    final useTestMode = await AppSettings.getTestMode();
    if (useTestMode) {
      return await _mockService.redeemCode(token, code);
    }
    
    try {
      final response = await _apiClient.post('/api/admin/use-redeem-code', body: {
        'code': code,
      }, token: token);
      
      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? (response['success'] ? '兑换成功' : '兑换失败'),
      };
    } catch (e) {
      debugPrint('兑换码请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败，请检查网络设置',
      };
    }
  }
}