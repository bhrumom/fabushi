import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'globe_home_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import '../widgets/space_background.dart';

import '../widgets/sidebar/codex_sidebar.dart';
import '../widgets/sidebar/dacheng_chat_sidebar.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 3;
  bool _isGlobeReady = false;
  bool _mobileSidebarOpen = false;

  final List<bool> _activatedScreens = [false, false, false, true, false];

  final GlobalKey<MeditationRoomScreenState> _meditationKey = GlobalKey();
  final GlobalKey<GlobeHomeScreenState> _globeKey = GlobalKey();

  bool get _isMobileRuntime => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _isGlobeReady = true;
    _applyInitialTabFromUrl();
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

  void _updateMeditationRoomVisibility() {
    final isZenRoomVisible = _currentIndex == 2 && _activatedScreens[2];
    _meditationKey.currentState?.setVisible(isZenRoomVisible);
  }

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

  void _selectDestination(int index) {
    setState(() {
      _currentIndex = index;
      _mobileSidebarOpen = false;
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
  }

  List<Widget> get _screens {
    final screens = <Widget>[];

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

    screens.add(const SizedBox.shrink());

    screens.add(
      TickerMode(
        enabled: _currentIndex == 2,
        child: _activatedScreens[2]
            ? MeditationRoomScreen(key: _meditationKey)
            : const Center(child: CircularProgressIndicator()),
      ),
    );

    screens.add(
      TickerMode(
        enabled: _currentIndex == 3,
        child: _activatedScreens[3]
            ? const MyProfileScreen()
            : const Center(child: CircularProgressIndicator()),
      ),
    );

    screens.add(
      TickerMode(
        enabled: _currentIndex == 4,
        child: _activatedScreens[4]
            ? SettingsScreen(onClose: () => setState(() => _currentIndex = 0))
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
        body: _isMobileRuntime ? _buildMobileShell() : _buildDesktopShell(),
      ),
    );
  }

  Widget _buildDesktopShell() {
    return Row(
      children: [
        CodexSidebar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectDestination,
        ),
        Expanded(child: _buildIndexedStack()),
      ],
    );
  }

  Widget _buildMobileShell() {
    return Stack(
      children: [
        Positioned.fill(child: _buildIndexedStack()),
        Positioned(
          left: 18,
          top: 16,
          child: SafeArea(
            child: _SidebarOpenButton(
              onPressed: () => setState(() => _mobileSidebarOpen = true),
            ),
          ),
        ),
        if (_mobileSidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _mobileSidebarOpen = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: _mobileSidebarOpen ? 0 : -MediaQuery.sizeOf(context).width,
          top: 0,
          bottom: 0,
          child: DachengChatSidebar(
            onNewChat: () => _selectDestination(0),
            onClose: () => setState(() => _mobileSidebarOpen = false),
          ),
        ),
      ],
    );
  }

  Widget _buildIndexedStack() {
    return IndexedStack(
      index: _currentIndex == 1 ? 0 : _currentIndex,
      children: _screens,
    );
  }
}

class _SidebarOpenButton extends StatelessWidget {
  const _SidebarOpenButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC222A30),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: '打开侧边栏',
        onPressed: onPressed,
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
