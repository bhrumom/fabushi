import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../../core/design_system/app_theme.dart';
import '../../application/auth_model.dart';

/// Flutter Web 专用登录页。
///
/// 只依赖 Web 可用 API，避免复用 App 登录页时把 dart:io、Apple 登录、
/// 移动端支付宝 SDK / WebView 等原生依赖带进 Web 登录链路。
class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _canPasswordLogin =>
      _accountController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _agreedToTerms &&
      !_isLoading;

  bool get _canOAuthLogin => _agreedToTerms && !_isLoading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleIncomingAlipayCallback();
    });
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _passwordLogin() async {
    if (!_canPasswordLogin) return;

    final authModel = context.read<AuthModel>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await authModel.login(
      _accountController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSnackBar('登录成功', isError: false);
      _finishLogin();
    } else {
      setState(() => _errorMessage = authModel.error ?? '登录失败，请检查账号或密码');
    }
  }

  Future<void> _startAlipayLogin() async {
    if (!_agreedToTerms) {
      setState(() => _errorMessage = '请先阅读并同意用户协议和隐私政策');
      return;
    }
    if (_isLoading) return;

    final authModel = context.read<AuthModel>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await authModel.getAlipayLoginUrl(platform: 'web');
    if (!mounted) return;

    if (result['success'] == true && result['loginUrl'] != null) {
      html.window.location.assign(result['loginUrl'] as String);
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage =
          result['message'] as String? ?? result['error'] as String? ?? '获取支付宝登录链接失败';
    });
  }

  Future<void> _handleIncomingAlipayCallback() async {
    final params = _collectCurrentUrlParams();
    if (params.isEmpty) return;

    final error = params['error'] ?? params['error_message'];
    if (error != null && error.isNotEmpty) {
      _clearAuthParamsFromAddressBar();
      setState(() => _errorMessage = '支付宝登录失败：$error');
      return;
    }

    final token = params['token'];
    final username = params['username'];
    final authCode =
        params['alipay_auth_code'] ?? params['auth_code'] ?? params['authCode'];
    final alipayUserId = params['alipay_user_id'] ?? params['alipayUserId'];
    final nickname = params['alipay_nickname'] ?? params['nickname'];
    final avatar = params['alipay_avatar'] ?? params['avatar'];

    if ((token == null || username == null) &&
        authCode == null &&
        alipayUserId == null) {
      return;
    }

    final authModel = context.read<AuthModel>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    var success = false;
    try {
      if (token != null && username != null) {
        await authModel.loginWithToken(token, username);
        success = authModel.isLoggedIn;
      } else if (authCode != null) {
        success = await authModel.alipayLogin(authCode);
        if (!success && alipayUserId != null) {
          success = await authModel.alipayOneClickRegister(
            alipayUserId,
            nickname,
            avatar,
          );
        }
      } else if (alipayUserId != null) {
        success = await authModel.alipayOneClickRegister(
          alipayUserId,
          nickname,
          avatar,
        );
      }
    } catch (e) {
      setState(() => _errorMessage = '处理支付宝回调失败：$e');
    } finally {
      _clearAuthParamsFromAddressBar();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSnackBar('支付宝登录成功', isError: false);
      _finishLogin();
    } else {
      setState(() => _errorMessage = authModel.error ?? '支付宝登录失败，请重试');
    }
  }

  Map<String, String> _collectCurrentUrlParams() {
    final params = <String, String>{};
    final uri = Uri.base;
    params.addAll(uri.queryParameters);

    final fragment = uri.fragment.replaceAll('&amp;', '&');
    if (fragment.isNotEmpty) {
      final queryStart = fragment.indexOf('?');
      final query = queryStart >= 0 ? fragment.substring(queryStart + 1) : fragment;
      if (query.contains('=')) {
        params.addAll(Uri.splitQueryString(query));
      }
    }

    return params;
  }

  void _clearAuthParamsFromAddressBar() {
    try {
      final path = html.window.location.pathname ?? '/';
      final hash = html.window.location.hash ?? '';
      final cleanHash = hash.contains('?') ? hash.substring(0, hash.indexOf('?')) : hash;
      final cleanUrl = cleanHash.isNotEmpty ? '$path$cleanHash' : path;
      html.window.history.replaceState(null, '', cleanUrl);
    } catch (_) {
      // 清理地址栏失败不影响登录状态。
    }
  }

  void _finishLogin() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    } else {
      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08060A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF121016),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _accountController,
                      hintText: '用户名或邮箱',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: '密码',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _passwordLogin(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildAgreement(),
                    const SizedBox(height: 24),
                    _buildPrimaryButton(),
                    const SizedBox(height: 22),
                    _buildDivider(),
                    const SizedBox(height: 18),
                    _buildAlipayButton(),
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
                      child: Text(
                        '以游客身份继续',
                        style: TextStyle(color: Colors.white.withOpacity(0.55)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Center(child: Text('🙏', style: TextStyle(fontSize: 36))),
        ),
        const SizedBox(height: 20),
        const Text(
          '登录大乘',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Flutter Web 原生登录',
          style: TextStyle(color: Colors.white.withOpacity(0.58), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1E1A24),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _buildAgreement() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: _agreedToTerms ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _agreedToTerms
                      ? AppTheme.primaryColor
                      : Colors.white.withOpacity(0.35),
                ),
              ),
              child: _agreedToTerms
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '我已阅读并同意《用户协议》和《隐私政策》',
                style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _canPasswordLogin ? _passwordLogin : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: const Color(0xFF332E38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                '账号密码登录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.14))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '或',
            style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.14))),
      ],
    );
  }

  Widget _buildAlipayButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _canOAuthLogin ? _startAlipayLogin : null,
        icon: const Text('💰', style: TextStyle(fontSize: 20)),
        label: const Text(
          '支付宝登录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
