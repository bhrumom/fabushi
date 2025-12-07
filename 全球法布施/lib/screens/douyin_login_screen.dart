import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/auth_model.dart';
import '../services/firebase_auth_service.dart';
import '../core/design_system/app_theme.dart';
import 'login_screen.dart';

/// 抖音风格登录页面 - 手机号验证码登录为主入口
class DouyinLoginScreen extends StatefulWidget {
  const DouyinLoginScreen({super.key});

  @override
  State<DouyinLoginScreen> createState() => _DouyinLoginScreenState();
}

class _DouyinLoginScreenState extends State<DouyinLoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _firebaseAuth = FirebaseAuthService();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _agreedToTerms = false;
  int _countdown = 0;
  Timer? _timer;
  String? _errorMessage;

  late AnimationController _buttonAnimController;
  late Animation<double> _buttonGlow;

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
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    _buttonAnimController.dispose();
    super.dispose();
  }

  bool get _canSendCode =>
      _phoneController.text.length >= 11 && _countdown == 0 && !_isLoading;

  bool get _canLogin =>
      _codeSent &&
      _codeController.text.length == 6 &&
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

  Future<void> _sendVerificationCode() async {
    if (!_canSendCode) return;

    final phone = _formatPhoneNumber(_phoneController.text.trim());
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _firebaseAuth.verifyPhoneNumber(phone);

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        if (result['autoVerified'] == true) {
          // Android自动验证成功，直接登录
          _handleFirebaseLoginSuccess(result);
        } else {
          setState(() => _codeSent = true);
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('验证码已发送'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = result['error']);
      }
    }
  }

  Future<void> _login() async {
    if (!_canLogin) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _firebaseAuth.signInWithPhoneCredential(
      _codeController.text.trim(),
    );

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

  Future<void> _handleFirebaseLoginSuccess(Map<String, dynamic> result) async {
    // 同步到后端D1数据库
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
              // 手机号输入
              _buildPhoneInput(),
              const SizedBox(height: 16),
              // 验证码输入
              _buildCodeInput(),
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
        Text(
          '手机号快捷登录',
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

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: _buttonGlow,
      builder: (context, child) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: _canLogin
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B).withOpacity(_buttonGlow.value),
                      const Color(0xFFFFE66D).withOpacity(_buttonGlow.value),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: _canLogin ? null : const Color(0xFF333333),
            borderRadius: BorderRadius.circular(26),
            boxShadow: _canLogin
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
              onTap: _canLogin ? _login : null,
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
                    : const Text(
                        '✨ 一键登录 ✨',
                        style: TextStyle(
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
            // 支付宝登录
            _buildOtherLoginButton(
              icon: '💰',
              label: '支付宝',
              onTap: () {
                // 跳转到原登录页面使用支付宝登录
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(width: 40),
            // 账号密码登录
            _buildOtherLoginButton(
              icon: '🔐',
              label: '账号密码',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
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
