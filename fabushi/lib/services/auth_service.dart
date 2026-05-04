// 用户认证服务
// 处理用户登录、注册、验证等功能

import 'dart:convert';

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

  UserModel? get currentUser => _currentUser;
  String? get currentToken => _currentToken;
  bool get isLoggedIn => _currentToken != null && _currentUser != null;

  String _safeTokenPreview(String token) {
    final previewLength = token.length < 20 ? token.length : 20;
    return '${token.substring(0, previewLength)}...';
  }

  Map<String, dynamic> _failureFromResponse(
    dynamic response,
    String fallbackMessage,
  ) {
    if (response == null) {
      return {'success': false, 'error': fallbackMessage};
    }

    return {
      'success': false,
      'error': HttpService.getErrorMessage(response),
      'statusCode': response.statusCode,
    };
  }

  Future<void> initialize() async {
    await _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString(_tokenKey);

      final userInfoJson = prefs.getString(_userInfoKey);
      if (userInfoJson != null) {
        final userInfo = jsonDecode(userInfoJson);
        _currentUser = UserModel.fromJson(userInfo);
      }

      if (_currentToken != null && _currentUser == null) {
        await _fetchUserInfo();
      }
    } catch (e) {
      print('加载存储的认证信息失败: $e');
      await _clearStoredAuth();
    }
  }

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

  Future<void> setAuth(String token, UserModel user) async {
    print('🔑 AuthService.setAuth: 开始保存token: ${_safeTokenPreview(token)}');
    _currentToken = token;
    _currentUser = user;
    await _saveAuth(token, user);

    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    if (savedToken == token) {
      print('✅ AuthService.setAuth: token已成功保存到SharedPreferences');
    } else {
      print('❌ AuthService.setAuth: token保存失败！');
    }
  }

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

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await HttpService.post(
        AppConfig.loginUrl,
        body: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;

        _currentToken = token;

        UserModel userInfo;
        if (data.containsKey('user') && data['user'] != null) {
          print('使用登录API返回的完整用户信息');
          userInfo = UserModel.fromJson(data['user']);
        } else if (data.containsKey('username')) {
          print('登录API返回基本信息，创建临时用户对象');
          final usernameFromApi = data['username'] as String;
          userInfo = UserModel(
            username: usernameFromApi,
            email: usernameFromApi.contains('@') ? usernameFromApi : '',
            emailVerified: false,
            createdAt: DateTime.now().toIso8601String(),
            membership: MembershipInfo(type: 'expired', isActive: false),
          );

          await _saveAuth(token, userInfo);

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

          return {'success': true, 'token': token, 'user': userInfo.toJson()};
        } else {
          print('登录API未返回用户信息，同步请求用户详细信息');
          userInfo = await _fetchUserInfo();
        }

        await _saveAuth(token, userInfo);

        return {'success': true, 'token': token, 'user': userInfo.toJson()};
      }

      return _failureFromResponse(response, '登录失败');
    } catch (e) {
      print('登录请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

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
      }

      return _failureFromResponse(response, '注册失败');
    } catch (e) {
      print('注册请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  Future<Map<String, dynamic>> sendVerificationCode({
    required String email,
    required String type,
  }) async {
    try {
      final response = await HttpService.post(
        AppConfig.sendVerificationCodeUrl,
        body: {'email': email, 'type': type},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '验证码已发送'};
      }

      return _failureFromResponse(response, '发送验证码失败');
    } catch (e) {
      print('发送验证码请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  Future<Map<String, dynamic>> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await HttpService.post(
        AppConfig.verifyCodeUrl,
        body: {'email': email, 'code': code},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '验证码正确'};
      }

      return _failureFromResponse(response, '验证码错误');
    } catch (e) {
      print('验证码验证请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await HttpService.post(
        AppConfig.forgotPasswordUrl,
        body: {'email': email},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '重置邮件已发送'};
      }

      return _failureFromResponse(response, '发送重置邮件失败');
    } catch (e) {
      print('忘记密码请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

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
      }

      return _failureFromResponse(response, '密码重置失败');
    } catch (e) {
      print('重置密码请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  Future<UserModel> _fetchUserInfo() async {
    if (_currentToken == null) {
      throw Exception('未登录');
    }

    try {
      final response = await HttpService.get(
        AppConfig.adminCheckStatusUrl,
        useAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📥 获取到的用户数据: $data');

        final membershipExpiresAt = data['membershipExpiresAt'];
        final membershipType = data['membershipType'] ?? 'expired';

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

        return UserModel(
          username: data['username'] ?? '',
          email: data['email'] ?? '',
          emailVerified: true,
          createdAt: DateTime.now().toIso8601String(),
          nickname: data['nickname'],
          avatar: data['avatar'],
          phoneNumber: data['phoneNumber'] ?? data['phone_number'],
          alipayUserId: data['alipayUserId'] ?? data['alipay_user_id'],
          alipayNickname: data['alipayNickname'] ?? data['alipay_nickname'],
          alipayAvatar: data['alipayAvatar'] ?? data['alipay_avatar'],
          mainPractice: data['mainPractice'] is Map
              ? Map<String, dynamic>.from(data['mainPractice'] as Map)
              : null,
          membership: MembershipInfo(
            type: membershipType,
            isActive: isActive,
            expiresAt: membershipExpiresAt,
          ),
        );
      } else {
        throw Exception(
          '获取用户信息失败: ${HttpService.getErrorMessage(response)} (HTTP ${response.statusCode})',
        );
      }
    } catch (e) {
      print('获取用户信息失败: $e');
      throw Exception('获取用户信息失败');
    }
  }

  Future<void> refreshUserInfo() async {
    print('🔄 refreshUserInfo: 开始刷新用户信息');
    if (_currentToken != null) {
      print('🔄 当前 _token: ${_safeTokenPreview(_currentToken!)}');
      try {
        final userInfo = await _fetchUserInfo();
        _currentUser = userInfo;

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

  Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? avatar,
    Map<String, dynamic>? mainPractice,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nickname != null) body['nickname'] = nickname;
      if (avatar != null) body['avatar'] = avatar;
      if (mainPractice != null) body['mainPractice'] = mainPractice;

      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/auth/update-profile',
        body: body,
        useAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] is Map) {
          final userInfo = UserModel.fromJson(
            Map<String, dynamic>.from(data['user'] as Map),
          );
          _currentUser = userInfo;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userInfoKey, jsonEncode(userInfo.toJson()));
        } else {
          await refreshUserInfo();
        }
        return {'success': true, 'message': '更新成功'};
      }

      return _failureFromResponse(response, '更新失败');
    } catch (e) {
      print('更新个人资料失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

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
        await refreshUserInfo();
        return {'success': true, 'message': '邮箱绑定成功'};
      }

      return _failureFromResponse(response, '邮箱绑定失败');
    } catch (e) {
      print('绑定邮箱请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  Future<void> logout() async {
    try {
      if (_currentToken != null) {
        await HttpService.post(AppConfig.logoutUrl, useAuth: true);
      }
    } catch (e) {
      print('服务器登出失败: $e');
    } finally {
      await _clearStoredAuth();
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    if (_currentToken == null) {
      return {'success': false, 'error': '未登录'};
    }
    try {
      final response = await HttpService.delete(
        AppConfig.deleteAccountUrl,
        useAuth: true,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': '注销成功'};
      }

      return _failureFromResponse(response, '注销失败 (HTTP ${response.statusCode})');
    } catch (e) {
      print('注销账户请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  Future<bool> checkUsernameAvailable(String username) async {
    try {
      return true;
    } catch (e) {
      print('检查用户名可用性失败: $e');
      return false;
    }
  }

  Future<bool> checkEmailAvailable(String email) async {
    try {
      return true;
    } catch (e) {
      print('检查邮箱可用性失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> appleLogin({
    required String identityToken,
    required String authorizationCode,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/auth/apple-login',
        body: {
          'identityToken': identityToken,
          'authorizationCode': authorizationCode,
          if (email != null) 'email': email,
          if (givenName != null) 'givenName': givenName,
          if (familyName != null) 'familyName': familyName,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['token'] != null) {
          final token = data['token'] as String;
          final userJson = data['user'];

          final userInfo = UserModel(
            username: data['username'] ?? userJson?['username'] ?? '',
            email: userJson?['email'] ?? email ?? '',
            emailVerified: true,
            createdAt: DateTime.now().toIso8601String(),
            membership: MembershipInfo(
              type: userJson?['membership']?['type'] ?? 'trial',
              isActive: true,
              expiresAt: userJson?['membership']?['expiresAt'],
            ),
          );

          await _saveAuth(token, userInfo);

          return {
            'success': true,
            'token': token,
            'username': data['username'],
            'user': userJson,
            'isNewUser': data['isNewUser'] ?? false,
          };
        }
        return {'success': false, 'error': data['error'] ?? 'Apple登录失败'};
      }

      return _failureFromResponse(response, 'Apple登录失败');
    } catch (e) {
      print('Apple登录请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  Future<Map<String, dynamic>> firebasePhoneLogin({
    required String idToken,
    required String phoneNumber,
    required String firebaseUid,
    required bool isNewUser,
  }) async {
    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/auth/firebase-phone-login',
        body: {
          'idToken': idToken,
          'phoneNumber': phoneNumber,
          'firebaseUid': firebaseUid,
          'isNewUser': isNewUser,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['token'] != null) {
          final token = data['token'] as String;
          final userJson = data['user'];

          final userInfo = UserModel(
            username: data['username'] ?? userJson?['username'] ?? '',
            email: userJson?['email'] ?? '',
            emailVerified: true,
            createdAt: DateTime.now().toIso8601String(),
            membership: MembershipInfo(
              type: userJson?['membership']?['type'] ?? 'trial',
              isActive: true,
              expiresAt: userJson?['membership']?['expiresAt'],
            ),
            phoneNumber: phoneNumber,
          );

          await _saveAuth(token, userInfo);

          return {
            'success': true,
            'token': token,
            'username': data['username'],
            'user': userJson,
            'isNewUser': data['isNewUser'] ?? isNewUser,
          };
        }
        return {'success': false, 'error': data['error'] ?? 'Firebase手机登录失败'};
      }

      return _failureFromResponse(response, 'Firebase手机登录失败');
    } catch (e) {
      print('Firebase手机登录请求失败: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }
}
