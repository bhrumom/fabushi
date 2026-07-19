// 用户认证服务
// 处理用户登录、注册、验证等功能

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../models/user_model.dart';
import 'http_service.dart';
import 'mahayana_command_service.dart';

class AuthService {
  static const String _userInfoKey = AppConfig.userInfoStorageKey;
  static const String _sessionHandle = 'mahayana-rust-session';

  // 单例模式
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final MahayanaCommandService _mahayana = MahayanaCommandService();

  // 当前用户信息
  UserModel? _currentUser;
  bool _hasSession = false;

  UserModel? get currentUser => _currentUser;
  String? get currentToken => _hasSession ? _sessionHandle : null;
  bool get isLoggedIn => _hasSession && _currentUser != null;

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
      wechatHeadimgurl: _firstNonEmptyString([
        user['wechatHeadimgurl'],
        user['wechat_headimgurl'],
      ]),
      wechatBoundAt: user['wechatBoundAt'] as String?,
      alipayUserId:
          (user['alipayProviderSubject'] ??
                  user['alipay_provider_subject'] ??
                  user['alipayUserId'])
              as String?,
      alipayNickname: user['alipayNickname'] as String?,
      alipayAvatar: _firstNonEmptyString([
        user['alipayAvatar'],
        user['alipay_avatar'],
      ]),
      alipayBoundAt: user['alipayBoundAt'] as String?,
      nickname: user['nickname'] as String?,
      avatar: _firstNonEmptyString([
        user['avatar'],
        user['avatarUrl'],
        user['avatar_url'],
        user['alipayAvatar'],
        user['alipay_avatar'],
        user['wechatHeadimgurl'],
        user['wechat_headimgurl'],
      ]),
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

  static String? _firstNonEmptyString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = _optionalString(value)?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
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
          _firstNonEmptyString([
            data['wechatHeadimgurl'],
            data['wechat_headimgurl'],
          ]) ??
          fallbackUser?.wechatHeadimgurl,
      wechatBoundAt:
          _optionalString(data['wechatBoundAt'] ?? data['wechat_bound_at']) ??
          fallbackUser?.wechatBoundAt,
      alipayUserId:
          _optionalString(
            data['alipayProviderSubject'] ??
                data['alipay_provider_subject'] ??
                data['alipayUserId'] ??
                data['alipay_user_id'],
          ) ??
          fallbackUser?.alipayUserId,
      alipayNickname:
          _optionalString(data['alipayNickname'] ?? data['alipay_nickname']) ??
          fallbackUser?.alipayNickname,
      alipayAvatar:
          _firstNonEmptyString([data['alipayAvatar'], data['alipay_avatar']]) ??
          fallbackUser?.alipayAvatar,
      alipayBoundAt:
          _optionalString(data['alipayBoundAt'] ?? data['alipay_bound_at']) ??
          fallbackUser?.alipayBoundAt,
      nickname: _optionalString(data['nickname']) ?? fallbackUser?.nickname,
      avatar:
          _firstNonEmptyString([
            data['avatar'],
            data['avatarUrl'],
            data['avatar_url'],
            data['alipayAvatar'],
            data['alipay_avatar'],
            data['wechatHeadimgurl'],
            data['wechat_headimgurl'],
          ]) ??
          fallbackUser?.avatarUrl,
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

