import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/application/auth_model.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  bool _profileMenuOpen = false;

  Future<void> _openLogin() async {
    await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => const _WebLoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel?>();
    final user = authModel?.currentUser;
    final displayName = user?.displayName.trim();
    final name = displayName == null || displayName.isEmpty ? '朋友' : displayName;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final sideWidth = compact ? 0.0 : 268.0;

          return Stack(
            children: [
              const Positioned.fill(child: _LingguangBackdrop()),
              if (!compact)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: sideWidth,
                  child: _SideRail(
                    user: user,
                    profileMenuOpen: _profileMenuOpen,
                    onProfileTap: () => setState(() => _profileMenuOpen = !_profileMenuOpen),
                  ),
                ),
              Positioned(
                left: sideWidth,
                top: 0,
                right: 0,
                bottom: 0,
                child: _HomeShell(
                  name: name,
                  compact: compact,
                  user: user,
                  onLoginPressed: _openLogin,
                  onProfilePressed: compact
                      ? () => setState(() => _profileMenuOpen = !_profileMenuOpen)
                      : null,
                ),
              ),
              if (_profileMenuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _profileMenuOpen = false),
                    child: const SizedBox.expand(),
                  ),
                ),
              if (_profileMenuOpen)
                Positioned(
                  left: compact ? 20 : 24,
                  bottom: compact ? 76 : 92,
                  child: _ProfileMenu(
                    user: user,
                    onLogin: () {
                      setState(() => _profileMenuOpen = false);
                      unawaited(_openLogin());
                    },
                    onLogout: () {
                      setState(() => _profileMenuOpen = false);
                      unawaited(authModel?.logout());
                    },
                  ),
                ),
              if (compact)
                Positioned(
                  left: 18,
                  bottom: 18,
                  child: _AvatarButton(
                    user: user,
                    onTap: () => setState(() => _profileMenuOpen = !_profileMenuOpen),
                    selected: _profileMenuOpen,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({
    required this.name,
    required this.compact,
    required this.user,
    required this.onLoginPressed,
    this.onProfilePressed,
  });

  final String name;
  final bool compact;
  final User? user;
  final VoidCallback onLoginPressed;
  final VoidCallback? onProfilePressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            right: compact ? 18 : 26,
            top: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _DownloadButton(),
                const SizedBox(width: 14),
                if (user == null)
                  _TopLoginButton(onPressed: onLoginPressed)
                else if (compact && onProfilePressed != null)
                  _AvatarButton(user: user, onTap: onProfilePressed!),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 24 : 60,
                  compact ? 80 : 32,
                  compact ? 24 : 60,
                  150,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi,$name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 36 : 44,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '灵光，让复杂变简单',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Wrap(
                      spacing: 12,
                      runSpacing: 14,
                      children: const [
                        _PromptChip(icon: Icons.auto_awesome, label: '你是谁'),
                        _PromptChip(icon: Icons.eco, label: '人生新手村通关闪应用'),
                        _PromptChip(icon: Icons.sports_esports, label: '搓个小游戏'),
                        _PromptChip(icon: Icons.landscape, label: '朋友圈生图灵感'),
                        _PromptChip(icon: Icons.lightbulb, label: '原来是这样'),
                        _PromptChip(icon: Icons.waving_hand, label: '我今天灵光吗?'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 22 : 214,
            right: compact ? 22 : 214,
            bottom: 48,
            child: const _AskBox(),
          ),
          const Positioned(
            right: 24,
            bottom: 190,
            child: _FloatingTools(),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.user,
    required this.profileMenuOpen,
    required this.onProfileTap,
  });

  final User? user;
  final bool profileMenuOpen;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE51D2027),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  _AppMark(size: 34),
                  SizedBox(width: 10),
                  Text(
                    '灵光',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _RailItem(icon: Icons.chat_bubble_outline, label: '新对话', selected: true),
              const _RailItem(icon: Icons.bookmark_outline, label: '我的收藏'),
              const _RailItem(icon: Icons.rocket_launch_outlined, label: '我的创作'),
              const SizedBox(height: 28),
              _RailSectionTitle('近期对话'),
              const _RailItem(icon: Icons.notes, label: '经营菜市场游戏', dense: true),
              const _RailItem(icon: Icons.notes, label: '日常问候', dense: true),
              const SizedBox(height: 12),
              _RailSectionTitle('更多对话'),
              const _RailItem(icon: Icons.notes, label: '制作浪漫烟花互动应用', dense: true),
              const Spacer(),
              const _RailItem(icon: Icons.add_circle_outline, label: '创建闪应用'),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onProfileTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: profileMenuOpen ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _AvatarButton(user: user, onTap: onProfileTap, selected: profileMenuOpen, small: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user == null ? '登录' : user!.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.icon, required this.label, this.selected = false, this.dense = false});

  final IconData icon;
  final String label;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: dense ? 4 : 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 9 : 12),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? Colors.white : Colors.white70, size: dense ? 18 : 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: dense ? 14 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailSectionTitle extends StatelessWidget {
  const _RailSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xCC282C34),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9CC2FF), size: 19),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AskBox extends StatelessWidget {
  const _AskBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xF22B2E38),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('问一问灵光', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            children: [
              _RoundIconButton(icon: Icons.add, onPressed: () {}),
              const Spacer(),
              _RoundIconButton(icon: Icons.near_me, filled: true, onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_iphone, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Text('下载灵光手机应用', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, color: Colors.white70),
        ],
      ),
    );
  }
}

