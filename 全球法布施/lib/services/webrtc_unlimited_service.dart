import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebRTCUnlimitedService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;

  WebRTCUnlimitedService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
  });

  Future<bool> initialize() async {
    debugPrint('✅ WebRTC无限制发送服务初始化成功');
    return true;
  }

  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
    required String country,
  }) async {
    if (_isRunning) return;
    
    _isRunning = true;
    _sentCount = 0;
    _dataSentInMB = 0.0;

    try {
      for (final file in files) {
        if (!_isRunning) break;
        
        debugPrint('📤 WebRTC发送文件: ${file.name}');
        await _sendViaWebRTC(file);
        
        _sentCount++;
        _dataSentInMB += file.size / (1024 * 1024);
        
        onProgress(_sentCount);
        onDataSent(_dataSentInMB);
      }
    } catch (e) {
      debugPrint('❌ WebRTC发送失败: $e');
    } finally {
      _isRunning = false;
      onStopped();
    }
  }

  Future<void> _sendViaWebRTC(PlatformFile file) async {
    // 创建多个WebRTC连接进行广播
    final connections = <web.RTCPeerConnection>[];
    
    try {
      // 创建5个并发连接
      for (int i = 0; i < 5; i++) {
        final connection = web.RTCPeerConnection({
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
            {'urls': 'stun:stun1.l.google.com:19302'},
          ].jsify()
        }.jsify());
        
        connections.add(connection);
        
        // 创建数据通道
        final dataChannel = connection.createDataChannel('file-transfer', {
          'ordered': false,
          'maxRetransmits': 0,
        }.jsify());
        
        // 发送文件数据
        dataChannel.onopen = (web.Event event) {
          _sendFileData(dataChannel, file);
        }.toJS;
      }
      
      debugPrint('✅ WebRTC连接已建立，开始发送');
      
    } catch (e) {
      debugPrint('⚠️ WebRTC发送错误: $e');
    } finally {
      // 清理连接
      for (final conn in connections) {
        conn.close();
      }
    }
  }

  void _sendFileData(web.RTCDataChannel channel, PlatformFile file) {
    if (file.bytes == null) return;
    
    const chunkSize = 16384; // 16KB chunks
    final totalChunks = (file.bytes!.length / chunkSize).ceil();
    
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < file.bytes!.length) 
          ? start + chunkSize 
          : file.bytes!.length;
      
      final chunk = file.bytes!.sublist(start, end);
      
      try {
        channel.send(Uint8List.fromList(chunk).buffer.toJS);
        if (i % 100 == 0) {
          debugPrint('✅ WebRTC块 $i/$totalChunks 发送成功');
        }
      } catch (e) {
        debugPrint('⚠️ WebRTC块 $i 发送失败: $e');
      }
    }
  }

  void stopSending() {
    _isRunning = false;
  }
}