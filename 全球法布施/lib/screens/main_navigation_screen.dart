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
  
  // 保持所有页面实例，避免重建
  final List<Widget> _screens = const [
    GlobeHomeScreen(),
    LeaderboardScreen(),
    PracticeScreen(),
    MeditationRoomScreen(),
    MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.public), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: '排行榜'),
          BottomNavigationBarItem(icon: Icon(Icons.self_improvement), label: '修习'),
          BottomNavigationBarItem(icon: Icon(Icons.temple_buddhist), label: '禅室'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