class _TopLoginButton extends StatelessWidget {
  const _TopLoginButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        fixedSize: const Size(84, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: const Text('登录', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _FloatingTools extends StatelessWidget {
  const _FloatingTools();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ToolBubble(icon: Icons.grid_view_rounded),
        SizedBox(height: 12),
        _ToolBubble(icon: Icons.translate_rounded),
      ],
    );
  }
}

class _ToolBubble extends StatelessWidget {
  const _ToolBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF7A3C4),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 12)],
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed, this.filled = false});

  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 24,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.user, required this.onLogin, required this.onLogout});

  final User? user;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 310,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xF224272F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileHeader(user: user),
            const Divider(color: Colors.white12, height: 18),
            const _MenuItem(icon: Icons.person_outline, label: '个人信息'),
            const _MenuItem(icon: Icons.dark_mode_outlined, label: '主题设置', trailing: '深色主题'),
            const _MenuItem(icon: Icons.tune_outlined, label: '个性化'),
            const _MenuItem(icon: Icons.manage_accounts_outlined, label: '账号设置'),
            const Divider(color: Colors.white12, height: 18),
            const _MenuItem(icon: Icons.help_outline, label: '帮助与反馈'),
            const _MenuItem(icon: Icons.info_outline, label: '关于灵光'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: user == null ? onLogin : onLogout,
                child: Text(user == null ? '登录' : '退出登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AvatarButton(user: user, onTap: () {}, small: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? '未登录',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                user == null ? '点击登录同步你的灵感' : '账号信息已同步',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 21),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          if (trailing != null) Text(trailing!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.user, required this.onTap, this.selected = false, this.small = false});

  final User? user;
  final VoidCallback onTap;
  final bool selected;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatar;
    final name = user?.displayName ?? '灵';
    final initial = name.isEmpty ? '灵' : name.characters.first;
    final size = small ? 36.0 : 46.0;

    return InkResponse(
      onTap: onTap,
      radius: size / 2 + 6,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? const Color(0xFF8BB9FF) : Colors.white.withValues(alpha: 0.28), width: 2),
        ),
        child: ClipOval(
          child: avatar != null && avatar.isNotEmpty
              ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _AvatarFallback(initial: initial))
              : _AvatarFallback(initial: initial),
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
      color: const Color(0xFF587CFF),
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

class _WebLoginDialog extends StatelessWidget {
  const _WebLoginDialog();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: compact ? 18 : 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 560),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF20A0B0F),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF526991)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 42)],
          ),
          child: Row(
            children: [
              if (!compact)
                const Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
                    child: _LoginArtwork(),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(child: _LoginShadow()),
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 34),
                        child: _LoginForm(compact: compact),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.compact});

  final bool compact;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _agreed = false;
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
    if (!_agreed) {
      setState(() => _error = '请先阅读并同意服务协议和隐私政策');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
      );
    } else {
      setState(() => _error = authModel.error ?? '登录失败，请稍后重试');
    }
  }

  void _openFullLogin() {
    Navigator.of(context).pop();
    unawaited(Navigator.of(context).pushNamed('/login'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _AppMark(size: 58),
        const SizedBox(height: 24),
        _DarkInput(
          controller: _usernameController,
          hint: '请输入账号',
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
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 19),
          ),
          onSubmitted: (_) => _login(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _loading ? null : _login,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('下一步', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 24),
        InkResponse(
          onTap: _openFullLogin,
          radius: 24,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              color: Colors.white.withValues(alpha: 0.03),
            ),
            child: const Text('支', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              visualDensity: VisualDensity.compact,
              side: const BorderSide(color: Colors.white38),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text.rich(
                  TextSpan(
                    text: '我已阅读并同意 灵光 的 ',
                    children: [
                      TextSpan(text: '服务协议', style: TextStyle(color: Color(0xFF5FA8FF))),
                      TextSpan(text: ' 和 '),
                      TextSpan(text: '隐私政策', style: TextStyle(color: Color(0xFF5FA8FF))),
                    ],
                  ),
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ],
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
    return Container(
      height: 54,
      decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(27)),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(prefix, color: Colors.white38),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111D48), Color(0xFF4FA5FF), Color(0xFFB8F0FF)],
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF55B6FF).withValues(alpha: 0.35), blurRadius: size * 0.28)],
      ),
      alignment: Alignment.center,
      child: Text(
        '灵',
        style: TextStyle(color: Colors.white, fontSize: size * 0.46, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LoginArtwork extends StatelessWidget {
  const _LoginArtwork();

  @override
  Widget build(BuildContext context) {
    return const _LingguangBackdrop(dimmed: false);
  }
}

class _LoginShadow extends StatelessWidget {
  const _LoginShadow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.black.withValues(alpha: 0.52), Colors.black.withValues(alpha: 0.9)],
        ),
      ),
    );
  }
}

