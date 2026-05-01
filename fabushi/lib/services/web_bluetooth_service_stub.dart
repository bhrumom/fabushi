import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// Web蓝牙服务存根实现
///
/// 用于不支持Web蓝牙的平台
class WebBluetoothServiceStub {
  // 回调函数
  final Function(int)? onProgress;
  final Function(double)? onDataSent;
  final Function()? onStopped;

  bool _initialized = false;
  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentMB = 0.0;

  WebBluetoothServiceStub({this.onProgress, this.onDataSent, this.onStopped});

  bool get isInitialized => _initialized;
  bool get isRunning => _isRunning;

  /// 初始化Web蓝牙服务
  Future<bool> initialize() async {
    debugPrint('⚠️ Web蓝牙存根：当前平台不支持Web蓝牙');
    _initialized = true;
    return false; // 存根实现总是返回false
  }

  /// 开始发送文件
  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
  }) async {
    debugPrint('⚠️ Web蓝牙存根：无法发送文件，平台不支持');

    // 立即调用停止回调
    onStopped?.call();
  }

  /// 停止发送
  void stopSending() {
    _isRunning = false;
    debugPrint('⚠️ Web蓝牙存根：停止发送');
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _initialized,
      'isSending': _isRunning,
      'sentCount': _sentCount,
      'dataSentMB': _dataSentMB,
      'platform': 'stub',
      'supported': false,
    };
  }

  /// 释放资源
  void dispose() {
    stopSending();
    _initialized = false;
    debugPrint('⚠️ Web蓝牙存根：资源已释放');
  }
}
