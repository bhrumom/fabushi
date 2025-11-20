// 用户认证服务
// 处理用户登录、注册、验证等功能

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../models/user_model.dart';
import 'http_service.dart';

class AuthService {
  static const String _tokenKey = AppConfig.tokenStorageKey;
  static const String _userInfoKey = AppConfig.userInfoStorageKey;

  // 单例模式
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 当前用户信息
  UserModel? _currentUser;
  String? _currentToken;

  // 获取当前用户
  UserModel? get currentUser => _currentUser;
  String? get currentToken => _currentToken;
  bool get isLoggedIn => _currentToken != null && _currentUser != null;

  // 初始化服务（应用启动时调用）
  Future<void> initialize() async {
    await _loadStoredAuth();
  }

  // 从本地存储加载认证信息
  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString(_tokenKey);

      final userInfoJson = prefs.getString(_userInfoKey);
      if (userInfoJson != null) {
        final userInfo = jsonDecode(userInfoJson);
        _currentUser = UserModel.fromJson(userInfo);
      }

      // 如果有token但没有用户信息，尝试获取用户信息
      if (_currentToken != null && _currentUser == null) {
        await _fetchUserInfo();
      }
    } catch (e) {
      print('加载存储的认证信息失败: $e');
      await _clearStoredAuth();
    }
  }

  // 保存认证信息到本地存储
  Future<void> _saveAuth(String token, UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userInfoKey, jsonEncode(user.toJson()));

      _currentToken = token;
      _currentUser = user;
    } catch (e) {
      print('保存认证信息失败: $e');
      throw Exception('保存认证信息失败');
    }
  }

  // 从外部直接设置认证信息（例如，从Web URL hash登录时）
  Future<void> setAuth(String token, UserModel user) async {
    _currentToken = token;
    _currentUser = user;
    await _saveAuth(token, user);
  }

  // 清除存储的认证信息
  Future<void> _clearStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userInfoKey);

      _currentToken = null;
      _currentUser = null;
    } catch (e) {
      print('清除认证信息失败: $e');
    }
  }

  // 用户登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await HttpService.post(
        AppConfig.loginUrl,
        body: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;

        // 先设置token，以便后续请求可以使用
        _currentToken = token;

        // 优先使用登录API返回的用户信息（如果有的话）
        UserModel userInfo;
        if (data.containsKey('user') && data['user'] != null) {
          // 登录API返回了完整用户信息，直接使用
          print('使用登录API返回的完整用户信息');
          userInfo = UserModel.fromJson(data['user']);
        } else if (data.containsKey('username')) {
          // 登录API只返回了基本信息（token + username），先保存基本信息允许登录
          print('登录API返回基本信息，创建临时用户对象');
          final usernameFromApi = data['username'] as String;
          userInfo = UserModel(
            username: usernameFromApi,
            email: usernameFromApi.contains('@') ? usernameFromApi : '',
            emailVerified: false,
            createdAt: DateTime.now().toIso8601String(),
            membership: MembershipInfo(type: 'expired', isActive: false),
          );

          // 立即保存基本信息
          await _saveAuth(token, userInfo);

          // 后台异步刷新完整用户信息
          print('开始后台异步刷新用户信息...');
          _fetchUserInfo()
              .then((fullUserInfo) async {
                print('后台刷新成功，更新用户信息: ${fullUserInfo.membership.type}');
                _currentUser = fullUserInfo;
                await _saveAuth(token, fullUserInfo);
              })
              .catchError((e) {
                print('后台刷新用户信息失败: $e');
              });

          // 返回基本信息，不等待刷新
          return {'success': true, 'token': token, 'user': userInfo.toJson()};
        } else {
          // 登录API没有返回任何用户信息，需要同步请求
          print('登录API未返回用户信息，同步请求用户详细信息');
          userInfo = await _fetchUserInfo();
        }

        // 其他情况：保存并返回
        await _saveAuth(token, userInfo);

        return {'success': true, 'token': token, 'user': userInfo.toJson()};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? '登录失败'};
      }
    } catch (e) {
      print('登录请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 用户注册
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String verificationCode,
  }) async {
    try {
      final response = await HttpService.post(
        AppConfig.registerUrl,
        body: {
          'username': username,
          'email': email,
          'password': password,
          'verificationCode': verificationCode,
        },
      );

      if (response.statusCode == 201) {
        return {'success': true, 'message': '注册成功'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? '注册失败'};
      }
    } catch (e) {
      print('注册请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 发送验证码
  Future<Map<String, dynamic>> sendVerificationCode({
    required String email,
    required String type, // 'register' 或 'forgot'
  }) async {
    try {
      final response = await HttpService.post(
        AppConfig.sendVerificationCodeUrl,
        body: {'email': email, 'type': type},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '验证码已发送'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? '发送验证码失败'};
      }
    } catch (e) {
      print('发送验证码请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 验证邮箱验证码
  Future<Map<String, dynamic>> verifyCode({required String email, required String code}) async {
    try {
      final response = await HttpService.post(
        AppConfig.verifyCodeUrl,
        body: {'email': email, 'code': code},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '验证码正确'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? '验证码错误'};
      }
    } catch (e) {
      print('验证码验证请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 忘记密码
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await HttpService.post(AppConfig.forgotPasswordUrl, body: {'email': email});

      if (response.statusCode == 200) {
        return {'success': true, 'message': '重置邮件已发送'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? '发送重置邮件失败'};
      }
    } catch (e) {
      print('忘记密码请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 重置密码
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await HttpService.post(
        AppConfig.resetPasswordUrl,
        body: {'email': email, 'token': token, 'newPassword': newPassword},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '密码重置成功'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? '密码重置失败'};
      }
    } catch (e) {
      print('重置密码请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 获取用户信息
  Future<UserModel> _fetchUserInfo() async {
    if (_currentToken == null) {
      throw Exception('未登录');
    }

    try {
      // 优先使用 /api/admin/check-status 获取完整用户信息
      final response = await HttpService.get(AppConfig.adminCheckStatusUrl, useAuth: true);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📥 获取到的用户数据: $data');
        
        // 检查会员到期时间
        final membershipExpiresAt = data['membershipExpiresAt'];
        final membershipType = data['membershipType'] ?? 'expired';
        
        // 判断会员是否激活
        bool isActive = false;
        if (membershipExpiresAt != null && membershipType != 'expired') {
          try {
            final expiryDate = DateTime.parse(membershipExpiresAt);
            isActive = expiryDate.isAfter(DateTime.now());
            print('📅 会员到期时间: $expiryDate, 是否激活: $isActive');
          } catch (e) {
            print('⚠️ 解析会员到期时间失败: $e');
          }
        }
        
        // 构建完整的用户信息
        return UserModel(
          username: data['username'] ?? '',
          email: data['email'] ?? '',
          emailVerified: true,
          createdAt: DateTime.now().toIso8601String(),
          membership: MembershipInfo(
            type: membershipType,
            isActive: isActive,
            expiresAt: membershipExpiresAt,
          ),
        );
      } else {
        throw Exception('获取用户信息失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取用户信息失败: $e');
      throw Exception('获取用户信息失败');
    }
  }

  // 刷新用户信息
  Future<void> refreshUserInfo() async {
    print('🔄 refreshUserInfo: 开始刷新用户信息');
    print('🔄 当前 _token: ${_currentToken?.substring(0, 20)}...');

    if (_currentToken != null) {
      try {
        final userInfo = await _fetchUserInfo();
        _currentUser = userInfo;

        // 更新本地存储
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userInfoKey, jsonEncode(userInfo.toJson()));

        print('✅ refreshUserInfo: 刷新成功');
      } catch (e) {
        print('❌ refreshUserInfo: 刷新失败: $e');
      }
    } else {
      print('⚠️ refreshUserInfo: token为空，跳过刷新');
    }
  }

  // 绑定邮箱
  Future<Map<String, dynamic>> bindEmail({
    required String email,
    required String verificationCode,
  }) async {
    try {
      final response = await HttpService.post(
        AppConfig.bindEmailUrl,
        body: {'email': email, 'verificationCode': verificationCode},
        useAuth: true,
      );

      if (response.statusCode == 200) {
        // 刷新用户信息
        await refreshUserInfo();

        return {'success': true, 'message': '邮箱绑定成功'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? '邮箱绑定失败'};
      }
    } catch (e) {
      print('绑定邮箱请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 用户登出
  Future<void> logout() async {
    try {
      // 调用服务器登出接口（可选）
      if (_currentToken != null) {
        await HttpService.post(AppConfig.logoutUrl, useAuth: true);
      }
    } catch (e) {
      print('服务器登出失败: $e');
    } finally {
      // 清除本地认证信息
      await _clearStoredAuth();
    }
  }

  // 检查用户名是否可用（可选功能）
  Future<bool> checkUsernameAvailable(String username) async {
    try {
      // 这里可以添加检查用户名可用性的API调用
      // 目前返回true，实际实现时需要调用相应的API
      return true;
    } catch (e) {
      print('检查用户名可用性失败: $e');
      return false;
    }
  }

  // 检查邮箱是否可用（可选功能）
  Future<bool> checkEmailAvailable(String email) async {
    try {
      // 这里可以添加检查邮箱可用性的API调用
      // 目前返回true，实际实现时需要调用相应的API
      return true;
    } catch (e) {
      print('检查邮箱可用性失败: $e');
      return false;
    }
  }
}
