import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:js' as js;

class ZenRoomScreen extends StatefulWidget {
  const ZenRoomScreen({super.key});

  @override
  State<ZenRoomScreen> createState() => _ZenRoomScreenState();
}

class _ZenRoomScreenState extends State<ZenRoomScreen> {
  bool _isLoading = true;
  String _loadingStatus = '正在初始化禅室...';

  @override
  void initState() {
    super.initState();
    _initZenRoom();
  }

  Future<void> _initZenRoom() async {
    try {
      setState(() => _loadingStatus = '加载 3D 场景...');
      await Future.delayed(const Duration(milliseconds: 500));

      final result = js.context.callMethod('initZenRoom3D');

      if (result == true) {
        setState(() {
          _isLoading = false;
          _loadingStatus = '';
        });
        js.context.callMethod('showZenRoom3D');
      } else {
        throw Exception('初始化失败');
      }
    } catch (e) {
      setState(() {
        _loadingStatus = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    js.context.callMethod('hideZenRoom3D');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('🙏 禅室'),
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFFD700)),
                  const SizedBox(height: 20),
                  Text(_loadingStatus, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),

          if (!_isLoading)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.black.withOpacity(0.7),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🕉️ 南无阿弥陀佛 🕉️',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '愿此功德回向法界众生，同证菩提',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '💡 提示：拖动旋转视角，滚轮缩放',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