  void _refreshUserInfoAfterLogin() {
    print('开始后台异步刷新用户信息...');
    _fetchUserInfo()
        .then((fullUserInfo) async {
          print('后台刷新成功，更新用户信息: ${fullUserInfo.membership.type}');
          _currentUser = fullUserInfo;
          await _saveAuth(fullUserInfo);
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
      await prefs.remove(AppConfig.tokenStorageKey);

      final userInfoJson = prefs.getString(_userInfoKey);
      if (userInfoJson != null) {
        final userInfo = jsonDecode(userInfoJson);
        _currentUser = UserModel.fromJson(userInfo);
      }

      final session = await _mahayana.execute(const {
        '@type': 'mahayana.auth.session.restore',
      });
      _hasSession = session['loggedIn'] == true;
      if (_hasSession) {
        final rawUser = session['user'];
        if (rawUser is Map) {
          _currentUser = buildRefreshedUser(
            Map<String, dynamic>.from(rawUser),
            fallbackUser: _currentUser,
          );
        }
        _currentUser ??= await _fetchUserInfo();
      }
    } catch (e) {
      _hasSession = false;
      _currentUser = null;
    }
  }

  Future<void> _saveAuth(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.tokenStorageKey);
      await prefs.setString(_userInfoKey, jsonEncode(user.toJson()));

      _hasSession = true;
      _currentUser = user;
    } catch (e) {
      print('保存认证信息失败: $e');
      throw Exception('保存认证信息失败');
    }
  }

  Future<void> setAuth(String _, UserModel user) async {
    await _saveAuth(user);
  }

  Future<void> _clearStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.tokenStorageKey);
      await prefs.remove(_userInfoKey);

      _hasSession = false;
      _currentUser = null;
    } catch (e) {
      print('清除认证信息失败: $e');
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final data = await _mahayana.execute({
        '@type': 'mahayana.auth.password.login',
        'username': username,
        'password': password,
      });
      if (data['sessionStored'] != true) {
        return {'success': false, 'error': '登录服务没有返回账号会话'};
      }
      final userInfo = buildLoginUser(data, requestedIdentifier: username);
      await _saveAuth(userInfo);
      _refreshUserInfoAfterLogin();
      return {
        'success': true,
        'sessionHandle': _sessionHandle,
        'user': userInfo.toJson(),
      };
    } catch (e) {
      print('大乘 Rust 登录失败: $e');
      if (_hasSession && _currentUser != null) {
        print('登录接口已成功返回，保留当前会话并跳过附加资料刷新失败');
        return {
          'success': true,
          'sessionHandle': _sessionHandle,
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
      await _mahayana.execute({
        '@type': 'mahayana.auth.register',
        'username': username,
        'email': email,
        'password': password,
        'verificationCode': verificationCode,
      });
      return {'success': true, 'message': '注册成功'};
    } catch (e) {
      print('大乘 Rust 注册失败: $e');
      return {'success': false, 'error': e.toString(), 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendVerificationCode({
    required String email,
    required String type,
  }) async {
    try {
      await _mahayana.execute({
        '@type': 'mahayana.auth.verification.send',
        'email': email,
        'type': type,
      });
      return {'success': true, 'message': '验证码已发送'};
    } catch (e) {
      print('大乘 Rust 发送验证码失败: $e');
      return {'success': false, 'error': e.toString()};
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
      await _mahayana.execute({
        '@type': 'mahayana.auth.password.forgot',
        'email': email,
      });
      return {'success': true, 'message': '重置邮件已发送'};
    } catch (e) {
      print('大乘 Rust 忘记密码请求失败: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _mahayana.execute({
        '@type': 'mahayana.auth.password.reset',
        'email': email,
        'resetToken': token,
        'newPassword': newPassword,
      });
      return {'success': true, 'message': '密码重置成功'};
    } catch (e) {
      print('大乘 Rust 重置密码失败: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<UserModel> _fetchUserInfo() async {
    if (!_hasSession) {
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
    if (_hasSession) {
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
      print('⚠️ refreshUserInfo: Rust 会话为空，跳过刷新');
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
      if (_hasSession) {
        await _mahayana.execute(const {'@type': 'mahayana.auth.logout'});
      }
    } catch (e) {
      print('服务器登出失败: $e');
    } finally {
      await _clearStoredAuth();
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    if (!_hasSession) {
      await _loadStoredAuth();
    }

    if (!_hasSession) {
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

      return _failureFromResponse(
        response,
        '注销失败 (HTTP ${response.statusCode})',
      );
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
      final data = await _mahayana.execute({
        '@type': 'mahayana.auth.apple.complete',
        'identityToken': identityToken,
        'authorizationCode': authorizationCode,
        'email': ?email,
        'givenName': ?givenName,
        'familyName': ?familyName,
      });
      if (data['sessionStored'] == true) {
        final userJson = data['user'];

        final userInfo = UserModel(
          username: data['username'] ?? userJson?['username'] ?? '',
          userNo: _parseOptionalInt(
            userJson?['userNo'] ??
                userJson?['user_no'] ??
                userJson?['id'] ??
                data['userNo'] ??
                data['userId'],
          ),
          email: userJson?['email'] ?? email ?? '',
          emailVerified: true,
          createdAt: DateTime.now().toIso8601String(),
          usernameChangedAt:
              userJson?['usernameChangedAt'] ??
              userJson?['username_changed_at'],
          membership: MembershipInfo(
            type: userJson?['membership']?['type'] ?? 'trial',
            isActive: true,
            expiresAt: userJson?['membership']?['expiresAt'],
          ),
        );

        await _saveAuth(userInfo);

        return {
          'success': true,
          'sessionHandle': _sessionHandle,
          'username': data['username'],
          'user': userJson,
          'isNewUser': data['isNewUser'] ?? false,
        };
      }
      return {'success': false, 'error': data['error'] ?? 'Apple登录失败'};
    } catch (e) {
      print('大乘 Rust Apple登录失败: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> firebasePhoneLogin({
    required String idToken,
    required String phoneNumber,
    required String firebaseUid,
    required bool isNewUser,
  }) async {
    try {
      final data = await _mahayana.execute({
        '@type': 'mahayana.auth.firebase.phone.complete',
        'idToken': idToken,
        'phoneNumber': phoneNumber,
        'firebaseUid': firebaseUid,
        'isNewUser': isNewUser,
      });
      if (data['sessionStored'] == true) {
        final userJson = data['user'];

        final userInfo = UserModel(
          username: data['username'] ?? userJson?['username'] ?? '',
          userNo: _parseOptionalInt(
            userJson?['userNo'] ??
                userJson?['user_no'] ??
                userJson?['id'] ??
                data['userNo'] ??
                data['userId'],
          ),
          email: userJson?['email'] ?? '',
          emailVerified: true,
          createdAt: DateTime.now().toIso8601String(),
          usernameChangedAt:
              userJson?['usernameChangedAt'] ??
              userJson?['username_changed_at'],
          membership: MembershipInfo(
            type: userJson?['membership']?['type'] ?? 'trial',
            isActive: true,
            expiresAt: userJson?['membership']?['expiresAt'],
          ),
          phoneNumber: phoneNumber,
        );

        await _saveAuth(userInfo);

        return {
          'success': true,
          'sessionHandle': _sessionHandle,
          'username': data['username'],
          'user': userJson,
          'isNewUser': data['isNewUser'] ?? isNewUser,
        };
      }
      return {'success': false, 'error': data['error'] ?? 'Firebase手机登录失败'};
    } catch (e) {
      print('大乘 Rust Firebase手机登录失败: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
