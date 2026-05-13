import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/like_service.dart';
import '../services/membership_service.dart';
import '../services/alipay_auth_service.dart';
import '../services/sync_service.dart';
import '../services/meditation_session_manager.dart';
import '../services/practice_stats_service.dart';
import 'user_model.dart';

class User {
  final String username;
  final int? userNo;
  final String email;
  final String? membershipType;
  final DateTime? membershipExpiry;
  final bool isAdmin;
  final String? alipayUserId;
  final String? nickname;
  final String? avatar;
  final String? phoneNumber;
  final String? firebaseUid;
  final String? usernameChangedAt;

  User({
    required this.username,
    this.userNo,
    required this.email,
    this.membershipType,
    this.membershipExpiry,
    this.isAdmin = false,
    this.alipayUserId,
    this.nickname,
    this.avatar,
    this.phoneNumber,
    this.firebaseUid,
    this.usernameChangedAt,
  });

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      userNo: _parseOptionalInt(json['userNo'] ?? json['user_no'] ?? json['id']),
      email: json['email'] ?? '',
      membershipType: json['membershipType'],
      membershipExpiry: json['membershipExpiry'] != null
          ? DateTime.parse(json['membershipExpiry'])
          : null,
      isAdmin: json['isAdmin'] ?? false,
      alipayUserId: json['alipayUserId'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      phoneNumber: json['phoneNumber'],
      firebaseUid: json['firebaseUid'],
      usernameChangedAt: json['usernameChangedAt'] ?? json['username_changed_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'userNo': userNo,
      'email': email,
      'membershipType': membershipType,
      'membershipExpiry': membershipExpiry?.toIso8601String(),
      'isAdmin': isAdmin,
      'alipayUserId': alipayUserId,
      'nickname': nickname,
      'avatar': avatar,
      'phoneNumber': phoneNumber,
      'firebaseUid': firebaseUid,
      'usernameChangedAt': usernameChangedAt,
    };
  }

  String get displayName => nickname?.isNotEmpty == true ? nickname! : username;

  bool get hasPremiumMembership {
    if (membershipType == null) return false;
    if (membershipExpiry == null) return false;
    return membershipExpiry!.isAfter(DateTime.now());
  }

  bool get isTrialMember {
    return membershipType == 'trial' && hasPremiumMembership;
  }

  bool get isPremiumMember {
    return membershipType == 'paid' && hasPremiumMembership;
  }
}

class AuthModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final MembershipService _membershipService = MembershipService();
  final AlipayAuthService _alipayAuthService = AlipayAuthService();

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  String? _token;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null && _token != null;
  bool get hasPremiumAccess => _currentUser?.hasPremiumMembership ?? false;
  String? get authToken => _token;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthModel() {
    // Initialization is now handled by the UI layer (AppWrapper) to avoid race conditions.
  }

  DateTime? _parseMembershipExpiry(dynamic expiresAt) {
    if (expiresAt is! String || expiresAt.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(expiresAt);
    } catch (_) {
      return null;
    }
  }

  int? _parseTokenUserNo(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }
      final normalizedPayload = base64.normalize(
        parts[1].replaceAll('-', '+').replaceAll('_', '/'),
      );
      final payload = jsonDecode(
        utf8.decode(base64.decode(normalizedPayload)),
      );
      if (payload is Map) {
        return User._parseOptionalInt(
          payload['userNo'] ??
              payload['user_no'] ??
              payload['userId'] ??
              payload['user_id'] ??
              payload['id'],
        );
      }
    } catch (_) {
      // Ignore token parsing failures and fall back to server or cached state.
    }
    return null;
  }

  User _buildBootstrapUser(
    String token,
    String username, {
    Map<String, dynamic>? userJson,
    User? fallbackUser,
    String? fallbackEmail,
    String? fallbackPhoneNumber,
    String? fallbackFirebaseUid,
    String? fallbackMembershipType,
    DateTime? fallbackMembershipExpiry,
  }) {
    if (userJson != null) {
      return _userFromServerPayload(
        userJson,
        isAdmin: fallbackUser?.isAdmin ?? false,
        fallbackUsername: username,
        fallbackEmail: fallbackEmail ?? fallbackUser?.email,
        fallbackPhoneNumber: fallbackPhoneNumber ?? fallbackUser?.phoneNumber,
        fallbackFirebaseUid: fallbackFirebaseUid ?? fallbackUser?.firebaseUid,
        fallbackMembershipType:
            fallbackMembershipType ?? fallbackUser?.membershipType,
        fallbackMembershipExpiry:
            fallbackMembershipExpiry ?? fallbackUser?.membershipExpiry,
      );
    }

    return User(
      username: username,
      userNo: _parseTokenUserNo(token) ?? fallbackUser?.userNo,
      email: fallbackEmail ?? fallbackUser?.email ?? '',
      membershipType: fallbackMembershipType ?? fallbackUser?.membershipType,
      membershipExpiry:
          fallbackMembershipExpiry ?? fallbackUser?.membershipExpiry,
      isAdmin: fallbackUser?.isAdmin ?? false,
      alipayUserId: fallbackUser?.alipayUserId,
      nickname: fallbackUser?.nickname,
      avatar: fallbackUser?.avatar,
      phoneNumber: fallbackPhoneNumber ?? fallbackUser?.phoneNumber,
      firebaseUid: fallbackFirebaseUid ?? fallbackUser?.firebaseUid,
      usernameChangedAt: fallbackUser?.usernameChangedAt,
    );
  }

  UserModel _buildStoredUserModel(User user) {
    final membershipType = user.membershipType ?? 'expired';
    return UserModel(
      username: user.username,
      userNo: user.userNo,
      email: user.email,
      emailVerified: true,
      createdAt: DateTime.now().toIso8601String(),
      usernameChangedAt: user.usernameChangedAt,
      membership: MembershipInfo(
        type: membershipType,
        isActive: user.membershipExpiry?.isAfter(DateTime.now()) ?? false,
        expiresAt: user.membershipExpiry?.toIso8601String(),
      ),
      alipayUserId: user.alipayUserId,
      nickname: user.nickname,
      avatar: user.avatar,
      phoneNumber: user.phoneNumber,
      firebaseUid: user.firebaseUid,
    );
  }

  User _userFromServerPayload(
    Map<String, dynamic> userJson, {
    required bool isAdmin,
    String? fallbackUsername,
    String? fallbackEmail,
    String? fallbackPhoneNumber,
    String? fallbackFirebaseUid,
    String? fallbackMembershipType,
    DateTime? fallbackMembershipExpiry,
  }) {
    final membershipJson = userJson['membership'];
    final membershipType = membershipJson is Map
        ? membershipJson['type'] as String?
        : fallbackMembershipType;
    final membershipExpiry = membershipJson is Map
        ? _parseMembershipExpiry(membershipJson['expiresAt']) ??
              fallbackMembershipExpiry
        : fallbackMembershipExpiry;

    return User(
      username: userJson['username'] ?? fallbackUsername ?? '',
      userNo: User._parseOptionalInt(
        userJson['userNo'] ?? userJson['user_no'] ?? userJson['id'],
      ),
      email: userJson['email'] ?? fallbackEmail ?? '',
      membershipType: membershipType,
      membershipExpiry: membershipExpiry,
      isAdmin: isAdmin,
      alipayUserId: userJson['alipayUserId'] ?? userJson['alipay_user_id'],
      nickname: userJson['nickname'],
      avatar: userJson['avatar'],
      phoneNumber:
          userJson['phoneNumber'] ?? userJson['phone_number'] ?? fallbackPhoneNumber,
      firebaseUid:
          userJson['firebaseUid'] ?? userJson['firebase_uid'] ?? fallbackFirebaseUid,
      usernameChangedAt:
          userJson['usernameChangedAt'] ?? userJson['username_changed_at'],
    );
  }

  Future<void> _syncMeditationPracticeForCurrentUser() async {
    await MeditationSessionManager().switchUser(_currentUser?.username);
  }

  Future<void> loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJsonString = prefs.getString('user_data');

      if (token != null && userJsonString != null) {
        _token = token;
        final userData = json.decode(userJsonString);
        _currentUser = User.fromJson(userData);

        final basicUserModel = UserModel(
          username: _currentUser!.username,
          userNo: _currentUser!.userNo,
          email: _currentUser!.email,
          emailVerified: true,
          createdAt: DateTime.now().toIso8601String(),
          usernameChangedAt: _currentUser!.usernameChangedAt,
          membership: MembershipInfo(
            type: _currentUser!.membershipType ?? 'expired',
            isActive: _currentUser!.hasPremiumMembership,
            expiresAt: _currentUser!.membershipExpiry?.toIso8601String(),
          ),
          alipayUserId: _currentUser!.alipayUserId,
          nickname: _currentUser!.nickname,
          avatar: _currentUser!.avatar,
          phoneNumber: _currentUser!.phoneNumber,
          firebaseUid: _currentUser!.firebaseUid,
        );
        await _authService.setAuth(token, basicUserModel);
        LikeService().setAuthToken(token);
        PracticeStatsService().setAuthToken(token);
        await LikeService().initialize(userId: _currentUser!.username);
        await _syncMeditationPracticeForCurrentUser();
        unawaited(PracticeStatsService().flushPendingRecords());

        await SyncService().initialize();
        SyncService().pullFromCloud();

        notifyListeners();
        refreshUserInfo();
      }
    } catch (e) {
      debugPrint('加载存储的认证信息失败: $e');
      _currentUser = null;
      _token = null;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.login(username, password);

      if (result['success'] == true) {
        _token = result['token'];
        final userJson = result['user'];

        final adminStatusResult = await _membershipService.getAdminStats(_token!);
        final bool isAdmin =
            adminStatusResult['success'] == true &&
            adminStatusResult['isAdmin'] == true;

        if (userJson is Map<String, dynamic>) {
          _currentUser = _userFromServerPayload(
            userJson,
            isAdmin: isAdmin,
            fallbackUsername: username,
            fallbackEmail: username.contains('@') ? username : '',
          );
        } else {
          _currentUser = User(
            username: username,
            email: username.contains('@') ? username : '',
            membershipType: null,
            membershipExpiry: null,
            isAdmin: isAdmin,
          );
        }

        await _storeAuth();
        PracticeStatsService().setAuthToken(_token);
        await LikeService().initialize(userId: _currentUser!.username);
        await _syncMeditationPracticeForCurrentUser();
        unawaited(PracticeStatsService().flushPendingRecords());

        await SyncService().initialize();
        SyncService().fullSync();

        _setLoading(false);
        notifyListeners();

        refreshUserInfo();

        return true;
      } else {
        _setError(result['error'] ?? '登录失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('登录时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    String verificationCode,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.register(
        username: username,
        email: email,
        password: password,
        verificationCode: verificationCode,
      );

      if (result['success'] == true) {
        _setLoading(false);
        return await login(username, password);
      } else {
        _setError(result['message'] ?? '注册失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('注册时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendVerificationCode(
    String email, {
    String type = 'register',
  }) async {
    try {
      final result = await _authService.sendVerificationCode(
        email: email,
        type: type,
      );
      return result['success'] == true;
    } catch (e) {
      _setError('发送验证码失败: $e');
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.forgotPassword(email);
      _setLoading(false);

      if (result['success'] == true) {
        return true;
      } else {
        _setError(result['message'] ?? '发送重置邮件失败');
        return false;
      }
    } catch (e) {
      _setError('发送重置邮件时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.resetPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );
      _setLoading(false);

      if (result['success'] == true) {
        return true;
      } else {
        _setError(result['message'] ?? '重置密码失败');
        return false;
      }
    } catch (e) {
      _setError('重置密码时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> refreshUserInfo() async {
    if (_token == null) return;

    try {
      debugPrint('🔄 开始刷新用户信息...');

      final adminStatusResult = await _membershipService.getAdminStats(_token!);
      final bool isAdmin =
          adminStatusResult['success'] == true &&
          adminStatusResult['isAdmin'] == true;

      debugPrint('👤 管理员状态: $isAdmin');

      await _authService.refreshUserInfo();
      final userModel = _authService.currentUser;

      if (userModel != null) {
        debugPrint(
          '📊 会员信息: ${userModel.membership.type}, 过期: ${userModel.membership.expiresAt}',
        );

        _currentUser = User(
          username: userModel.username,
          userNo: userModel.userNo ?? _currentUser?.userNo,
          email: userModel.email ?? '',
          membershipType: userModel.membership.type,
          membershipExpiry: userModel.membership.expiresAt != null
              ? DateTime.parse(userModel.membership.expiresAt!)
              : null,
          isAdmin: isAdmin,
          alipayUserId: userModel.alipayUserId,
          nickname: userModel.nickname,
          avatar: userModel.avatarUrl,
          phoneNumber: userModel.phoneNumber,
          firebaseUid: userModel.firebaseUid,
          usernameChangedAt: userModel.usernameChangedAt,
        );

        await _storeAuth();
        await _syncMeditationPracticeForCurrentUser();
        notifyListeners();

        debugPrint('✅ 用户信息刷新完成');
      } else {
        debugPrint('⚠️ 未能获取用户信息');
      }
    } catch (e) {
      debugPrint('❌ 刷新用户信息失败: $e');
    }
  }

  Future<Map<String, dynamic>> getAlipayLoginUrl({String? platform}) async {
    try {
      return await _alipayAuthService.getAlipayLoginUrl(platform: platform);
    } catch (e) {
      _setError('获取支付宝登录链接失败: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> alipayLogin(String authCode) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _alipayAuthService.alipayLogin(authCode, null);

      if (result['success'] == true) {
        _token = result['token'];
        final username = result['username'] ?? '';
        final email = result['email'] ?? '';
        final userJson = result['user'];
        final trialExpiry = DateTime.now().add(const Duration(days: 3));
        final bootstrapUser = userJson is Map
            ? _buildBootstrapUser(
                _token!,
                username,
                userJson: Map<String, dynamic>.from(userJson as Map),
                fallbackEmail: email,
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              )
            : _buildBootstrapUser(
                _token!,
                username,
                fallbackEmail: email,
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              );

        await _authService.setAuth(_token!, _buildStoredUserModel(bootstrapUser));

        _currentUser = bootstrapUser;

        await _storeAuth();
        await LikeService().initialize(userId: _currentUser!.username);
        await _syncMeditationPracticeForCurrentUser();

        _setLoading(false);
        notifyListeners();

        refreshUserInfo();
        return true;
      } else {
        _setError(result['message'] ?? '支付宝登录失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('支付宝登录时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> alipayOneClickRegister(
    String alipayUserId,
    String? nickname,
    String? avatar,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('支付宝一键注册开始: alipayUserId=$alipayUserId');

      final result = await _alipayAuthService.alipayOneClickRegister(
        alipayUserId: alipayUserId,
        nickname: nickname,
        avatar: avatar,
      );

      debugPrint(
        '支付宝一键注册结果: success=${result['success']}, error=${result['error']}',
      );

      if (result['success'] == true) {
        _token = result['token'];
        final username = result['username'];
        final email = result['email'];
        final userJson = result['user'];
        final trialExpiry = DateTime.now().add(const Duration(days: 3));
        final bootstrapUser = userJson is Map
            ? _buildBootstrapUser(
                _token!,
                username,
                userJson: Map<String, dynamic>.from(userJson as Map),
                fallbackEmail: email ?? '',
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              )
            : _buildBootstrapUser(
                _token!,
                username,
                fallbackEmail: email ?? '',
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              );

        await _authService.setAuth(_token!, _buildStoredUserModel(bootstrapUser));

        _currentUser = bootstrapUser;

        await _storeAuth();
        await LikeService().initialize(userId: _currentUser!.username);
        await _syncMeditationPracticeForCurrentUser();
        _setLoading(false);
        notifyListeners();

        refreshUserInfo();

        return true;
      } else {
        _setError(result['message'] ?? '支付宝一键注册失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('支付宝一键注册时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> appleLogin({
    required String identityToken,
    required String authorizationCode,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('🍎 Apple登录开始');

      final result = await _authService.appleLogin(
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        email: email,
        givenName: givenName,
        familyName: familyName,
      );

      debugPrint('🍎 Apple登录结果: success=${result['success']}');

      if (result['success'] == true) {
        _token = result['token'];
        final userJson = result['user'];
        final username = result['username'] ?? userJson?['username'] ?? '';
        final trialExpiry = DateTime.now().add(const Duration(days: 3));
        final bootstrapUser = userJson is Map<String, dynamic>
            ? _buildBootstrapUser(
                _token!,
                username,
                userJson: userJson,
                fallbackEmail: email ?? '',
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              )
            : _buildBootstrapUser(
                _token!,
                username,
                fallbackEmail: email ?? '',
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              );

        await _authService.setAuth(_token!, _buildStoredUserModel(bootstrapUser));

        _currentUser = bootstrapUser;

        await _storeAuth();
        await LikeService().initialize(userId: _currentUser!.username);
        await _syncMeditationPracticeForCurrentUser();
        _setLoading(false);
        notifyListeners();

        refreshUserInfo();

        await SyncService().initialize();
        SyncService().fullSync();

        debugPrint('✅ Apple登录完成: $username');
        return true;
      } else {
        _setError(result['error'] ?? 'Apple登录失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Apple登录错误: $e');
      _setError('Apple登录错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> firebasePhoneLogin({
    required String idToken,
    required String phoneNumber,
    required String firebaseUid,
    required bool isNewUser,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('📱 Firebase手机登录开始: phone=$phoneNumber, isNew=$isNewUser');

      final result = await _authService.firebasePhoneLogin(
        idToken: idToken,
        phoneNumber: phoneNumber,
        firebaseUid: firebaseUid,
        isNewUser: isNewUser,
      );

      debugPrint('📱 Firebase手机登录结果: success=${result['success']}');

      if (result['success'] == true) {
        _token = result['token'];
        final userJson = result['user'];
        final username = result['username'] ?? userJson?['username'] ?? '';
        final trialExpiry = DateTime.now().add(const Duration(days: 3));
        final bootstrapUser = userJson is Map<String, dynamic>
            ? _buildBootstrapUser(
                _token!,
                username,
                userJson: userJson,
                fallbackPhoneNumber: phoneNumber,
                fallbackFirebaseUid: firebaseUid,
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              )
            : _buildBootstrapUser(
                _token!,
                username,
                fallbackPhoneNumber: phoneNumber,
                fallbackFirebaseUid: firebaseUid,
                fallbackMembershipType: 'trial',
                fallbackMembershipExpiry: trialExpiry,
              );

        await _authService.setAuth(_token!, _buildStoredUserModel(bootstrapUser));

        _currentUser = bootstrapUser;

        await _storeAuth();
        await LikeService().initialize(userId: _currentUser!.username);
        await _syncMeditationPracticeForCurrentUser();
        _setLoading(false);
        notifyListeners();

        refreshUserInfo();

        debugPrint('✅ Firebase手机登录完成: $username');
        return true;
      } else {
        _setError(result['error'] ?? 'Firebase手机登录失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Firebase手机登录错误: $e');
      _setError('Firebase手机登录错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> alipayRegister(
    String username,
    String email,
    String authCode,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint(
        '支付宝注册开始: username=$username, email=$email, authCode=$authCode',
      );

      final loginResult = await _alipayAuthService.alipayLogin(authCode, null);

      debugPrint('支付宝登录结果: $loginResult');

      if (loginResult['success'] == true) {
        _token = loginResult['token'];
        final userJson = loginResult['user'];

        final adminStatusResult = await _membershipService.getAdminStats(_token!);
        final bool isAdmin =
            adminStatusResult['success'] == true &&
            adminStatusResult['isAdmin'] == true;

        if (userJson is Map<String, dynamic>) {
          _currentUser = _userFromServerPayload(
            userJson,
            isAdmin: isAdmin,
            fallbackUsername: userJson['username'] ?? username,
            fallbackEmail: userJson['email'] ?? email,
          );
        } else {
          _currentUser = User(
            username: username,
            email: email,
            membershipType: 'trial',
            membershipExpiry: DateTime.now().add(const Duration(days: 3)),
            isAdmin: isAdmin,
          );
        }

        await _storeAuth();
        await LikeService().initialize(userId: _currentUser!.username);
        await _syncMeditationPracticeForCurrentUser();

        _setLoading(false);
        notifyListeners();
        return true;
      } else if (loginResult['needsRegistration'] == true) {
        final alipayUser = loginResult['alipayUser'];

        debugPrint('需要注册新用户，支付宝用户信息: $alipayUser');

        final autoUsername = username.isNotEmpty
            ? username
            : (alipayUser?['nick_name'] ??
                  '支付宝用户_${DateTime.now().millisecondsSinceEpoch}');
        final autoEmail = email.isNotEmpty
            ? email
            : '${alipayUser?['user_id'] ?? authCode}@alipay.user';

        debugPrint('支付宝新用户自动注册: username=$autoUsername, email=$autoEmail');

        final result = await _alipayAuthService.alipayRegister(
          alipayUserId: alipayUser?['user_id'] ?? authCode,
          username: autoUsername,
          password: '',
          email: autoEmail,
          nickname: alipayUser?['nick_name'],
          avatar: alipayUser?['avatar'],
        );

        debugPrint('支付宝注册结果: $result');

        if (result['success'] == true) {
          _token = result['token'];
          final userJson = result['user'];

          final adminStatusResult = await _membershipService.getAdminStats(_token!);
          final bool isAdmin =
              adminStatusResult['success'] == true &&
              adminStatusResult['isAdmin'] == true;

          if (userJson is Map<String, dynamic>) {
            _currentUser = _userFromServerPayload(
              userJson,
              isAdmin: isAdmin,
              fallbackUsername: autoUsername,
              fallbackEmail: autoEmail,
              fallbackMembershipType: 'trial',
              fallbackMembershipExpiry: DateTime.now().add(const Duration(days: 3)),
            );
          } else {
            _currentUser = User(
              username: autoUsername,
              email: autoEmail,
              membershipType: 'trial',
              membershipExpiry: DateTime.now().add(const Duration(days: 3)),
              isAdmin: isAdmin,
            );
          }

          await _storeAuth();
          await LikeService().initialize(userId: _currentUser!.username);
          await _syncMeditationPracticeForCurrentUser();
          _setLoading(false);
          notifyListeners();
          return true;
        } else {
          _setError(result['error'] ?? '支付宝注册失败');
          _setLoading(false);
          return false;
        }
      } else {
        String errorMessage = loginResult['error'] ?? '支付宝登录失败';
        String? errorCode = loginResult['code'];

        if (errorCode == 'CODE_INVALID') {
          errorMessage = '支付宝授权码已过期或无效，请重新尝试登录';
        } else if (errorCode == 'CODE_REUSED') {
          errorMessage = '支付宝授权码已被使用，请重新登录';
        } else if (errorCode == 'CONFIG_ERROR') {
          errorMessage = '支付宝服务配置错误，请联系技术支持';
        }

        _setError(errorMessage);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('支付宝注册时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> setTokenDirectly(
    String token,
    String username, {
    Map<String, dynamic>? userJson,
  }) async {
    final bootstrapUser = _buildBootstrapUser(
      token,
      username,
      userJson: userJson,
      fallbackUser: _currentUser,
    );

    await _authService.setAuth(token, _buildStoredUserModel(bootstrapUser));

    _token = token;
    _currentUser = bootstrapUser;

    await _storeAuth();
    await _syncMeditationPracticeForCurrentUser();
    notifyListeners();

    await refreshUserInfo();
  }

  Future<void> loginWithToken(
    String token,
    String username, {
    Map<String, dynamic>? userJson,
  }) async {
    try {
      debugPrint('使用token登录: username=$username');

      _token = token;
      final bootstrapUser = _buildBootstrapUser(
        token,
        username,
        userJson: userJson,
        fallbackUser: _currentUser,
        fallbackMembershipType: _currentUser?.membershipType ?? 'trial',
        fallbackMembershipExpiry:
            _currentUser?.membershipExpiry ?? DateTime.now().add(const Duration(days: 3)),
      );

      await _authService.setAuth(token, _buildStoredUserModel(bootstrapUser));

      _currentUser = bootstrapUser;

      await _storeAuth();
      await LikeService().initialize(userId: _currentUser!.username);
      await _syncMeditationPracticeForCurrentUser();
      notifyListeners();

      debugPrint('✅ Token已设置，登录完成');

      await refreshUserInfo();
    } catch (e) {
      debugPrint('使用token登录失败: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.deleteAccount();
      if (result['success'] == true) {
        await logout();
        _setLoading(false);
        return {'success': true, 'message': '注销成功'};
      } else {
        _setError(result['error'] ?? '注销失败');
        _setLoading(false);
        return result;
      }
    } catch (e) {
      _setError('注销时发生错误: $e');
      _setLoading(false);
      return {'success': false, 'error': '操作发生错误'};
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      debugPrint('登出请求失败: $e');
    } finally {
      _currentUser = null;
      _token = null;
      _clearError();
      LikeService().setAuthToken(null);
      PracticeStatsService().setAuthToken(null);
      await LikeService().clearUserData();
      await SyncService().clearSyncState();
      await MeditationSessionManager().switchUser(null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');

      notifyListeners();
    }
  }

  Future<void> _storeAuth() async {
    if (_token != null && _currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_data', json.encode(_currentUser!.toJson()));
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    switch (permission) {
      case 'admin':
        return _currentUser!.isAdmin;
      case 'premium':
        return _currentUser!.hasPremiumMembership || _currentUser!.isAdmin;
      case 'basic':
        return true;
      default:
        return false;
    }
  }

  String getMembershipStatusText() {
    if (_currentUser == null) return '未登录';
    if (_currentUser!.membershipType == null ||
        _currentUser!.membershipType == 'expired') {
      return '已过期';
    }
    if (_currentUser!.isPremiumMember) return '高级会员';
    if (_currentUser!.isTrialMember) return '试用会员';
    return _currentUser!.membershipType ?? '普通用户';
  }

  String? getMembershipExpiryText() {
    if (_currentUser?.membershipExpiry == null) return null;

    final expiry = _currentUser!.membershipExpiry!;
    final now = DateTime.now();
    final difference = expiry.difference(now);

    if (difference.isNegative) return '已过期';

    if (difference.inDays > 0) {
      return '${difference.inDays}天后到期';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时后到期';
    } else {
      return '即将到期';
    }
  }

  int? getMembershipDaysRemaining() {
    if (_currentUser?.membershipExpiry == null) return null;

    final expiry = _currentUser!.membershipExpiry!;
    final now = DateTime.now();
    final difference = expiry.difference(now);

    if (difference.isNegative) return -1;

    return difference.inDays;
  }
}
