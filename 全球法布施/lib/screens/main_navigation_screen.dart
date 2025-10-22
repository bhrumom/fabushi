import 'package:flutter/material.dart';
import 'globe_home_screen.dart';
import 'leaderboard_screen.dart';
import 'practice_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 定义屏幕列表，顺序必须与底部导航栏一致
    final screens = [
      const GlobeHomeScreen(),      // 0: 首页
      const LeaderboardScreen(),    // 1: 排行榜
      const PracticeScreen(),       // 2: 修习
      const MeditationRoomScreen(), // 3: 禅室
      const MyProfileScreen(),      // 4: 我的
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.public), label: '首页'),              // 0
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: '排行榜'),    // 1
          BottomNavigationBarItem(icon: Icon(Icons.self_improvement), label: '修习'), // 2
          BottomNavigationBarItem(icon: Icon(Icons.temple_buddhist), label: '禅室'),   // 3
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),            // 4
        ],
      ),
    );
  }
}
