import 'package:flutter/material.dart';

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B10),
      appBar: AppBar(title: const Text('会员')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Web 首页保持轻量加载，会员解锁请在 App 端完成。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}
