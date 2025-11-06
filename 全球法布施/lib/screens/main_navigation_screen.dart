import 'package:flutter/material.dart';
import 'globe_home_screen.dart';
import 'leaderboard_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import 'video_feed_screen.dart';
import '../core/design_system/app_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isGlobeReady = false;

  @override
  void initState() {
    super.initState();
    // 立即加载，由 GlobeHomeScreen 内部控制延迟
    _isGlobeReady = true;
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
    const MeditationRoomScreen(),
    const MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        elevation: 8,
        height: 60,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.public), label: '首页'),
          NavigationDestination(icon: Icon(Icons.video_library), label: '法流'),
          NavigationDestination(icon: Icon(Icons.temple_buddhist), label: '禅室'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
