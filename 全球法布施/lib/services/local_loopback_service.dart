import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 本地回环服务
/// 以极速不间断地向 127.0.0.1 发送 UDP 数据包
class LocalLoopbackService {
  static const int _loopbackPort = 9998;
  static const String _loopbackAddress = '127.0.0.1';
  
  RawDatagramSocket? _socket;
  bool _isRunning = false;
  int _loopCount = 0;
  
  final void Function(int)? onLoopCountChanged;
  final void Function(String)? onLog;
  
  LocalLoopbackService({
    this.onLoopCountChanged,
    this.onLog,
  });
  
  /// 初始化服务
  Future<bool> initialize() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _log('✨ 本地回环服务初始化完成');
      return true;
    } catch (e) {
      _log('❌ 本地回环服务初始化失败: $e');
      return false;
    }
  }
  
  /// 开始高速回环
  Future<void> start({
    required Uint8List data,
    required String fileName,
  }) async {
    if (_isRunning) return;
    if (_socket == null) {
      await initialize();
    }
    
    _isRunning = true;
    _loopCount = 0;
    
    _log('🚀 开始高速本地回环: $fileName');
    
    // 构建数据包
    final packet = _buildPacket(data, fileName);
    final address = InternetAddress(_loopbackAddress);
    
    // 使用微任务或快速循环进行不间断发送
    _runLoop(packet, address);
  }
  
  void _runLoop(Uint8List packet, InternetAddress address) async {
    while (_isRunning && _socket != null) {
      try {
        _socket!.send(packet, address, _loopbackPort);
        _loopCount++;
        
        // 每 1000 次通知一次进度，避免频繁更新 UI
        if (_loopCount % 1000 == 0) {
          onLoopCountChanged?.call(_loopCount);
        }
        
        // 极小延迟，防止完全阻塞主线程，但保持极高速
        // 使用 Future.delayed(Duration.zero) 或微任务
        if (_loopCount % 100 == 0) {
          await Future.delayed(Duration.zero);
        }
      } catch (e) {
        _log('⚠️ 回环发送失败: $e');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }
  
  /// 停止回环
  void stop() {
    _isRunning = false;
    _log('🛑 本地回环已停止，共完成 $_loopCount 次回环');
  }
  
  /// 释放资源
  void dispose() {
    stop();
    _socket?.close();
    _socket = null;
  }
  
  Uint8List _buildPacket(Uint8List data, String fileName) {
    final header = {
      'type': 'dharma_local_loop',
      'fileName': fileName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final headerBytes = utf8.encode(jsonEncode(header));
    final packet = BytesBuilder();
    
    // 包头长度 (4 字节)
    packet.addByte((headerBytes.length >> 24) & 0xFF);
    packet.addByte((headerBytes.length >> 16) & 0xFF);
    packet.addByte((headerBytes.length >> 8) & 0xFF);
    packet.addByte(headerBytes.length & 0xFF);
    
    packet.add(headerBytes);
    
    // 数据（UDP 包限制，只放一部分或全部，回环主要看次数）
    if (data.length > 1300) {
      packet.add(data.sublist(0, 1300));
    } else {
      packet.add(data);
    }
    
    return packet.toBytes();
  }
  
  void _log(String message) {
    debugPrint('[LocalLoop] $message');
    onLog?.call(message);
  }
  
  bool get isRunning => _isRunning;
  int get loopCount => _loopCount;
}
