import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import '../../features/auth/application/auth_model.dart';
import '../../screens/register_screen.dart';
import '../../screens/alipay_web_login_screen.dart';

class UnifiedLoginDialog extends StatefulWidget {
  const UnifiedLoginDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (_) => const UnifiedLoginDialog(),
    );
  }

  @override
  State<UnifiedLoginDialog> createState() => _UnifiedLoginDialogState();
}

class _UnifiedLoginDialogState extends State<UnifiedLoginDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final authModel = context.read<AuthModel>();
    final success = await authModel.login(username, password);
    if (!mounted) return;

    setState(() => _loading = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = authModel.error ?? '登录失败，请稍后重试');
    }
  }

  Future<void> _openAlipayLogin() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    String platformStr = 'app';
    if (kIsWeb) {
      platformStr = 'web';
    } else if (Platform.isMacOS) {
      platformStr = 'macos';
    } else if (Platform.isIOS) {
      platformStr = 'ios';
    } else if (Platform.isAndroid) {
      platformStr = 'android';
    }

    final result = await context.read<AuthModel>().getAlipayLoginUrl(
      platform: platformStr,
    );
    if (!mounted) return;

    final loginUrl = result['loginUrl'];
    if (result['success'] == true && loginUrl is String && loginUrl.isNotEmpty) {
      if (kIsWeb) {
        html.window.location.assign(loginUrl);
      } else {
        final callbackUrl = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => AlipayWebLoginScreen(loginUrl: loginUrl),
            fullscreenDialog: true,
          ),
        );
        
        if (!mounted) return;
        
        if (callbackUrl != null && callbackUrl.isNotEmpty) {
          final uri = Uri.tryParse(callbackUrl);
          if (uri != null) {
            final authCode = uri.queryParameters['auth_code'] ?? uri.queryParameters['alipay_auth_code'];
            
            if (authCode != null && authCode.isNotEmpty) {
              final authModel = context.read<AuthModel>();
              final loginSuccess = await authModel.alipayLogin(authCode);
              
              if (!mounted) return;
              setState(() {
                _loading = false;
                if (loginSuccess) {
                  Navigator.of(context).pop(true);
                } else {
                  _error = authModel.error ?? '支付宝登录失败';
                }
              });
              return;
            }
          }
        }
        
        // If we reach here, either user cancelled or parsing failed
        setState(() {
          _loading = false;
          // _error = '已取消支付宝登录'; // optional, or just do nothing
        });
        return;
      }
      return;
    }

    setState(() {
      _loading = false;
      _error = result['message'] as String? ??
          result['error'] as String? ??
          '获取支付宝登录链接失败';
    });
  }

  void _navigateToRegister() {
    Navigator.of(context).pop(); // Close dialog first
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 32,
        vertical: 32,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 24 : 30,
            28,
            compact ? 24 : 30,
            24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF21C242F), // Telegram-like dark blue/grey
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.44),
                blurRadius: 42,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _AppMark(),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '登录大乘',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Colors.white54),
                      splashRadius: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _DarkInput(
                  controller: _usernameController,
                  hint: '请输入账号或邮箱',
                  prefix: Icons.person_outline,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 16),
                _DarkInput(
                  controller: _passwordController,
                  hint: '请输入密码',
                  prefix: Icons.lock_outline,
                  obscureText: _obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                      size: 19,
                    ),
                    splashRadius: 20,
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF40A7E3), // Telegram blue
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _loading ? null : _openAlipayLogin,
                  icon: const Icon(Icons.account_balance_wallet, size: 18),
                  label: const Text('使用支付宝快捷登录'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '还没账号？',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: _navigateToRegister,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF40A7E3),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('立即注册'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkInput extends StatelessWidget {
  const _DarkInput({
    required this.controller,
    required this.hint,
    required this.prefix,
    this.suffix,
    this.obscureText = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  final Widget? suffix;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.2), // Telegram input style
          prefixIcon: Icon(prefix, color: Colors.white38, size: 20),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF40A7E3)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF40A7E3), Color(0xFF2A83BA)],
        ),
      ),
      child: const Text(
        '大',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    );
  }
}
