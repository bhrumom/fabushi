import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'globe_home_screen.dart';
import 'leaderboard_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import 'video_feed_screen.dart';
import '../core/design_system/app_theme.dart';
import '../widgets/space_background.dart';
import '../providers/video_feed_visibility_notifier.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isGlobeReady = false;
  
  // 禅室屏幕的 GlobalKey，用于通知可见性变化
  final GlobalKey<MeditationRoomScreenState> _meditationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 立即加载，由 GlobeHomeScreen 内部控制延迟
    _isGlobeReady = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初始化时设置视频流页面可见性（默认 index=0 不可见）
    _updateVideoFeedVisibility();
  }

  /// 更新视频流页面可见性状态
  void _updateVideoFeedVisibility() {
    // 使用 context.read 避免重复监听
    final notifier = context.read<VideoFeedVisibilityNotifier>();
    notifier.setVisible(_currentIndex == 1); // index 1 是法流页面
  }
  
  /// 更新禅室页面可见性状态
  void _updateMeditationRoomVisibility() {
    final isZenRoomVisible = _currentIndex == 2;  // index 2 是禅室页面
    // 使用 GlobalKey 通知禅室页面可见性变化
    _meditationKey.currentState?.setVisible(isZenRoomVisible);
  }

  // 保持所有页面实例，避免重建
  List<Widget> get _screens => [
    _isGlobeReady
        ? const GlobeHomeScreen()
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在加载地球组件...')],
            ),
          ),
    const VideoFeedScreen(),
    MeditationRoomScreen(key: _meditationKey),  // 使用 GlobalKey
    const MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
                 )
              ],
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
                _updateVideoFeedVisibility();
                _updateMeditationRoomVisibility();  // 通知禅室页面可见性变化
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 70,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.public_outlined), 
                  selectedIcon: Icon(Icons.public),
                  label: '首页'
                ),
                NavigationDestination(
                  icon: Icon(Icons.video_library_outlined), 
                  selectedIcon: Icon(Icons.video_library),
                  label: '法流'
                ),
                NavigationDestination(
                  icon: Icon(Icons.self_improvement_outlined), 
                  selectedIcon: Icon(Icons.self_improvement),
                  label: '禅室'
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline), 
                  selectedIcon: Icon(Icons.person),
                  label: '我的'
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
