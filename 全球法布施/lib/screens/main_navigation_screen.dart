import 'package:flutter/material.dart';
import 'globe_home_screen.dart';
import 'leaderboard_screen.dart';
import 'practice_screen.dart';
import 'my_profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    GlobeHomeScreen(),
    LeaderboardScreen(),
    PracticeScreen(),
    MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.public), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: '排行榜'),
          BottomNavigationBarItem(icon: Icon(Icons.self_improvement), label: '修习室'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
