import 'package:flutter/material.dart';
import 'globe_home_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import '../core/design_system/app_theme.dart';
import '../l10n/app_localizations.dart';
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
    final l10n = context.l10n;

    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: AppTheme.primaryColor.withOpacity(0.3),
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
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
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
                  icon: const Icon(Icons.public_outlined),
                  selectedIcon: const Icon(Icons.public),
                  label: l10n.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.self_improvement_outlined),
                  selectedIcon: const Icon(Icons.self_improvement),
                  label: l10n.navMeditationRoom,
                ),
                NavigationDestination(
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
