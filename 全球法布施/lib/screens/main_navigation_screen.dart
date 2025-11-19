import 'package:flutter/material.dart';
import 'globe_home_screen.dart';
import 'leaderboard_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import 'video_feed_screen.dart';
import '../core/design_system/app_theme.dart';
import '../widgets/space_background.dart';

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
