import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../models/auth_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_rest_auth_service.dart';
import '../services/platform_service.dart';
import '../core/design_system/app_theme.dart';
import '../widgets/recaptcha_dialog.dart';

/// 统一登录页面 - 支持手机号验证码登录和账号密码登录
class DouyinLoginScreen extends StatefulWidget {
  const DouyinLoginScreen({super.key});

  @override
  State<DouyinLoginScreen> createState() => _DouyinLoginScreenState();
}

class _DouyinLoginScreenState extends State<DouyinLoginScreen>
    with SingleTickerProviderStateMixin {
  // 手机号登录相关
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _firebaseAuth = FirebaseAuthService();
  final _firebaseRestAuth = FirebaseRestAuthService();

  // 账号密码登录相关
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // 登录模式：false = 手机号登录, true = 账号密码登录
  bool _isPasswordMode = false;

  bool _isLoading = false;
  bool _codeSent = false;
  bool _agreedToTerms = false;
  int _countdown = 0;
  Timer? _timer;
  String? _errorMessage;

  late AnimationController _buttonAnimController;
  late Animation<double> _buttonGlow;

  // 支付宝回调相关
  StreamSubscription? _urlSubscription;
  final PlatformService _platformService = PlatformServiceFactory.create();

  // 检测是否为桌面平台
  bool get _isDesktop {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.linux);
  }

  @override
  void initState() {
    super.initState();
    _buttonAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _buttonGlow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeInOut),
    );

    // 监听URL变化，用于处理支付宝登录回调
    if (kIsWeb) {
      _platformService.listenToMessages((event) {
        final data = event.data;
        if (data is Map && data.containsKey('alipay_auth_code')) {
          _handleAlipayCallback(data['alipay_auth_code']);
        }
      });
    } else {
      // macOS平台监听原生回调
      _platformService.listenToMessages((url) {
        if (url is String) {
          _handleMacOSAlipayCallback(url);
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _timer?.cancel();
    _buttonAnimController.dispose();
    _urlSubscription?.cancel();
    _platformService.dispose();
    super.dispose();
  }

  bool get _canSendCode =>
      _phoneController.text.length >= 11 && _countdown == 0 && !_isLoading;

  bool get _canPhoneLogin =>
      _codeSent &&
      _codeController.text.length == 6 &&
      _agreedToTerms &&
      !_isLoading;

  bool get _canPasswordLogin =>
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _agreedToTerms &&
      !_isLoading;

  String _formatPhoneNumber(String phone) {
    // 给中国手机号加上+86前缀
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('86')) return '+$phone';
    return '+86$phone';
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // ==================== 手机号登录逻辑 ====================

  Future<void> _sendVerificationCode() async {
    if (!_canSendCode) return;

    final phone = _formatPhoneNumber(_phoneController.text.trim());
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isDesktop) {
        // 桌面平台: 使用WebView加载Firebase验证页面
        final result = await RecaptchaDialog.show(context, phoneNumber: phone);
        
        if (result == null || result['success'] != true) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = result?['error'] ?? '验证已取消';
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _codeSent = true;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('验证码已发送'), backgroundColor: Colors.green),
          );
        }
      } else {
        // 移动端/Web: 使用Firebase SDK
        final result = await _firebaseAuth.verifyPhoneNumber(phone);
        if (mounted) {
          setState(() => _isLoading = false);
          if (result['success'] == true) {
            if (result['autoVerified'] == true) {
              _handleFirebaseLoginSuccess(result);
            } else {
              setState(() => _codeSent = true);
              _startCountdown();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('验证码已发送'), backgroundColor: Colors.green),
              );
            }
          } else {
            setState(() => _errorMessage = result['error']);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '发送验证码失败: $e';
        });
      }
    }
  }

  Future<void> _phoneLogin() async {
    if (!_canPhoneLogin) return;

    final phone = _formatPhoneNumber(_phoneController.text.trim());
    final code = _codeController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isDesktop) {
        final result = await _firebaseRestAuth.signInWithPhoneNumber(code: code);
        if (mounted) {
          if (result['success'] == true) {
            await _handleFirebaseRestLoginSuccess(result, phone);
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = result['error'] ?? '登录失败';
            });
          }
        }
      } else {
        final result = await _firebaseAuth.signInWithPhoneCredential(code);
        if (mounted) {
          if (result['success'] == true) {
            await _handleFirebaseLoginSuccess(result);
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = result['error'];
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '登录失败: $e';
        });
      }
    }
  }

  Future<void> _handleFirebaseLoginSuccess(Map<String, dynamic> result) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final idToken = await _firebaseAuth.getIdToken();

    if (idToken != null) {
      final syncResult = await authModel.firebasePhoneLogin(
        idToken: idToken,
        phoneNumber: result['phoneNumber'] ?? '',
        firebaseUid: result['firebaseUid'] ?? '',
        isNewUser: result['isNewUser'] ?? false,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (syncResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true);
        } else {
          setState(() => _errorMessage = authModel.error ?? '登录失败');
        }
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '获取认证信息失败';
      });
    }
  }

  Future<void> _handleFirebaseRestLoginSuccess(Map<String, dynamic> result, String phone) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    
    final idToken = result['idToken'];
    final firebaseUid = result['localId'] ?? '';
    final isNewUser = result['isNewUser'] ?? false;

    if (idToken != null) {
      final syncResult = await authModel.firebasePhoneLogin(
        idToken: idToken,
        phoneNumber: phone,
        firebaseUid: firebaseUid,
        isNewUser: isNewUser,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (syncResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true);
        } else {
          setState(() => _errorMessage = authModel.error ?? '登录失败');
        }
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '登录失败：无效的响应';
      });
    }
  }

  // ==================== 账号密码登录逻辑 ====================

  Future<void> _passwordLogin() async {
    if (!_canPasswordLogin) return;

    final authModel = Provider.of<AuthModel>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await authModel.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = authModel.error ?? '登录失败');
      }
    }
  }

  // ==================== 支付宝登录逻辑 ====================

  Future<void> _handleAlipayLogin() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? platform;
      if (!kIsWeb && Platform.isMacOS) {
        platform = 'macos';
      }

      final result = await authModel.getAlipayLoginUrl(platform: platform);

      if (result['success'] == true && result['loginUrl'] != null) {
        final loginUrl = result['loginUrl'] as String;

        final uri = Uri.parse(loginUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (kIsWeb) {
          _platformService.openUrl(loginUrl, '_self');
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = result['error'] ?? '获取支付宝登录链接失败';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '支付宝登录出错: $e';
        });
      }
    }
  }

  Future<void> _handleAlipayCallback(Map<String, dynamic> params) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      final alipayUserId = params['alipay_user_id'] as String?;
      final alipayNickname = params['alipay_nickname'] as String?;
      final alipayAvatar = params['alipay_avatar'] as String?;
      final authCode = params['alipay_auth_code'] as String?;

      final success = await authModel.alipayOneClickRegister(
        alipayUserId ?? authCode ?? '',
        alipayNickname,
        alipayAvatar,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付宝登录成功！'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('支付宝登录错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('支付宝登录失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleMacOSAlipayCallback(String url) async {
    debugPrint('收到macOS支付宝回调: $url');

    try {
      String decodedUrl = url.replaceAll('&amp;', '&');
      Map<String, String> params = {};

      String urlWithoutScheme = decodedUrl
          .replaceFirst('com.ombhrum.fabushi://', '')
          .replaceFirst('globaldharma://', '');

      final queryParams = urlWithoutScheme.split('&');
      for (final param in queryParams) {
        if (param.contains('=')) {
          final keyValue = param.split('=');
          if (keyValue.length == 2) {
            params[keyValue[0]] = Uri.decodeComponent(keyValue[1]);
          }
        }
      }

      if (params.containsKey('error')) {
        final errorMessage = params['error_message'] ?? '支付宝登录失败';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('支付宝登录失败: $errorMessage'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (params.containsKey('alipay_auth_code')) {
        final authCode = params['alipay_auth_code']!;
        final alipayUserId = params['alipay_user_id'];
        final alipayNickname = params['alipay_nickname'];
        final alipayAvatar = params['alipay_avatar'];
        final isNewUser = params['isNewUser'] == 'true';
        final token = params['token'];
        final username = params['username'];

        final authModel = Provider.of<AuthModel>(context, listen: false);
        bool success = false;

        if (!isNewUser && token != null && username != null) {
          try {
            await authModel.loginWithToken(token, username);
            success = true;
          } catch (e) {
            debugPrint('使用token登录失败: $e');
            success = false;
          }
        } else {
          success = await authModel.alipayOneClickRegister(
            alipayUserId ?? authCode,
            alipayNickname,
            alipayAvatar,
          );
        }

        if (success && mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('支付宝登录成功！欢迎 ${authModel.currentUser?.username}'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          final error = authModel.error ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.isNotEmpty ? error : '支付宝登录失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('处理macOS支付宝回调失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理支付宝回调失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==================== 切换登录模式 ====================

  void _toggleLoginMode() {
    setState(() {
      _isPasswordMode = !_isPasswordMode;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo和标题
              _buildHeader(),
              const SizedBox(height: 60),
              // 根据模式显示不同的输入区域
              if (_isPasswordMode) ...[
                _buildUsernameInput(),
                const SizedBox(height: 16),
                _buildPasswordInput(),
              ] else ...[
                _buildPhoneInput(),
                const SizedBox(height: 16),
                _buildCodeInput(),
              ],
              // 错误信息
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              // 登录按钮
              _buildLoginButton(),
              const SizedBox(height: 20),
              // 用户协议
              _buildAgreement(),
              const SizedBox(height: 40),
              // 其他登录方式
              _buildOtherLoginMethods(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // 应用Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🙏',
              style: TextStyle(fontSize: 40),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '全球法布施',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        // 动态标题
        Text(
          _isPasswordMode ? '账号密码登录' : '手机号快捷登录',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // 国家码
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white12),
              ),
            ),
            child: const Row(
              children: [
                Text('🇨🇳', style: TextStyle(fontSize: 18)),
                SizedBox(width: 4),
                Text(
                  '+86',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.white54, size: 20),
              ],
            ),
          ),
          // 手机号输入
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                hintText: '请输入手机号',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // 验证码输入
          Expanded(
            child: TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                hintText: '请输入验证码',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // 获取验证码按钮
          GestureDetector(
            onTap: _canSendCode ? _sendVerificationCode : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _canSendCode
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _countdown > 0 ? '${_countdown}s' : '获取验证码',
                style: TextStyle(
                  color: _canSendCode ? AppTheme.primaryColor : Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: _usernameController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: '请输入用户名或邮箱',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.person_outline, color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: '请输入密码',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _canPasswordLogin ? _passwordLogin() : null,
      ),
    );
  }

  Widget _buildLoginButton() {
    final canLogin = _isPasswordMode ? _canPasswordLogin : _canPhoneLogin;
    final onLogin = _isPasswordMode ? _passwordLogin : _phoneLogin;

    return AnimatedBuilder(
      animation: _buttonGlow,
      builder: (context, child) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: canLogin
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B).withOpacity(_buttonGlow.value),
                      const Color(0xFFFFE66D).withOpacity(_buttonGlow.value),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: canLogin ? null : const Color(0xFF333333),
            borderRadius: BorderRadius.circular(26),
            boxShadow: canLogin
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B)
                          .withOpacity(0.3 * _buttonGlow.value),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: canLogin ? onLogin : null,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isPasswordMode ? '🔐 登录' : '✨ 一键登录 ✨',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgreement() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _agreedToTerms ? AppTheme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _agreedToTerms ? AppTheme.primaryColor : Colors.white38,
              ),
            ),
            child: _agreedToTerms
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            children: [
              Text(
                '我已阅读并同意',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: 打开用户协议
                },
                child: const Text(
                  '《用户协议》',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                ),
              ),
              Text(
                '和',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: 打开隐私政策
                },
                child: const Text(
                  '《隐私政策》',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherLoginMethods() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '其他登录方式',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 支付宝登录 - 直接执行登录逻辑
            _buildOtherLoginButton(
              icon: '💰',
              label: '支付宝',
              onTap: _handleAlipayLogin,
            ),
            const SizedBox(width: 40),
            // 切换登录模式
            _buildOtherLoginButton(
              icon: _isPasswordMode ? '📱' : '🔐',
              label: _isPasswordMode ? '手机号登录' : '账号密码',
              onTap: _toggleLoginMode,
            ),
          ],
        ),
        const SizedBox(height: 32),
        // 游客模式
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            '以游客身份继续',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherLoginButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
