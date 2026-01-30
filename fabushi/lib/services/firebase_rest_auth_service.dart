// Firebase removed for Windows compatibility
// This is a stub implementation

import 'package:flutter/foundation.dart';

/// Stub implementation of Firebase REST API service
/// Firebase is not available on Windows platform
class FirebaseRestAuthService {
  String? _sessionInfo;

  /// 发送验证码到手机号 - STUB
  Future<Map<String, dynamic>> sendVerificationCode({
    required String phoneNumber,
    required String recaptchaToken,
  }) async {
    debugPrint('⚠️ Firebase REST API not available on Windows');
    return {
      'success': false,
      'error': 'Firebase手机验证在Windows平台不可用，请使用抖音登录',
    };
  }

  /// 使用验证码登录 - STUB
  Future<Map<String, dynamic>> signInWithPhoneNumber({
    required String code,
    String? sessionInfo,
  }) async {
    debugPrint('⚠️ Firebase REST API not available on Windows');
    return {
      'success': false,
      'error': 'Firebase登录在Windows平台不可用',
    };
  }

  /// 检查是否需要使用REST API (桌面平台)
  static bool get shouldUseRestApi {
    return !kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.linux);
  }
}
