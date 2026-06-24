import 'package:flutter/material.dart';
import 'globe_home_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import '../core/design_system/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/space_background.dart';

import '../widgets/sidebar/codex_sidebar.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 3;
  bool _isGlobeReady = false;

  // 追踪哪些页面已被激活
  final List<bool> _activatedScreens = [false, false, false, true, false];

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
      'assistant' || 'openclaw' || 'workbench' => 0,
      'meditation' || 'meditation-room' || 'zen' => 1,
      'profile' || 'me' || 'mine' => 2,
      _ => 0,
    };
    _currentIndex = initialIndex;
    _activatedScreens[initialIndex] = true;
  }

  /// 更新禅室页面可见性状态
  void _updateMeditationRoomVisibility() {
    final isZenRoomVisible = _currentIndex == 2 && _activatedScreens[2];
    // 使用 GlobalKey 通知禅室页面可见性变化
    _meditationKey.currentState?.setVisible(isZenRoomVisible);
  }

  /// 更新地球页面可见性状态
  void _updateGlobeVisibility() {
    final isGlobeVisible = _currentIndex == 0 || _currentIndex == 1;
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

    // 0: 首页 (聊天视图)
    screens.add(
      TickerMode(
        enabled: _currentIndex == 0 || _currentIndex == 1,
        child: _isGlobeReady
            ? GlobeHomeScreen(key: _globeKey)
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载组件...'),
                  ],
                ),
              ),
      ),
    );
    
    // 1: 地球视图 (目前和首页复用 GlobeHomeScreen)
    screens.add(const SizedBox.shrink()); 

    // 2: 禅室 (佛像3D)
    screens.add(
      TickerMode(
        enabled: _currentIndex == 2,
        child: _activatedScreens[2]
            ? MeditationRoomScreen(key: _meditationKey)
            : const Center(child: CircularProgressIndicator()),
      ),
    );

    // 3: 我的 (个人资料)
    screens.add(
      TickerMode(
        enabled: _currentIndex == 3,
        child: _activatedScreens[3]
            ? const MyProfileScreen()
            : const Center(child: CircularProgressIndicator()),
      ),
    );

    // 4: 设置
    screens.add(
      TickerMode(
        enabled: _currentIndex == 4,
        child: _activatedScreens[4]
            ? SettingsScreen(
                onClose: () => setState(() => _currentIndex = 0),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );

    return screens;
  }

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            CodexSidebar(
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
                
                if (index == 0) {
                  _globeKey.currentState?.setGlobeMode(false);
                } else if (index == 1) {
                  _globeKey.currentState?.setGlobeMode(true);
                }
              },
            ),
            Expanded(
              child: IndexedStack(
                // 当 currentIndex 为 1 (地球视图) 时，复用 0 的 GlobeHomeScreen
                index: _currentIndex == 1 ? 0 : _currentIndex, 
                children: _screens,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
