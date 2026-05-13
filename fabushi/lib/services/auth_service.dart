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

  int? _parseOptionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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

  static UserModel buildLoginUser(
    Map<String, dynamic> data, {
    required String requestedIdentifier,
  }) {
    final rawUser = data['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    final resolvedUsername =
        (user['username'] ?? data['username'] ?? requestedIdentifier)
            .toString();
    final resolvedEmail =
        (user['email'] as String?) ??
        (resolvedUsername.contains('@') ? resolvedUsername : '');
    final membershipJson = user['membership'];

    return UserModel(
      username: resolvedUsername,
      userNo: _instance._parseOptionalInt(
        user['userNo'] ??
            user['user_no'] ??
            user['id'] ??
            data['userNo'] ??
            data['userId'],
      ),
      email: resolvedEmail,
      emailVerified:
          user['emailVerified'] as bool? ?? user['email_verified'] == true,
      createdAt:
          (user['createdAt'] ??
                  user['created_at'] ??
                  DateTime.now().toIso8601String())
              .toString(),
      usernameChangedAt:
          (user['usernameChangedAt'] ?? user['username_changed_at']) as String?,
      wechatOpenid: user['wechatOpenid'] as String?,
      wechatNickname: user['wechatNickname'] as String?,
      wechatHeadimgurl: user['wechatHeadimgurl'] as String?,
      wechatBoundAt: user['wechatBoundAt'] as String?,
      alipayUserId: user['alipayUserId'] as String?,
      alipayNickname: user['alipayNickname'] as String?,
      alipayAvatar: user['alipayAvatar'] as String?,
      alipayBoundAt: user['alipayBoundAt'] as String?,
      nickname: user['nickname'] as String?,
      avatar: user['avatar'] as String?,
      phoneNumber: (user['phoneNumber'] ?? user['phone_number']) as String?,
      firebaseUid: (user['firebaseUid'] ?? user['firebase_uid']) as String?,
      mainPractice: user['mainPractice'] is Map
          ? Map<String, dynamic>.from(user['mainPractice'] as Map)
          : null,
      membership: membershipJson is Map
          ? MembershipInfo.fromJson(Map<String, dynamic>.from(membershipJson))
          : MembershipInfo(type: 'expired', isActive: false),
    );
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static bool _parseBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }

  static bool _isMembershipActive(String type, String? expiresAt) {
    if (type == 'expired' || expiresAt == null || expiresAt.isEmpty) {
      return false;
    }

    try {
      final expiryDate = DateTime.parse(expiresAt);
      return expiryDate.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic>? _optionalMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static MembershipInfo _buildMembershipInfo(
    Map<String, dynamic> data, {
    MembershipInfo? fallbackMembership,
  }) {
    final membershipJson = _optionalMap(data['membership']);
    final membershipSource = membershipJson ?? data;
    final type =
        _optionalString(membershipSource['type'] ?? data['membershipType']) ??
        fallbackMembership?.type ??
        'expired';
    final expiresAt =
        _optionalString(
          membershipSource['expiresAt'] ??
              membershipSource['expires_at'] ??
              data['membershipExpiresAt'] ??
              data['membership_expires_at'],
        ) ??
        fallbackMembership?.expiresAt;
    final explicitIsActive =
        membershipSource['isActive'] ?? membershipSource['is_active'];
    final computedIsActive = _isMembershipActive(type, expiresAt);

    return MembershipInfo(
      type: type,
      isActive: _parseBool(explicitIsActive, fallback: computedIsActive),
      expiresAt: expiresAt,
      daysRemaining:
          _instance._parseOptionalInt(
            membershipSource['daysRemaining'] ??
                membershipSource['days_remaining'],
          ) ??
          fallbackMembership?.daysRemaining,
      subscriptionId:
          _optionalString(
            membershipSource['subscriptionId'] ??
                membershipSource['subscription_id'],
          ) ??
          fallbackMembership?.subscriptionId,
      paymentMethod:
          _optionalString(
            membershipSource['paymentMethod'] ??
                membershipSource['payment_method'],
          ) ??
          fallbackMembership?.paymentMethod,
    );
  }

  static UserModel buildRefreshedUser(
    Map<String, dynamic> data, {
    UserModel? fallbackUser,
  }) {
    final membership = _buildMembershipInfo(
      data,
      fallbackMembership: fallbackUser?.membership,
    );

    return UserModel(
      username:
          _optionalString(data['username']) ?? fallbackUser?.username ?? '',
      userNo:
          _instance._parseOptionalInt(
            data['userNo'] ??
                data['user_no'] ??
                data['id'] ??
                data['userId'] ??
                data['user_id'],
          ) ??
          fallbackUser?.userNo,
      email: _optionalString(data['email']) ?? fallbackUser?.email ?? '',
      emailVerified: _parseBool(
        data['emailVerified'] ?? data['email_verified'],
        fallback: fallbackUser?.emailVerified ?? true,
      ),
      createdAt:
          _optionalString(data['createdAt'] ?? data['created_at']) ??
          fallbackUser?.createdAt ??
          DateTime.now().toIso8601String(),
      usernameChangedAt:
          _optionalString(
            data['usernameChangedAt'] ?? data['username_changed_at'],
          ) ??
          fallbackUser?.usernameChangedAt,
      wechatOpenid:
          _optionalString(data['wechatOpenid'] ?? data['wechat_openid']) ??
          fallbackUser?.wechatOpenid,
      wechatNickname:
          _optionalString(data['wechatNickname'] ?? data['wechat_nickname']) ??
          fallbackUser?.wechatNickname,
      wechatHeadimgurl:
          _optionalString(
            data['wechatHeadimgurl'] ?? data['wechat_headimgurl'],
          ) ??
          fallbackUser?.wechatHeadimgurl,
      wechatBoundAt:
          _optionalString(data['wechatBoundAt'] ?? data['wechat_bound_at']) ??
          fallbackUser?.wechatBoundAt,
      alipayUserId:
          _optionalString(data['alipayUserId'] ?? data['alipay_user_id']) ??
          fallbackUser?.alipayUserId,
      alipayNickname:
          _optionalString(data['alipayNickname'] ?? data['alipay_nickname']) ??
          fallbackUser?.alipayNickname,
      alipayAvatar:
          _optionalString(data['alipayAvatar'] ?? data['alipay_avatar']) ??
          fallbackUser?.alipayAvatar,
      alipayBoundAt:
          _optionalString(data['alipayBoundAt'] ?? data['alipay_bound_at']) ??
          fallbackUser?.alipayBoundAt,
      nickname: _optionalString(data['nickname']) ?? fallbackUser?.nickname,
      avatar:
          _optionalString(data['avatar'] ?? data['avatarUrl']) ??
          fallbackUser?.avatar,
      phoneNumber:
          _optionalString(data['phoneNumber'] ?? data['phone_number']) ??
          fallbackUser?.phoneNumber,
      firebaseUid:
          _optionalString(data['firebaseUid'] ?? data['firebase_uid']) ??
          fallbackUser?.firebaseUid,
      mainPractice:
          _optionalMap(data['mainPractice'] ?? data['main_practice']) ??
          fallbackUser?.mainPractice,
      membership: membership,
    );
  }

  void _refreshUserInfoAfterLogin(String token) {
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final userInfo = buildLoginUser(data, requestedIdentifier: username);

        if (data.containsKey('user') && data['user'] != null) {
          print('使用登录API返回的用户信息，并允许后续资料刷新失败时继续登录');
        } else if (data.containsKey('username')) {
          print('登录API返回基本信息，先用最小用户资料完成登录');
        } else {
          print('登录API未返回用户信息，回退到请求入参完成首屏登录');
        }

        _currentToken = token;
        _currentUser = userInfo;
        await _saveAuth(token, userInfo);
        _refreshUserInfoAfterLogin(token);

        return {'success': true, 'token': token, 'user': userInfo.toJson()};
      }

      return _failureFromResponse(response, '登录失败');
    } catch (e) {
      print('登录请求失败: $e');
      if (_currentToken != null && _currentUser != null) {
        print('登录接口已成功返回，保留当前会话并跳过附加资料刷新失败');
        return {
          'success': true,
          'token': _currentToken,
          'user': _currentUser!.toJson(),
        };
      }
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
      final fallbackUser = _currentUser;
      final response = await HttpService.get(
        AppConfig.userInfoUrl,
        useAuth: true,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw Exception('用户信息响应格式不正确');
        }
        final data = Map<String, dynamic>.from(decoded);
        print('📥 获取到的用户数据: $data');

        final userInfo = buildRefreshedUser(data, fallbackUser: fallbackUser);
        final membershipExpiresAt = userInfo.membership.expiresAt;
        if (membershipExpiresAt != null) {
          print(
            '📅 会员到期时间: $membershipExpiresAt, 是否激活: ${userInfo.membership.isActive}',
          );
        }

        return userInfo;
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
            userNo: _parseOptionalInt(userJson?['userNo'] ?? userJson?['user_no'] ?? userJson?['id'] ?? data['userNo'] ?? data['userId']),
            email: userJson?['email'] ?? email ?? '',
            emailVerified: true,
            createdAt: DateTime.now().toIso8601String(),
            usernameChangedAt: userJson?['usernameChangedAt'] ?? userJson?['username_changed_at'],
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
            userNo: _parseOptionalInt(userJson?['userNo'] ?? userJson?['user_no'] ?? userJson?['id'] ?? data['userNo'] ?? data['userId']),
            email: userJson?['email'] ?? '',
            emailVerified: true,
            createdAt: DateTime.now().toIso8601String(),
            usernameChangedAt: userJson?['usernameChangedAt'] ?? userJson?['username_changed_at'],
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
