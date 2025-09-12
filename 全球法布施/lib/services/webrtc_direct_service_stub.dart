import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'webrtc_direct_service.dart';

/// WebRTC直接传输服务存根实现
/// 
/// 用于不支持WebRTC的平台（如移动平台）
/// 提供基本的无连接传输功能
class WebRTCDirectServiceStub implements WebRTCDirectServiceInterface {
  // 回调函数
  final Function(int)? onProgress;
  final Function(double)? onDataSent;
  final Function()? onStopped;
  
  bool _initialized = false;
  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentMB = 0.0;
  
  final _progressController = StreamController<Map<String, dynamic>>.broadcast();
  
  WebRTCDirectServiceStub({
    this.onProgress,
    this.onDataSent,
    this.onStopped,
  });
  
  @override
  bool get isInitialized => _initialized;
  
  @override
  bool get isRunning => _isRunning;
  
  @override
  Stream<Map<String, dynamic>> get onTransferProgress => _progressController.stream;
  
  @override
  Future<bool> initialize() async {
    debugPrint('⚠️ WebRTC存根：当前平台不支持WebRTC，使用模拟实现');
    _initialized = true;
    return true;
  }
  
  @override
  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
  }) async {
    if (_isRunning) return;
    
    _isRunning = true;
    _sentCount = 0;
    _dataSentMB = 0.0;
    
    debugPrint('⚠️ WebRTC存根：模拟发送 ${files.length} 个文件');
    
    try {
      do {
        for (final file in files) {
          if (!_isRunning) break;
          
          debugPrint('⚠️ WebRTC存根：模拟发送文件 ${file.name}');
          
          // 模拟发送过程
          await _simulateFileSending(file);
          
          _sentCount++;
          _dataSentMB += (file.size / 1024 / 1024);
          
          onProgress?.call(_sentCount);
          onDataSent?.call(_dataSentMB);
          
          _progressController.add({
            'fileName': file.name,
            'progress': '100.0',
            'method': 'WebRTC存根',
            'status': 'completed',
          });
          
          // 模拟发送间隔
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        if (isLoop && _isRunning) {
          debugPrint('⚠️ WebRTC存根：循环模式，继续下一轮');
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (isLoop && _isRunning);
      
    } catch (e) {
      debugPrint('❌ WebRTC存根发送过程中出错: $e');
    } finally {
      _isRunning = false;
      onStopped?.call();
      debugPrint('⚠️ WebRTC存根：发送已停止');
    }
  }
  
  /// 模拟文件发送过程
  Future<void> _simulateFileSending(PlatformFile file) async {
    final fileName = file.name;
    final fileSize = file.size;
    
    debugPrint('⚠️ WebRTC存根：开始模拟发送 $fileName (${fileSize} 字节)');
    
    // 模拟分块发送
    const int chunkSize = 16384; // 16KB
    final int totalChunks = (fileSize / chunkSize).ceil();
    
    for (int i = 0; i < totalChunks; i++) {
      if (!_isRunning) break;
      
      final progress = ((i + 1) / totalChunks * 100).toStringAsFixed(1);
      
      _progressController.add({
        'fileName': fileName,
        'chunkIndex': i,
        'totalChunks': totalChunks,
        'progress': progress,
        'method': 'WebRTC存根',
        'status': 'sending',
      });
      
      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    debugPrint('⚠️ WebRTC存根：文件 $fileName 模拟发送完成');
  }
  
  @override
  void stopSending() {
    if (!_isRunning) return;
    
    _isRunning = false;
    debugPrint('⚠️ WebRTC存根：停止发送');
  }
  
  @override
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _initialized,
      'isSending': _isRunning,
      'sentCount': _sentCount,
      'dataSentMB': _dataSentMB,
      'platform': 'stub',
      'note': '当前平台不支持WebRTC，使用存根实现',
    };
  }
  
  @override
  void dispose() {
    stopSending();
    _progressController.close();
    _initialized = false;
    debugPrint('⚠️ WebRTC存根：资源已释放');
  }
}

/// 创建WebRTC服务的工厂函数
WebRTCDirectServiceInterface createWebRTCService({
  Function(int)? onProgress,
  Function(double)? onDataSent,
  Function()? onStopped,
}) {
  return WebRTCDirectServiceStub(
    onProgress: onProgress,
    onDataSent: onDataSent,
    onStopped: onStopped,
  );
}
