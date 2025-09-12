import 'dart:async';
import 'dart:js' as js;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class NoConnectionWebService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;

  bool _isRunning = false;

  NoConnectionWebService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
  });

  Future<bool> initialize() async {
    try {
      if (!js.context.hasProperty('flutterNoConnectionBridge')) {
        debugPrint('❌ JavaScript桥接器未加载');
        return false;
      }
      debugPrint('✅ Web端无连接发送服务初始化成功');
      return true;
    } catch (e) {
      debugPrint('❌ 初始化失败: $e');
      return false;
    }
  }

  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
    required String country,
  }) async {
    if (_isRunning) return;
    
    _isRunning = true;
    int sentCount = 0;
    double dataSentInMB = 0.0;

    try {
      for (final file in files) {
        if (!_isRunning) break;
        
        debugPrint('📤 模拟发送文件: ${file.name}');
        
        // 模拟发送过程
        await Future.delayed(const Duration(milliseconds: 500));
        
        sentCount++;
        dataSentInMB += file.size / (1024 * 1024);
        
        onProgress(sentCount);
        onDataSent(dataSentInMB);
      }
    } catch (e) {
      debugPrint('❌ 发送失败: $e');
    } finally {
      _isRunning = false;
      onStopped();
    }
  }

  void stopSending() {
    _isRunning = false;
  }

  Map<String, dynamic>? getTargetInfo() {
    return {
      'totalTargets': 5,
      'targetsByType': {'http': 3, 'dns': 2},
    };
  }

  Future<Map<String, dynamic>?> testConnections() async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'results': [],
      'summary': {'total': 5, 'successful': 4},
    };
  }
}