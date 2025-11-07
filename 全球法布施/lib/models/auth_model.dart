import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/like_service.dart';
import '../services/membership_service.dart';
import '../services/alipay_auth_service.dart';
import 'user_model.dart';

class User {
  final String username;
  final String email;
  final String? membershipType;
  final DateTime? membershipExpiry;
  final bool isAdmin;
  final String? alipayUserId;

  User({
    required this.username,
    required this.email,
    this.membershipType,
    this.membershipExpiry,
    this.isAdmin = false,
    this.alipayUserId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      membershipType: json['membershipType'],
      membershipExpiry: json['membershipExpiry'] != null
          ? DateTime.parse(json['membershipExpiry'])
          : null,
      isAdmin: json['isAdmin'] ?? false,
      alipayUserId: json['alipayUserId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'membershipType': membershipType,
      'membershipExpiry': membershipExpiry?.toIso8601String(),
      'isAdmin': isAdmin,
      'alipayUserId': alipayUserId,
    };
  }

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
  // 服务实例
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
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthModel() {
    // Initialization is now handled by the UI layer (AppWrapper) to avoid race conditions.
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

        // 关键：设置 AuthService 的 token
        final basicUserModel = UserModel(
          username: _currentUser!.username,
          email: _currentUser!.email,
          emailVerified: true,
          createdAt: DateTime.now().toIso8601String(),
          membership: MembershipInfo(
            type: _currentUser!.membershipType ?? 'expired',
            isActive: _currentUser!.hasPremiumMembership,
            expiresAt: _currentUser!.membershipExpiry?.toIso8601String(),
          ),
          alipayUserId: _currentUser!.alipayUserId,
        );
        await _authService.setAuth(token, basicUserModel);
        LikeService().setAuthToken(token);

        notifyListeners(); // 立即更新UI显示登录状态

        // 后台异步刷新用户信息（不阻塞UI）
        refreshUserInfo();
      }
    } catch (e) {
      debugPrint('加载存储的认证信息失败: $e');
      // 加载失败时清除状态
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

        // 登录后，额外获取管理员状态
        final adminStatusResult = await _membershipService.getAdminStats(_token!);
        final bool isAdmin =
            adminStatusResult['success'] == true && adminStatusResult['isAdmin'] == true;

        final membershipJson = userJson['membership'] ?? {};
        _currentUser = User(
          username: userJson['username'] ?? '',
          email: userJson['email'] ?? '',
          membershipType: membershipJson['type'],
          membershipExpiry: membershipJson['expiresAt'] != null
              ? DateTime.parse(membershipJson['expiresAt'])
              : null,
          isAdmin: isAdmin,
          alipayUserId: userJson['alipayUserId'],
        );

        await _storeAuth();

        _setLoading(false);
        notifyListeners();

        // 后台异步刷新完整用户信息（包括会员信息）
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
        // 注册成功后自动登录
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

  Future<bool> sendVerificationCode(String email, {String type = 'register'}) async {
    try {
      final result = await _authService.sendVerificationCode(email: email, type: type);
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

  Future<bool> resetPassword(String email, String token, String newPassword) async {
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
      await _authService.refreshUserInfo();
      final userModel = _authService.currentUser;

      if (userModel != null) {
        final adminStatusResult = await _membershipService.getAdminStats(_token!);
        final bool isAdmin =
            adminStatusResult['success'] == true && adminStatusResult['isAdmin'] == true;

        _currentUser = User(
          username: userModel.username,
          email: userModel.email ?? '',
          membershipType: userModel.membership.type,
          membershipExpiry: userModel.membership.expiresAt != null
              ? DateTime.parse(userModel.membership.expiresAt!)
              : null,
          isAdmin: isAdmin,
          alipayUserId: userModel.alipayUserId,
        );
        await _storeAuth();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('刷新用户信息失败: $e');
    }
  }

  // 支付宝登录相关方法
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
        final userJson = result['user'];

        // 登录后，额外获取管理员状态
        final adminStatusResult = await _membershipService.getAdminStats(_token!);
        final bool isAdmin =
            adminStatusResult['success'] == true && adminStatusResult['isAdmin'] == true;

        final membershipJson = userJson['membership'] ?? {};
        _currentUser = User(
          username: userJson['username'] ?? '',
          email: userJson['email'] ?? '',
          membershipType: membershipJson['type'],
          membershipExpiry: membershipJson['expiresAt'] != null
              ? DateTime.parse(membershipJson['expiresAt'])
              : null,
          isAdmin: isAdmin,
        );

        await _storeAuth();

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(result['error'] ?? '支付宝登录失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('支付宝登录时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 支付宝一键注册（无需填写信息）- 从macOS回调参数直接注册
  Future<bool> alipayOneClickRegister(String alipayUserId, String? nickname, String? avatar) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('支付宝一键注册开始: alipayUserId=$alipayUserId');

      // 直接调用一键注册API（授权码已在回调时使用）
      final result = await _alipayAuthService.alipayOneClickRegister(
        alipayUserId: alipayUserId,
        nickname: nickname,
        avatar: avatar,
      );

      debugPrint('支付宝一键注册结果: $result');

      if (result['success'] == true) {
        // 注册成功后自动登录
        _token = result['token'];
        final username = result['username'];
        final email = result['email'];

        // 先设置token到AuthService
        final basicUserModel = UserModel(
          username: username,
          email: email ?? '',
          emailVerified: true,
          createdAt: DateTime.now().toIso8601String(),
          membership: MembershipInfo(type: 'trial', isActive: true),
        );
        await _authService.setAuth(_token!, basicUserModel);

        // 获取完整的用户信息
        await _authService.refreshUserInfo();
        final userModel = _authService.currentUser;

        if (userModel != null) {
          // 获取管理员状态
          final adminStatusResult = await _membershipService.getAdminStats(_token!);
          final bool isAdmin =
              adminStatusResult['success'] == true && adminStatusResult['isAdmin'] == true;

          final membershipJson = userModel.membership.toJson();
          _currentUser = User(
            username: userModel.username,
            email: userModel.email ?? '',
            membershipType: membershipJson['type'],
            membershipExpiry: membershipJson['expiresAt'] != null
                ? DateTime.parse(membershipJson['expiresAt'])
                : null,
            isAdmin: isAdmin,
            alipayUserId: userModel.alipayUserId,
          );

          await _storeAuth();
          _setLoading(false);
          notifyListeners();
          return true;
        } else {
          throw Exception('获取用户信息失败');
        }
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

  Future<bool> alipayRegister(String username, String email, String authCode) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('支付宝注册开始: username=$username, email=$email, authCode=$authCode');

      // 首先尝试使用授权码直接登录（可能后端已经自动创建了用户）
      final loginResult = await _alipayAuthService.alipayLogin(authCode, null);

      debugPrint('支付宝登录结果: $loginResult');

      if (loginResult['success'] == true) {
        // 如果登录成功，直接使用返回的用户信息
        _token = loginResult['token'];
        final userJson = loginResult['user'];

        // 获取管理员状态
        final adminStatusResult = await _membershipService.getAdminStats(_token!);
        final bool isAdmin =
            adminStatusResult['success'] == true && adminStatusResult['isAdmin'] == true;

        final membershipJson = userJson['membership'] ?? {};
        _currentUser = User(
          username: userJson['username'] ?? '',
          email: userJson['email'] ?? '',
          membershipType: membershipJson['type'],
          membershipExpiry: membershipJson['expiresAt'] != null
              ? DateTime.parse(membershipJson['expiresAt'])
              : null,
          isAdmin: isAdmin,
          alipayUserId: userJson['alipayUserId'],
        );

        await _storeAuth();
        _setLoading(false);
        notifyListeners();
        return true;
      } else if (loginResult['needsRegistration'] == true) {
        // 如果是新用户需要注册，使用支付宝用户信息自动注册
        final alipayUser = loginResult['alipayUser'];

        debugPrint('需要注册新用户，支付宝用户信息: $alipayUser');

        // 生成默认的用户名和邮箱（如果未提供）
        final autoUsername = username.isNotEmpty
            ? username
            : (alipayUser?['nick_name'] ?? '支付宝用户_${DateTime.now().millisecondsSinceEpoch}');
        final autoEmail = email.isNotEmpty
            ? email
            : '${alipayUser?['user_id'] ?? authCode}@alipay.user';

        debugPrint('支付宝新用户自动注册: username=$autoUsername, email=$autoEmail');

        final result = await _alipayAuthService.alipayRegister(
          alipayUserId: alipayUser?['user_id'] ?? authCode,
          username: autoUsername,
          password: '', // 支付宝用户不需要密码
          email: autoEmail,
          nickname: alipayUser?['nick_name'],
          avatar: alipayUser?['avatar'],
        );

        debugPrint('支付宝注册结果: $result');

        if (result['success'] == true) {
          // 注册成功后自动登录
          _token = result['token'];
          final userJson = result['user'];

          // 获取管理员状态
          final adminStatusResult = await _membershipService.getAdminStats(_token!);
          final bool isAdmin =
              adminStatusResult['success'] == true && adminStatusResult['isAdmin'] == true;

          final membershipJson = userJson['membership'] ?? {};
          _currentUser = User(
            username: userJson['username'] ?? '',
            email: userJson['email'] ?? '',
            membershipType: membershipJson['type'],
            membershipExpiry: membershipJson['expiresAt'] != null
                ? DateTime.parse(membershipJson['expiresAt'])
                : null,
            isAdmin: isAdmin,
            alipayUserId: userJson['alipayUserId'],
          );

          await _storeAuth();
          _setLoading(false);
          notifyListeners();
          return true;
        } else {
          _setError(result['error'] ?? '支付宝注册失败');
          _setLoading(false);
          return false;
        }
      } else {
        // 登录失败 - 处理不同的错误类型
        String errorMessage = loginResult['error'] ?? '支付宝登录失败';
        String? errorCode = loginResult['code'];

        // 根据错误代码提供更具体的错误信息
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

  // 直接从token设置认证状态（用于HTML页面登录同步）
  Future<void> setTokenDirectly(String token, String username) async {
    // Create a basic user model for the service layer
    final basicUserModel = UserModel(
      username: username,
      email: '',
      emailVerified: false,
      createdAt: DateTime.now().toIso8601String(),
      membership: MembershipInfo(type: 'expired', isActive: false),
    );

    // Update the AuthService singleton so subsequent API calls are authenticated.
    await _authService.setAuth(token, basicUserModel);

    // Update this AuthModel's state to match.
    _token = token;
    _currentUser = User(
      username: username,
      email: '', // Will be filled by refreshUserInfo
      membershipType: null,
      membershipExpiry: null,
      isAdmin: false,
    );

    // Store in AuthModel's storage (redundant but part of current design)
    await _storeAuth();

    // Notify UI to show "logged in" state immediately.
    notifyListeners();

    // In the background, fetch the full user details from the server.
    await refreshUserInfo();
  }

  // 使用token直接登录（用于macOS支付宝登录）
  Future<void> loginWithToken(String token, String username) async {
    try {
      debugPrint('使用token登录: username=$username');

      // 先设置 _token
      _token = token;

      // 创建基本用户模型
      final basicUserModel = UserModel(
        username: username,
        email: '',
        emailVerified: true,
        createdAt: DateTime.now().toIso8601String(),
        membership: MembershipInfo(type: 'trial', isActive: true),
      );

      // 设置token到AuthService
      await _authService.setAuth(token, basicUserModel);

      // 设置本地用户状态
      _currentUser = User(
        username: username,
        email: '',
        membershipType: 'trial',
        membershipExpiry: DateTime.now().add(const Duration(days: 3)),
        isAdmin: false,
      );

      // 立即保存并通知UI
      await _storeAuth();
      notifyListeners();

      debugPrint('✅ Token已设置，登录完成');
    } catch (e) {
      debugPrint('使用token登录失败: $e');
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

      // 清除存储的认证信息
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

  // 获取当前用户的认证token，用于API请求
  String? get authToken => _token;

  // 检查用户是否有权限执行某个操作
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    switch (permission) {
      case 'admin':
        return _currentUser!.isAdmin;
      case 'premium':
        return _currentUser!.hasPremiumMembership || _currentUser!.isAdmin;
      case 'basic':
        return true; // 所有登录用户都有基本权限
      default:
        return false;
    }
  }

  // 获取用户会员状态描述
  String getMembershipStatusText() {
    if (_currentUser == null) return '未登录';
    if (_currentUser!.isAdmin) return '管理员';
    if (_currentUser!.isPremiumMember) return '高级会员';
    if (_currentUser!.isTrialMember) return '试用会员';
    return '普通用户';
  }

  // 获取会员到期时间描述
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

  // 获取会员剩余天数
  int? getMembershipDaysRemaining() {
    if (_currentUser?.membershipExpiry == null) return null;

    final expiry = _currentUser!.membershipExpiry!;
    final now = DateTime.now();
    final difference = expiry.difference(now);

    if (difference.isNegative) return -1; // 已过期

    return difference.inDays;
  }
}
