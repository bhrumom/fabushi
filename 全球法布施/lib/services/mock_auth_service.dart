import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 模拟认证服务，用于离线测试
class MockAuthService {
  // 模拟延迟
  static const Duration _mockDelay = Duration(milliseconds: 1500);
  
  // 模拟用户数据
  static const Map<String, String> _mockUsers = {
    'test@example.com': 'password123',
    'admin@fabushi.com': 'admin123',
    'user@test.com': 'test123',
  };

  Future<Map<String, dynamic>> login(String username, String password) async {
    debugPrint('🔄 模拟登录请求: $username');
    
    // 模拟网络延迟
    await Future.delayed(_mockDelay);
    
    // 检查用户名和密码
    if (_mockUsers.containsKey(username) && _mockUsers[username] == password) {
      final isAdmin = username.contains('admin');
      final isPremium = username.contains('test@example.com');
      
      return {
        'success': true,
        'token': 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
        'user': {
          'username': username.split('@')[0],
          'email': username,
          'membershipType': isPremium ? 'premium' : (isAdmin ? 'admin' : null),
          'membershipExpiry': isPremium 
              ? DateTime.now().add(const Duration(days: 30)).toIso8601String()
              : null,
          'isAdmin': isAdmin,
        },
      };
    } else {
      return {
        'success': false,
        'message': '用户名或密码错误',
      };
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String verificationCode,
  ) async {
    debugPrint('🔄 模拟注册请求: $username, $email');
    
    // 模拟网络延迟
    await Future.delayed(_mockDelay);
    
    // 简单验证
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      return {
        'success': false,
        'message': '请填写完整信息',
      };
    }
    
    if (verificationCode != '123456') {
      return {
        'success': false,
        'message': '验证码错误（测试验证码：123456）',
      };
    }
    
    if (_mockUsers.containsKey(email)) {
      return {
        'success': false,
        'message': '该邮箱已被注册',
      };
    }
    
    return {
      'success': true,
      'message': '注册成功',
    };
  }

  Future<Map<String, dynamic>> sendVerificationCode(
    String email, {
    String type = 'register',
  }) async {
    debugPrint('🔄 模拟发送验证码: $email, type: $type');
    
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (email.isEmpty || !email.contains('@')) {
      return {
        'success': false,
        'message': '请输入有效的邮箱地址',
      };
    }
    
    return {
      'success': true,
      'message': '验证码已发送（测试验证码：123456）',
    };
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    debugPrint('🔄 模拟忘记密码请求: $email');
    
    // 模拟网络延迟
    await Future.delayed(_mockDelay);
    
    if (email.isEmpty || !email.contains('@')) {
      return {
        'success': false,
        'message': '请输入有效的邮箱地址',
      };
    }
    
    return {
      'success': true,
      'message': '重置密码邮件已发送',
    };
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    debugPrint('🔄 模拟重置密码请求: $email');
    
    // 模拟网络延迟
    await Future.delayed(_mockDelay);
    
    if (newPassword.length < 6) {
      return {
        'success': false,
        'message': '密码长度至少6位',
      };
    }
    
    return {
      'success': true,
      'message': '密码重置成功',
    };
  }

  Future<bool> verifyToken(String token) async {
    debugPrint('🔄 模拟验证Token: ${token.substring(0, 20)}...');
    
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 简单检查token格式
    return token.startsWith('mock_jwt_token_');
  }

  Future<Map<String, dynamic>> getUserInfo(String token) async {
    debugPrint('🔄 模拟获取用户信息');
    
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!token.startsWith('mock_jwt_token_')) {
      return {
        'success': false,
        'message': 'Token无效',
      };
    }
    
    return {
      'success': true,
      'user': {
        'username': 'testuser',
        'email': 'test@example.com',
        'membershipType': 'premium',
        'membershipExpiry': DateTime.now().add(const Duration(days: 25)).toIso8601String(),
        'isAdmin': false,
      },
    };
  }

  Future<Map<String, dynamic>> logout(String token) async {
    debugPrint('🔄 模拟登出请求');
    
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'success': true,
      'message': '登出成功',
    };
  }

  // 会员状态相关
  Future<Map<String, dynamic>> getMembershipStatus(String token) async {
    debugPrint('🔄 模拟获取会员状态');
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!token.startsWith('mock_jwt_token_')) {
      return {
        'success': false,
        'message': 'Token无效',
      };
    }
    
    return {
      'success': true,
      'membership': {
        'username': 'testuser',
        'email': 'test@example.com',
        'membership': {
          'type': 'trial',
          'isActive': true,
          'expiresAt': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'daysRemaining': 5,
        },
        'hasStripeCustomer': false,
      },
    };
  }

  // 兑换码相关
  Future<Map<String, dynamic>> redeemCode(String token, String code) async {
    debugPrint('🔄 模拟兑换码: $code');
    
    await Future.delayed(_mockDelay);
    
    if (!token.startsWith('mock_jwt_token_')) {
      return {
        'success': false,
        'message': 'Token无效',
      };
    }
    
    // 模拟兑换码验证
    if (code == 'TEST123456') {
      return {
        'success': true,
        'message': '兑换成功！获得月度会员',
        'membershipType': 'premium',
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'daysAdded': 30,
      };
    } else if (code == 'TRIAL7DAYS') {
      return {
        'success': true,
        'message': '兑换成功！获得7天试用',
        'membershipType': 'trial',
        'expiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'daysAdded': 7,
      };
    } else {
      return {
        'success': false,
        'message': '兑换码无效或已过期（测试兑换码：TEST123456, TRIAL7DAYS）',
      };
    }
  }

  // 获取测试账户信息
  static List<Map<String, String>> getTestAccounts() {
    return [
      {
        'email': 'test@example.com',
        'password': 'password123',
        'type': '高级会员账户',
      },
      {
        'email': 'admin@fabushi.com',
        'password': 'admin123',
        'type': '管理员账户',
      },
      {
        'email': 'user@test.com',
        'password': 'test123',
        'type': '普通用户账户',
      },
    ];
  }

  // 获取测试兑换码
  static List<String> getTestRedeemCodes() {
    return [
      'TEST123456', // 月度会员
      'TRIAL7DAYS', // 7天试用
    ];
  }
}