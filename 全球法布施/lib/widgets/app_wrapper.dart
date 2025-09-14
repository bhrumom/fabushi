// 应用包装器
// 处理应用初始化状态和错误

import 'package:flutter/material.dart';
import '../services/app_initializer.dart';
import '../screens/home_screen.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    try {
      // 检查是否已初始化
      if (!AppInitializer.isInitialized) {
        await AppInitializer.initialize();
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString();
        _isInitialized = true; // 即使出错也继续
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化应用...'),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  '初始化警告',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '应用初始化时遇到问题，但仍可继续使用：\n$_initError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initError = null;
                    });
                  },
                  child: const Text('继续使用'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}