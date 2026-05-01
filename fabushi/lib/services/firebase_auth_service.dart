import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 手机验证相关状态
  String? _verificationId;
  int? _resendToken;
  Completer<Map<String, dynamic>>? _phoneVerificationCompleter;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String? get verificationId => _verificationId;

  // ==================== 手机号登录相关 ====================

  /// 发送手机验证码
  /// 返回 {success: bool, error?: String, verificationId?: String}
  Future<Map<String, dynamic>> verifyPhoneNumber(String phoneNumber) async {
    try {
      _phoneVerificationCompleter = Completer<Map<String, dynamic>>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android自动验证完成
          debugPrint('📱 手机验证自动完成');
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            await _saveUserLocally(userCredential.user);
            if (!_phoneVerificationCompleter!.isCompleted) {
              _phoneVerificationCompleter!.complete({
                'success': true,
                'autoVerified': true,
                'user': userCredential.user,
              });
            }
          } catch (e) {
            if (!_phoneVerificationCompleter!.isCompleted) {
              _phoneVerificationCompleter!.complete({
                'success': false,
                'error': '自动验证失败: $e',
              });
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('📱 手机验证失败: ${e.code} - ${e.message}');
          if (!_phoneVerificationCompleter!.isCompleted) {
            _phoneVerificationCompleter!.complete({
              'success': false,
              'error': _getPhoneErrorMessage(e.code),
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('📱 验证码已发送, verificationId: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!_phoneVerificationCompleter!.isCompleted) {
            _phoneVerificationCompleter!.complete({
              'success': true,
              'verificationId': verificationId,
              'codeSent': true,
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('📱 验证码自动获取超时');
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );

      return await _phoneVerificationCompleter!.future;
    } catch (e) {
      debugPrint('📱 发送验证码异常: $e');
      return {'success': false, 'error': '发送验证码失败: $e'};
    }
  }

  /// 使用验证码登录
  /// 返回 {success: bool, error?: String, user?: User, isNewUser?: bool}
  Future<Map<String, dynamic>> signInWithPhoneCredential(String smsCode) async {
    try {
      if (_verificationId == null) {
        return {'success': false, 'error': '请先获取验证码'};
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _saveUserLocally(userCredential.user);

      // 判断是否是新用户
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      debugPrint('📱 手机登录成功, isNewUser: $isNewUser');

      return {
        'success': true,
        'user': userCredential.user,
        'isNewUser': isNewUser,
        'firebaseUid': userCredential.user?.uid,
        'phoneNumber': userCredential.user?.phoneNumber,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('📱 验证码登录失败: ${e.code}');
      return {'success': false, 'error': _getPhoneErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'error': '登录失败: $e'};
    }
  }

  /// 将手机号绑定到当前用户
  Future<Map<String, dynamic>> linkPhoneToCurrentUser(String smsCode) async {
    try {
      if (_verificationId == null) {
        return {'success': false, 'error': '请先获取验证码'};
      }

      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': '请先登录'};
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await user.linkWithCredential(credential);
      await _saveUserLocally(user);

      return {'success': true, 'phoneNumber': user.phoneNumber};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getPhoneErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'error': '绑定失败: $e'};
    }
  }

  /// 获取Firebase ID Token (用于后端验证)
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('获取ID Token失败: $e');
      return null;
    }
  }

  // ==================== 邮箱密码登录相关 ====================

  // 邮箱密码注册
  Future<Map<String, dynamic>> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(username);
      await credential.user?.sendEmailVerification();
      await _saveUserLocally(credential.user);

      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getErrorMessage(e.code)};
    }
  }

  // 邮箱密码登录
  Future<Map<String, dynamic>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveUserLocally(credential.user);
      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getErrorMessage(e.code)};
    }
  }

  // Google登录 (暂时禁用)
  Future<Map<String, dynamic>> signInWithGoogle() async {
    return {'success': false, 'error': 'Google登录暂不可用'};
  }

  // 发送邮箱验证
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // 重置密码
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getErrorMessage(e.code)};
    }
  }

  // 登出
  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    await _auth.signOut();
    await _clearUserLocally();
  }

  // ==================== 辅助方法 ====================

  // 本地保存用户信息
  Future<void> _saveUserLocally(User? user) async {
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'displayName': user.displayName,
      'emailVerified': user.emailVerified,
    };
    await prefs.setString('firebase_user', jsonEncode(userData));
  }

  // 清除本地用户信息
  Future<void> _clearUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_user');
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '邮箱已被使用';
      case 'invalid-email':
        return '邮箱格式无效';
      case 'weak-password':
        return '密码强度不足';
      case 'user-not-found':
        return '用户不存在';
      case 'wrong-password':
        return '密码错误';
      default:
        return '操作失败';
    }
  }

  String _getPhoneErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return '手机号格式无效';
      case 'too-many-requests':
        return '请求过于频繁，请稍后再试';
      case 'invalid-verification-code':
        return '验证码错误';
      case 'session-expired':
        return '验证码已过期，请重新获取';
      case 'credential-already-in-use':
        return '该手机号已被其他账户使用';
      case 'quota-exceeded':
        return '今日验证次数已达上限';
      default:
        return '验证失败: $code';
    }
  }
}
