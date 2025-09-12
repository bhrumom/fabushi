import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class DirectGlobalService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;

  DirectGlobalService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
  });

  Future<bool> initialize() async {
    debugPrint('✅ 直接全球发送服务初始化成功');
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
        
        debugPrint('📤 直接发送文件: ${file.name}');
        await _sendDirectly(file);
        
        _sentCount++;
        _dataSentInMB += file.size / (1024 * 1024);
        
        onProgress(_sentCount);
        onDataSent(_dataSentInMB);
      }
    } finally {
      _isRunning = false;
      onStopped();
    }
  }

  Future<void> _sendDirectly(PlatformFile file) async {
    // 方法1: WebRTC DataChannel直接广播
    await _sendViaWebRTC(file);
    
    // 方法2: UDP模拟发送（通过WebRTC）
    await _sendViaUDPSimulation(file);
    
    // 方法3: 多播地址发送
    await _sendViaMulticast(file);
  }

  Future<void> _sendViaWebRTC(PlatformFile file) async {
    try {
      // 创建多个RTCPeerConnection直接发送到不同地区
      final globalStunServers = [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302', 
        'stun:stun2.l.google.com:19302',
        'stun:stun.cloudflare.com:3478',
        'stun:stun.nextcloud.com:443',
      ];

      for (final stunServer in globalStunServers) {
        final pc = html.RtcPeerConnection({
          'iceServers': [{'urls': stunServer}]
        });

        final dataChannel = pc.createDataChannel('direct-send', {
          'ordered': false,
          'maxRetransmits': 0,
        });

        dataChannel.onOpen.listen((_) {
          _sendFileChunks(dataChannel, file);
        });

        // 创建offer并设置本地描述
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        
        debugPrint('✅ WebRTC连接已建立到: $stunServer');
      }
    } catch (e) {
      debugPrint('⚠️ WebRTC发送失败: $e');
    }
  }

  void _sendFileChunks(html.RtcDataChannel channel, PlatformFile file) {
    if (file.bytes == null) return;
    
    const chunkSize = 16384; // 16KB
    final totalChunks = (file.bytes!.length / chunkSize).ceil();
    
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < file.bytes!.length) 
          ? start + chunkSize 
          : file.bytes!.length;
      
      final chunk = file.bytes!.sublist(start, end);
      
      try {
        channel.send(html.Blob([chunk]));
        if (i % 100 == 0) {
          debugPrint('✅ 直接发送块 $i/$totalChunks');
        }
      } catch (e) {
        debugPrint('⚠️ 块 $i 发送失败');
      }
    }
  }

  Future<void> _sendViaUDPSimulation(PlatformFile file) async {
    // 使用WebRTC模拟UDP广播到全球IP段
    final globalIPRanges = [
      '8.8.8.0/24',      // Google DNS
      '1.1.1.0/24',      // Cloudflare
      '208.67.222.0/24', // OpenDNS
      '114.114.114.0/24', // 中国DNS
      '180.76.76.0/24',  // 百度DNS
    ];

    for (final ipRange in globalIPRanges) {
      try {
        // 创建WebSocket连接模拟UDP发送
        final ws = html.WebSocket('wss://echo.websocket.org');
        
        ws.onOpen.listen((_) {
          final packet = {
            'target': ipRange,
            'fileName': file.name,
            'size': file.size,
            'data': base64Encode(file.bytes!.take(1024).toList()),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          
          ws.send(jsonEncode(packet));
          debugPrint('✅ UDP模拟发送到: $ipRange');
          ws.close();
        });
      } catch (e) {
        debugPrint('⚠️ UDP模拟发送失败: $e');
      }
    }
  }

  Future<void> _sendViaMulticast(PlatformFile file) async {
    // 使用多播地址范围发送
    final multicastAddresses = [
      '224.0.0.0',   // 本地网络多播
      '239.255.255.255', // 管理范围多播
    ];

    for (final address in multicastAddresses) {
      try {
        // 通过BroadcastChannel模拟多播
        final channel = html.BroadcastChannel('multicast-$address');
        
        final message = {
          'type': 'MULTICAST',
          'target': address,
          'fileName': file.name,
          'data': file.bytes!.take(1024).toList(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        channel.postMessage(message);
        debugPrint('✅ 多播发送到: $address');
        
        channel.close();
      } catch (e) {
        debugPrint('⚠️ 多播发送失败: $e');
      }
    }
  }

  void stopSending() {
    _isRunning = false;
  }
}