import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

// 条件导入，根据平台选择不同的实现
import 'webrtc_direct_service_stub.dart'
    if (dart.library.html) 'webrtc_direct_service_web_impl.dart';

/// WebRTC直接传输服务工厂类
/// 
/// 根据平台自动选择合适的WebRTC实现
/// 确保所有发送都是无连接发送，所有平台都是无连接真实发送数据
class WebRTCDirectService {
  // 回调函数
  final Function(int)? onProgress;
  final Function(double)? onDataSent;
  final Function()? onStopped;
  
  late final WebRTCDirectServiceInterface _implementation;
  
  WebRTCDirectService({
    this.onProgress,
    this.onDataSent,
    this.onStopped,
  }) {
    // 根据平台创建相应的实现
    _implementation = createWebRTCService(
      onProgress: onProgress,
      onDataSent: onDataSent,
      onStopped: onStopped,
    );
  }
  
  /// 是否已初始化
  bool get isInitialized => _implementation.isInitialized;
  
  /// 是否正在发送
  bool get isRunning => _implementation.isRunning ?? false;
  
  /// 传输进度流
  Stream<Map<String, dynamic>> get onTransferProgress => 
      _implementation.onTransferProgress ?? const Stream.empty();
  
  /// 初始化WebRTC服务
  Future<bool> initialize() async {
    debugPrint('🚀 初始化WebRTC无连接直接传输服务...');
    return await _implementation.initialize();
  }
  
  /// 开始发送文件
  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
  }) async {
    debugPrint('📡 开始WebRTC无连接文件发送');
    await _implementation.startSending(files: files, isLoop: isLoop);
  }
  
  /// 停止发送
  void stopSending() {
    debugPrint('🛑 停止WebRTC无连接传输');
    _implementation.stopSending();
  }
  
  /// 获取传输统计
  Map<String, dynamic> getStats() {
    return _implementation.getStats() ?? {
      'isInitialized': false,
      'isSending': false,
      'sentCount': 0,
      'dataSentMB': 0.0,
    };
  }
  
  /// 释放资源
  void dispose() {
    _implementation.dispose();
    debugPrint('🗑️ WebRTC服务资源已释放');
  }
}

/// WebRTC服务接口
abstract class WebRTCDirectServiceInterface {
  bool get isInitialized;
  bool? get isRunning;
  Stream<Map<String, dynamic>>? get onTransferProgress;
  
  Future<bool> initialize();
  Future<void> startSending({required List<PlatformFile> files, required bool isLoop});
  void stopSending();
  Map<String, dynamic>? getStats();
  void dispose();
}