import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class User {
  final String username;
  final String email;
  final String? membershipType;
  final DateTime? membershipExpiry;
  final bool isAdmin;

  User({
    required this.username,
    required this.email,
    this.membershipType,
    this.membershipExpiry,
    this.isAdmin = false,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'membershipType': membershipType,
      'membershipExpiry': membershipExpiry?.toIso8601String(),
      'isAdmin': isAdmin,
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
    return membershipType == 'premium' && hasPremiumMembership;
  }
}

class AuthModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
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
    _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('user_data');
      
      if (token != null && userJson != null) {
        _token = token;
        _currentUser = User.fromJson(Map<String, dynamic>.from(
          await _parseJson(userJson)
        ));
        
        // 验证token是否仍然有效
        final isValid = await _authService.verifyToken();
        if (!isValid) {
          await logout();
        } else {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('加载存储的认证信息失败: $e');
    }
  }

  Future<Map<String, dynamic>> _parseJson(String jsonString) async {
    // 在Web平台上直接解析，在其他平台上可能需要异步处理
    if (kIsWeb) {
      return Map<String, dynamic>.from(
        Uri.splitQueryString(jsonString)
      );
    }
    return Map<String, dynamic>.from(
      Uri.splitQueryString(jsonString)
    );
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.login(username, password);
      
      if (result['success'] == true) {
        _token = result['token'];
        _currentUser = User.fromJson(result['user']);
        
        // 存储认证信息
        await _storeAuth();
        
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(result['message'] ?? '登录失败');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('登录时发生错误: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(String username, String email, String password, String verificationCode) async {
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
      final result = await _authService.verifyToken();
      if (result) {
        // 刷新用户信息
        await _authService.refreshUserInfo();
        if (_authService.currentUser != null) {
          final userModel = _authService.currentUser!;
          _currentUser = User(
            username: userModel.username,
            email: userModel.email ?? '',
            membershipType: userModel.membership.type,
            membershipExpiry: userModel.membership.expiresAt != null 
                ? DateTime.parse(userModel.membership.expiresAt!)
                : null,
            isAdmin: false, // UserModel中没有isAdmin字段，默认为false
          );
          await _storeAuth();
          notifyListeners();
        }
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('刷新用户信息失败: $e');
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
      await prefs.setString('user_data', _currentUser!.toJson().toString());
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
}