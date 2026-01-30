// Firebase removed for Windows compatibility
// This is a stub implementation that returns error messages

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Stub implementation of FirebaseAuthService for platforms without Firebase support
class FirebaseAuthService {
  // 手机验证相关状态
  String? _verificationId;

  dynamic get currentUser => null;
  Stream<dynamic> get authStateChanges => Stream.value(null);
  String? get verificationId => _verificationId;

  // ==================== 手机号登录相关 ====================

  /// 发送手机验证码 - STUB: Firebase not available on Windows
  Future<Map<String, dynamic>> verifyPhoneNumber(String phoneNumber) async {
    debugPrint('⚠️ Firebase not available on this platform');
    return {'success': false, 'error': 'Firebase手机验证在Windows平台不可用，请使用抖音登录'};
  }

  /// 使用验证码登录 - STUB
  Future<Map<String, dynamic>> signInWithPhoneCredential(String smsCode) async {
    debugPrint('⚠️ Firebase not available on this platform');
    return {'success': false, 'error': 'Firebase登录在Windows平台不可用'};
  }

  /// 将手机号绑定到当前用户 - STUB
  Future<Map<String, dynamic>> linkPhoneToCurrentUser(String smsCode) async {
    return {'success': false, 'error': 'Firebase在Windows平台不可用'};
  }

  /// 获取Firebase ID Token - STUB
  Future<String?> getIdToken() async {
    return null;
  }

  // ==================== 邮箱密码登录相关 ====================

  // 邮箱密码注册 - STUB
  Future<Map<String, dynamic>> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    return {'success': false, 'error': 'Firebase在Windows平台不可用'};
  }

  // 邮箱密码登录 - STUB
  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
    return {'success': false, 'error': 'Firebase在Windows平台不可用'};
  }

  // Google登录 - STUB
  Future<Map<String, dynamic>> signInWithGoogle() async {
    return {'success': false, 'error': 'Google登录暂不可用'};
  }

  // 发送邮箱验证 - STUB
  Future<void> sendEmailVerification() async {
    debugPrint('⚠️ Firebase not available on this platform');
  }

  // 重置密码 - STUB
  Future<Map<String, dynamic>> resetPassword(String email) async {
    return {'success': false, 'error': 'Firebase在Windows平台不可用'};
  }

  // 登出
  Future<void> signOut() async {
    _verificationId = null;
    await _clearUserLocally();
  }

  // ==================== 辅助方法 ====================

  // 清除本地用户信息
  Future<void> _clearUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_user');
  }
}
