import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'globe_home_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import '../core/design_system/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/auth_model.dart';
import '../widgets/space_background.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isGlobeReady = false;

  // 追踪哪些页面已被激活
  final List<bool> _activatedScreens = [true, false, false];

  // 用于通知各主页面的可见性变化
  final GlobalKey<MeditationRoomScreenState> _meditationKey = GlobalKey();
  final GlobalKey<GlobeHomeScreenState> _globeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 立即加载，由 GlobeHomeScreen 内部控制延迟
    _isGlobeReady = true;
    _applyInitialTabFromUrl();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _applyInitialTabFromUrl() {
    final tab = Uri.base.queryParameters['tab']?.toLowerCase();
    final initialIndex = switch (tab) {
      'home' => 0,
      'meditation' || 'meditation-room' || 'zen' => 1,
      'profile' || 'me' || 'mine' => 2,
      _ => 0,
    };
    _currentIndex = initialIndex;
    _activatedScreens[initialIndex] = true;
  }

  /// 更新禅室页面可见性状态
  void _updateMeditationRoomVisibility() {
    final isZenRoomVisible = _currentIndex == 1 && _activatedScreens[1];
    // 使用 GlobalKey 通知禅室页面可见性变化
    _meditationKey.currentState?.setVisible(isZenRoomVisible);
  }

  /// 更新地球页面可见性状态
  void _updateGlobeVisibility() {
    final isGlobeVisible = _currentIndex == 0;
    _globeKey.currentState?.setVisible(isGlobeVisible);
  }

  void _notifyScreenVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateMeditationRoomVisibility();
      _updateGlobeVisibility();
    });
  }

  // 保持所有页面实例，按需延迟加载
  List<Widget> get _screens {
    final screens = <Widget>[];

    // 0: 首页 (地球)
    screens.add(
      TickerMode(
        enabled: _currentIndex == 0,
        child: _isGlobeReady
            ? GlobeHomeScreen(key: _globeKey)
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载地球组件...'),
                  ],
                ),
              ),
      ),
    );

    // 1: 禅室 (佛像3D)
    screens.add(
      TickerMode(
        enabled: _currentIndex == 1,
        child: _activatedScreens[1]
            ? MeditationRoomScreen(key: _meditationKey)
            : const Center(child: CircularProgressIndicator()),
      ),
    );

    // 2: 我的
    screens.add(
      TickerMode(
        enabled: _currentIndex == 2,
        child: _activatedScreens[2]
            ? const MyProfileScreen()
            : const Center(child: CircularProgressIndicator()),
      ),
    );

    return screens;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const _WebHomeShell();
    }

    final l10n = context.l10n;

    return SpaceBackground(
      child: Scaffold(
        key: const ValueKey('dacheng.main.scaffold'),
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              iconTheme: WidgetStateProperty.all(
                const IconThemeData(color: Colors.white),
              ),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(color: Colors.white),
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF), // Glass effect
              border: const Border(top: BorderSide(color: Color(0x26FFFFFF))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
              key: const ValueKey('dacheng.nav.bar'),
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                  // 标记页面为激活状态
                  if (!_activatedScreens[index]) {
                    _activatedScreens[index] = true;
                  }
                });
                _notifyScreenVisibility();
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 70,
              destinations: [
                NavigationDestination(
                  key: const ValueKey('dacheng.nav.home'),
                  icon: const Icon(Icons.public_outlined),
                  selectedIcon: const Icon(Icons.public),
                  label: l10n.navHome,
                ),
                NavigationDestination(
                  key: const ValueKey('dacheng.nav.zen'),
                  icon: const Icon(Icons.self_improvement_outlined),
                  selectedIcon: const Icon(Icons.self_improvement),
                  label: l10n.navMeditationRoom,
                ),
                NavigationDestination(
                  key: const ValueKey('dacheng.nav.profile'),
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: l10n.navProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebHomeShell extends StatefulWidget {
  const _WebHomeShell();

  @override
  State<_WebHomeShell> createState() => _WebHomeShellState();
}

class _WebHomeShellState extends State<_WebHomeShell> {
  bool _profileMenuOpen = false;

  void _toggleProfileMenu() {
    setState(() => _profileMenuOpen = !_profileMenuOpen);
  }

  void _closeProfileMenu() {
    if (!_profileMenuOpen) {
      return;
    }
    setState(() => _profileMenuOpen = false);
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).pushNamed('/login');
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
              child: _WebProfileMenu(
                user: user,
                onLogin: () async {
                  _closeProfileMenu();
                  await _openLogin();
                },
                onLogout: () async {
                  _closeProfileMenu();
                  await authModel?.logout();
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
            child: _WebAvatarButton(
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
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF11151D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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

class _WebAvatarButton extends StatelessWidget {
  const _WebAvatarButton({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final User? user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatar?.trim();
    final displayName = user?.displayName.trim() ?? '';
    final initial = displayName.isEmpty ? '大' : displayName.substring(0, 1);

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
                        _WebAvatarFallback(initial: initial),
                  )
                : _WebAvatarFallback(initial: initial),
          ),
        ),
      ),
    );
  }
}

class _WebAvatarFallback extends StatelessWidget {
  const _WebAvatarFallback({required this.initial});

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

class _WebProfileMenu extends StatelessWidget {
  const _WebProfileMenu({
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
            Text(
              user?.displayName ?? '未登录',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user?.email.isNotEmpty == true ? user!.email : '点击登录后可同步个人状态',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (user == null)
              FilledButton(
                onPressed: onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF11151D),
                ),
                child: const Text('登录'),
              )
            else
              OutlinedButton(
                onPressed: onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Text('退出登录'),
              ),
          ],
        ),
      ),
    );
  }
}
