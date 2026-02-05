import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// Firebase Identity Toolkit REST API 服务
/// 用于在不支持SDK的平台（如macOS桌面）使用Firebase手机验证码登录
class FirebaseRestAuthService {
  static const String _baseUrl = 'https://identitytoolkit.googleapis.com/v1';
  
  // 获取当前平台的Firebase API Key
  static String get _apiKey {
    return DefaultFirebaseOptions.currentPlatform.apiKey;
  }

  // 存储当前验证会话ID
  String? _sessionInfo;

  /// 发送验证码到手机号
  /// 需要reCAPTCHA token来验证请求合法性
  /// 返回: {success: bool, error?: String, sessionInfo?: String}
  Future<Map<String, dynamic>> sendVerificationCode({
    required String phoneNumber,
    required String recaptchaToken,
  }) async {
    try {
      final url = '$_baseUrl/accounts:sendVerificationCode?key=$_apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'recaptchaToken': recaptchaToken,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['sessionInfo'] != null) {
        _sessionInfo = data['sessionInfo'];
        return {
          'success': true,
          'sessionInfo': _sessionInfo,
        };
      } else {
        return {
          'success': false,
          'error': _parseError(data),
        };
      }
    } catch (e) {
      debugPrint('Firebase REST API error: $e');
      return {
        'success': false,
        'error': '网络错误: $e',
      };
    }
  }

  /// 使用验证码登录
  /// 返回: {success: bool, idToken?: String, refreshToken?: String, localId?: String, phoneNumber?: String, isNewUser?: bool, error?: String}
  Future<Map<String, dynamic>> signInWithPhoneNumber({
    required String code,
    String? sessionInfo,
  }) async {
    try {
      final session = sessionInfo ?? _sessionInfo;
      if (session == null) {
        return {
          'success': false,
          'error': '请先发送验证码',
        };
      }

      final url = '$_baseUrl/accounts:signInWithPhoneNumber?key=$_apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionInfo': session,
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['idToken'] != null) {
        _sessionInfo = null; // 清除已使用的session
        return {
          'success': true,
          'idToken': data['idToken'],
          'refreshToken': data['refreshToken'],
          'localId': data['localId'],
          'phoneNumber': data['phoneNumber'],
          'isNewUser': data['isNewUser'] ?? false,
        };
      } else {
        return {
          'success': false,
          'error': _parseError(data),
        };
      }
    } catch (e) {
      debugPrint('Firebase REST API signIn error: $e');
      return {
        'success': false,
        'error': '登录失败: $e',
      };
    }
  }

  /// 解析Firebase错误信息
  String _parseError(Map<String, dynamic> data) {
    final error = data['error'];
    if (error == null) return '未知错误';
    
    final message = error['message'] as String?;
    if (message == null) return '未知错误';

    // 转换常见错误为中文
    switch (message) {
      case 'INVALID_PHONE_NUMBER':
        return '无效的手机号';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return '请求过于频繁，请稍后再试';
      case 'INVALID_CODE':
        return '验证码错误';
      case 'SESSION_EXPIRED':
        return '验证码已过期，请重新获取';
      case 'INVALID_SESSION_INFO':
        return '验证会话无效，请重新获取验证码';
      case 'QUOTA_EXCEEDED':
        return '短信配额已用完';
      case 'CAPTCHA_CHECK_FAILED':
        return 'reCAPTCHA验证失败';
      default:
        if (message.startsWith('INVALID_')) {
          return '验证失败: ${message.replaceAll('_', ' ')}';
        }
        return message;
    }
  }

  /// 检查是否需要使用REST API (桌面平台)
  static bool get shouldUseRestApi {
    return !kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.linux);
  }
}
