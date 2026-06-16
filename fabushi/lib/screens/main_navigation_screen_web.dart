import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../features/auth/application/auth_model.dart';
import 'globe_home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  bool _profileMenuOpen = false;

  Future<void> _openLogin() async {
    final success = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (_) => const _WebLoginDialog(),
    );

    if (!mounted || success != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
    );
  }

  void _toggleProfileMenu() {
    setState(() => _profileMenuOpen = !_profileMenuOpen);
  }

  void _closeProfileMenu() {
    if (!_profileMenuOpen) return;
    setState(() => _profileMenuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel?>();
    final user = authModel?.currentUser;
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Stack(
      children: [
        Positioned.fill(
          child: GlobeHomeScreen(
            topBarTrailing: _TopLoginButton(
              label: user == null ? '登录' : user.displayName,
              onPressed: user == null ? _openLogin : _toggleProfileMenu,
            ),
            composerLeftInset: compact ? 84 : 88,
          ),
        ),
        if (_profileMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeProfileMenu,
              child: const SizedBox.expand(),
            ),
          ),
        if (_profileMenuOpen)
          Positioned(
            left: 18,
            bottom: compact ? 84 : 88,
            child: SafeArea(
              top: false,
              right: false,
              child: _ProfileMenu(
                user: user,
                onLogin: () {
                  _closeProfileMenu();
                  unawaited(_openLogin());
                },
                onLogout: () {
                  _closeProfileMenu();
                  unawaited(authModel?.logout());
                },
              ),
            ),
          ),
        Positioned(
          left: 18,
          bottom: 16,
          child: SafeArea(
            top: false,
            right: false,
            child: _AvatarButton(
              user: user,
              selected: _profileMenuOpen,
              onTap: _toggleProfileMenu,
            ),
          ),
        ),
      ],
    );
  }
}

/// Web /login route wrapper.
///
/// It reuses the existing Web login dialog instead of loading the App login page.
class WebLoginRouteScreen extends StatefulWidget {
  const WebLoginRouteScreen({super.key});

  @override
  State<WebLoginRouteScreen> createState() => _WebLoginRouteScreenState();
}

class _WebLoginRouteScreenState extends State<WebLoginRouteScreen> {
  bool _dialogOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dialogOpened) return;
    _dialogOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_openLoginDialog());
      }
    });
  }

  Future<void> _openLoginDialog() async {
    final success = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (_) => const _WebLoginDialog(),
    );

    if (!mounted) return;
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
      );
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const MainNavigationScreen();
  }
}

class _TopLoginButton extends StatelessWidget {
  const _TopLoginButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 42,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF11151D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.user,
    required this.onTap,
    this.selected = false,
  });

  final User? user;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatar?.trim();
    final name = user?.displayName.trim() ?? '';
    final initial = name.isEmpty ? '大' : name.substring(0, 1);

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? const Color(0xFF78D6E8)
                  : Colors.white.withValues(alpha: 0.32),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child:
                avatar != null &&
                    (avatar.startsWith('http://') ||
                        avatar.startsWith('https://'))
                ? Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _AvatarFallback(initial: initial),
                  )
                : _AvatarFallback(initial: initial),
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15253A), Color(0xFF2A7C91)],
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.user,
    required this.onLogin,
    required this.onLogout,
  });

  final User? user;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 292,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xF21A2028),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _AvatarButton(user: user, onTap: () {}),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? '未登录',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user == null ? '登录后同步修行记录' : '账号信息已同步',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            _MenuItem(
              icon: Icons.manage_accounts_outlined,
              label: user == null ? '账号登录' : '账号设置',
            ),
            _MenuItem(
              icon: Icons.public_rounded,
              label: '全球法布施首页',
              trailing: 'Web',
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.09),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: user == null ? onLogin : onLogout,
              child: Text(user == null ? '登录' : '退出登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _WebLoginDialog extends StatefulWidget {
  const _WebLoginDialog();

  @override
  State<_WebLoginDialog> createState() => _WebLoginDialogState();
}

class _WebLoginDialogState extends State<_WebLoginDialog> {
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

    final result = await context.read<AuthModel>().getAlipayLoginUrl(
      platform: 'web',
    );
    if (!mounted) return;

    final loginUrl = result['loginUrl'];
    if (result['success'] == true && loginUrl is String && loginUrl.isNotEmpty) {
      html.window.location.assign(loginUrl);
      return;
    }

    setState(() {
      _loading = false;
      _error =
          result['message'] as String? ?? result['error'] as String? ?? '获取支付宝登录链接失败';
    });
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
            color: const Color(0xF20A0D12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.44),
                blurRadius: 42,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _AppMark(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '登录大乘',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DarkInput(
                controller: _usernameController,
                hint: '请输入账号',
                prefix: Icons.person_outline,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 14),
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
                ),
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF11151D),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '登录',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _loading ? null : _openAlipayLogin,
                child: const Text('使用支付宝登录'),
              ),
            ],
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
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          prefixIcon: Icon(prefix, color: Colors.white38),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF78D6E8)),
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
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15253A), Color(0xFF2A7C91)],
        ),
      ),
      child: const Text(
        '大',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}
