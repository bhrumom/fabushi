import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 邮箱密码注册
  Future<Map<String, dynamic>> registerWithEmail(String email, String password, String username) async {
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
  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
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

  // Google登录
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return {'success': false, 'error': '登录已取消'};

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _saveUserLocally(userCredential.user);
      return {'success': true, 'user': userCredential.user};
    } catch (e) {
      return {'success': false, 'error': '登录失败: $e'};
    }
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
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _clearUserLocally();
  }

  // 本地保存用户信息
  Future<void> _saveUserLocally(User? user) async {
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userData = {
      'uid': user.uid,
      'email': user.email,
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
      case 'email-already-in-use': return '邮箱已被使用';
      case 'invalid-email': return '邮箱格式无效';
      case 'weak-password': return '密码强度不足';
      case 'user-not-found': return '用户不存在';
      case 'wrong-password': return '密码错误';
      default: return '操作失败';
    }
  }
}