class _LingguangBackdrop extends StatelessWidget {
  const _LingguangBackdrop({this.dimmed = true});

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A425C), Color(0xFF111318), Color(0xFF08090D)],
            ),
          ),
        ),
        CustomPaint(painter: _PlanetPainter()),
        CustomPaint(painter: _MountainPainter()),
        if (dimmed) Container(color: Colors.black.withValues(alpha: 0.42)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.3, -0.35),
              radius: 0.9,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final glowPaint = Paint()
      ..color = const Color(0xFFE7D6A3).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final center = Offset(size.width * 0.42, size.height * 0.2);
    final rect = Rect.fromCenter(center: center, width: size.width * 0.32, height: size.width * 0.32);
    canvas.drawArc(rect, -0.15, 4.6, false, glowPaint);
    canvas.drawArc(rect, -0.15, 4.6, false, ringPaint);

    final ringRect = Rect.fromCenter(center: center, width: size.width * 0.48, height: size.width * 0.12);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.34);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(ringRect, 3.35, 2.45, false, ringPaint..strokeWidth = 1.4);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final far = Paint()..color = const Color(0xFF39465C).withValues(alpha: 0.7);
    final mid = Paint()..color = const Color(0xFF213022).withValues(alpha: 0.92);
    final near = Paint()..color = const Color(0xFF0D1110).withValues(alpha: 0.9);
    final snow = Paint()..color = Colors.white.withValues(alpha: 0.68);

    final peak = Path()
      ..moveTo(0, size.height * 0.64)
      ..lineTo(size.width * 0.26, size.height * 0.46)
      ..lineTo(size.width * 0.43, size.height * 0.56)
      ..lineTo(size.width * 0.58, size.height * 0.34)
      ..lineTo(size.width * 0.78, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.38)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(peak, far);

    final snowPath = Path()
      ..moveTo(size.width * 0.54, size.height * 0.4)
      ..lineTo(size.width * 0.58, size.height * 0.34)
      ..lineTo(size.width * 0.63, size.height * 0.43)
      ..lineTo(size.width * 0.59, size.height * 0.41)
      ..lineTo(size.width * 0.56, size.height * 0.47)
      ..close();
    canvas.drawPath(snowPath, snow);

    final forest = Path()
      ..moveTo(0, size.height * 0.74)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.6, size.width * 0.5, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.62)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(forest, mid);

    final foreground = Path()
      ..moveTo(0, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.78, size.width * 0.48, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.74, size.height * 0.94, size.width, size.height * 0.78)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(foreground, near);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
