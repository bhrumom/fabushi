import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:isolate';


/// 本地回环服务
/// 以极速不间断地向 127.0.0.1 发送 UDP 数据包
class LocalLoopbackService {
  static const int _loopbackPort = 9998;
  static const String _loopbackAddress = '127.0.0.1';
  
  bool _isRunning = false;
  int _loopCount = 0;
  
  Isolate? _workerIsolate;
  ReceivePort? _receivePort;

  
  final void Function(String)? onLog;
  
  LocalLoopbackService({
    this.onLog,
  });
  
  
  /// 开始高速回环
  Future<void> start({
    Uint8List? data,
    String? filePath,
    required String fileName,
  }) async {
    if (_isRunning) return;
    
    _isRunning = true;
    
    _log('🚀 [Isolate] 准备启动高速流式本地回环: $fileName');
    
    // 构建包头（不含大数据部分）
    final headerPacket = _buildHeader(fileName);
    
    // 初始化接收端口
    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (message is String) {
        _log(message);
      }
    });
    
    try {
      // 启动后台 Isolate
      _workerIsolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateParams(
          sendPort: _receivePort!.sendPort,
          headerPacket: headerPacket,
          data: data,
          filePath: filePath,
          address: _loopbackAddress,
          port: _loopbackPort,
        ),
      );
    } catch (e) {
      _log('❌ 启动 Isolate 失败: $e');
      _isRunning = false;
    }
  }
  
  static void _isolateEntry(_IsolateParams params) async {
    final sendPort = params.sendPort;
    final address = InternetAddress(params.address);
    final port = params.port;
    
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      sendPort.send('✨ [Worker] 数据发送引擎初始化完成');
      
      // 极速流式回环发送
      while (true) {
        if (params.data != null) {
          // 如果是内存数据
          final data = params.data!;
          int offset = 0;
          final chunkSize = 1300;
          
          while (offset < data.length) {
            final end = (offset + chunkSize < data.length) ? offset + chunkSize : data.length;
            final packet = BytesBuilder();
            packet.add(params.headerPacket);
            packet.add(data.sublist(offset, end));
            socket.send(packet.toBytes(), address, port);
            offset = end;
          }
        } else if (params.filePath != null) {
          // 如果是文件路径，逐步流式读取发送
          final file = File(params.filePath!);
          if (await file.exists()) {
            final raf = await file.open(mode: FileMode.read);
            final chunkSize = 1300;
            
            while (true) {
              final bytes = await raf.read(chunkSize);
              if (bytes.isEmpty) break;
              
              final packet = BytesBuilder();
              packet.add(params.headerPacket);
              packet.add(bytes);
              socket.send(packet.toBytes(), address, port);
            }
            await raf.close();
          }
        }

        // 完成一次全量文件回环后极小延迟
        await Future.delayed(const Duration(milliseconds: 10));
      }
    } catch (e) {
      sendPort.send('⚠️ [Worker] 发送循环异常: $e');
    } finally {
      socket?.close();
    }
  }
  
  /// 停止回环
  void stop() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    
    _receivePort?.close();
    _receivePort = null;
    
    _log('🛑 本地回环外部信号已停止');
  }
  
  /// 释放资源
  void dispose() {
    stop();
  }
  
  Uint8List _buildHeader(String fileName) {
    final header = {
      'type': 'dharma_local_loop',
      'fileName': fileName,
      'timestamp': DateTime.now().toIso8601String(),
      'mode': 'streaming',
    };
    
    final headerBytes = utf8.encode(jsonEncode(header));
    final packet = BytesBuilder();
    
    // 包头长度 (4 字节)
    packet.addByte((headerBytes.length >> 24) & 0xFF);
    packet.addByte((headerBytes.length >> 16) & 0xFF);
    packet.addByte((headerBytes.length >> 8) & 0xFF);
    packet.addByte(headerBytes.length & 0xFF);
    
    packet.add(headerBytes);
    return packet.toBytes();
  }
  
  void _log(String message) {
    debugPrint('[LocalLoop] $message');
    onLog?.call(message);
  }
  
  bool get isRunning => _isRunning;
}

class _IsolateParams {
  final SendPort sendPort;
  final Uint8List headerPacket;
  final Uint8List? data;
  final String? filePath;
  final String address;
  final int port;

  _IsolateParams({
    required this.sendPort,
    required this.headerPacket,
    this.data,
    this.filePath,
    required this.address,
    required this.port,
  });
}
