import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:isolate';

/// 本地回环运行模式
enum LoopbackRunMode {
  /// Isolate后台运行（前台时使用，不阻塞UI）
  isolate,
  /// 主线程运行（后台时使用，保持应用活跃）
  mainThread,
}

/// 本地回环服务
/// 以极速不间断地向 127.0.0.1 发送 UDP 数据包
/// 
/// 支持两种运行模式：
/// - 前台模式：在 Isolate 中运行，不阻塞 UI
/// - 后台模式：在主线程运行，保持应用活跃防止系统杀后台
class LocalLoopbackService {
  static const int _loopbackPort = 9998;
  static const String _loopbackAddress = '127.0.0.1';
  
  bool _isRunning = false;
  int _loopCount = 0;
  LoopbackRunMode _currentMode = LoopbackRunMode.isolate;
  
  // Isolate 模式资源
  Isolate? _workerIsolate;
  ReceivePort? _receivePort;
  
  // 主线程模式资源
  Timer? _mainThreadTimer;
  RawDatagramSocket? _mainThreadSocket;
  
  // 缓存的启动参数（用于模式切换时重新启动）
  Uint8List? _cachedData;
  String? _cachedFilePath;
  String? _cachedFileName;
  Uint8List? _cachedHeaderPacket;

  final void Function(String)? onLog;
  final void Function(int loopCount)? onHeartbeat;
  
  LocalLoopbackService({
    this.onLog,
    this.onHeartbeat,
  });
  
  /// 当前运行模式
  LoopbackRunMode get currentMode => _currentMode;
  
  /// 当前循环计数
  int get loopCount => _loopCount;
  
  /// 开始高速回环（默认使用 Isolate 模式）
  Future<void> start({
    Uint8List? data,
    String? filePath,
    required String fileName,
    LoopbackRunMode mode = LoopbackRunMode.isolate,
  }) async {
    if (_isRunning) return;
    
    // 缓存参数
    _cachedData = data;
    _cachedFilePath = filePath;
    _cachedFileName = fileName;
    _cachedHeaderPacket = _buildHeader(fileName);
    
    _isRunning = true;
    _currentMode = mode;
    
    if (mode == LoopbackRunMode.isolate) {
      await _startIsolateMode();
    } else {
      await _startMainThreadMode();
    }
  }
  
  /// 切换运行模式
  /// 
  /// 在不停止回环的情况下，热切换运行模式。
  /// 用于应用前后台切换时动态调整：
  /// - 前台时切换到 Isolate 模式，避免卡UI
  /// - 后台时切换到主线程模式，保持应用活跃
  Future<void> switchMode(LoopbackRunMode newMode) async {
    if (!_isRunning) return;
    if (_currentMode == newMode) return;
    
    final preservedLoopCount = _loopCount;
    _log('🔄 切换本地回环模式: $_currentMode -> $newMode (保留计数: $preservedLoopCount)');
    
    // 停止当前模式（但不重置状态）
    if (_currentMode == LoopbackRunMode.isolate) {
      _stopIsolateMode();
    } else {
      await _stopMainThreadMode();
    }
    
    // 切换模式
    _currentMode = newMode;
    _loopCount = preservedLoopCount;
    
    // 启动新模式
    if (newMode == LoopbackRunMode.isolate) {
      await _startIsolateMode();
    } else {
      await _startMainThreadMode();
    }
    
    _log('✅ 模式切换完成: $newMode');
  }
  
  /// 启动 Isolate 模式
  Future<void> _startIsolateMode() async {
    if (_cachedFileName == null || _cachedHeaderPacket == null) {
      _log('❌ 缺少启动参数');
      return;
    }
    
    _log('🚀 [Isolate] 准备启动高速流式本地回环: $_cachedFileName');
    
    // 初始化接收端口
    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (message is String) {
        _log(message);
      } else if (message is Map && message['type'] == 'heartbeat') {
        // Handle heartbeat from background isolate - this runs on main thread
        final loopCount = message['loopCount'] as int? ?? 0;
        _loopCount = loopCount;
        onHeartbeat?.call(loopCount);
      }
    });
    
    try {
      // 启动后台 Isolate
      _workerIsolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateParams(
          sendPort: _receivePort!.sendPort,
          headerPacket: _cachedHeaderPacket!,
          data: _cachedData,
          filePath: _cachedFilePath,
          address: _loopbackAddress,
          port: _loopbackPort,
          initialLoopCount: _loopCount,
        ),
      );
    } catch (e) {
      _log('❌ 启动 Isolate 失败: $e');
      _isRunning = false;
    }
  }
  
  /// 停止 Isolate 模式（仅停止，不重置状态）
  void _stopIsolateMode() {
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    
    _receivePort?.close();
    _receivePort = null;
  }
  
  /// 启动主线程模式
  Future<void> _startMainThreadMode() async {
    if (_cachedFileName == null || _cachedHeaderPacket == null) {
      _log('❌ 缺少启动参数');
      return;
    }
    
    _log('🚀 [MainThread] 启动主线程本地回环: $_cachedFileName');
    
    try {
      _mainThreadSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _mainThreadSocket!.broadcastEnabled = true;
      _log('✨ [MainThread] 数据发送引擎初始化完成');
      
      final address = InternetAddress(_loopbackAddress);
      DateTime lastHeartbeat = DateTime.now();
      const heartbeatInterval = Duration(seconds: 2);
      
      // 使用 Timer.periodic 在主线程执行
      // 注意：这里使用较长的间隔(50ms)，确保不会阻塞UI太久
      // 每次只发送一个完整文件循环，然后让出主线程
      _mainThreadTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        if (!_isRunning || _currentMode != LoopbackRunMode.mainThread) {
          timer.cancel();
          return;
        }
        
        try {
          _loopCount++;
          
          // 发送心跳
          final now = DateTime.now();
          if (now.difference(lastHeartbeat) >= heartbeatInterval) {
            onHeartbeat?.call(_loopCount);
            lastHeartbeat = now;
            
            // 每30秒输出日志
            if (_loopCount % 15 == 0) {
              _log('💓 [MainThread] 本地回环循环次数: $_loopCount');
            }
          }
          
          // 发送数据
          if (_cachedData != null) {
            _sendMemoryData(_mainThreadSocket!, address, _loopbackPort, _cachedHeaderPacket!, _cachedData!);
          } else if (_cachedFilePath != null) {
            await _sendFileData(_mainThreadSocket!, address, _loopbackPort, _cachedHeaderPacket!, _cachedFilePath!);
          }
        } catch (e) {
          _log('⚠️ [MainThread] 发送异常: $e');
        }
      });
    } catch (e) {
      _log('❌ 启动主线程模式失败: $e');
    }
  }
  
  /// 发送内存数据
  void _sendMemoryData(RawDatagramSocket socket, InternetAddress address, int port, Uint8List header, Uint8List data) {
    const chunkSize = 1300;
    int offset = 0;
    
    while (offset < data.length) {
      final end = (offset + chunkSize < data.length) ? offset + chunkSize : data.length;
      final packet = BytesBuilder();
      packet.add(header);
      packet.add(data.sublist(offset, end));
      socket.send(packet.toBytes(), address, port);
      offset = end;
    }
  }
  
  /// 发送文件数据
  Future<void> _sendFileData(RawDatagramSocket socket, InternetAddress address, int port, Uint8List header, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    
    const chunkSize = 1300;
    final raf = await file.open(mode: FileMode.read);
    
    try {
      while (true) {
        final bytes = await raf.read(chunkSize);
        if (bytes.isEmpty) break;
        
        final packet = BytesBuilder();
        packet.add(header);
        packet.add(bytes);
        socket.send(packet.toBytes(), address, port);
      }
    } finally {
      await raf.close();
    }
  }
  
  /// 停止主线程模式（仅停止，不重置状态）
  Future<void> _stopMainThreadMode() async {
    _mainThreadTimer?.cancel();
    _mainThreadTimer = null;
    
    _mainThreadSocket?.close();
    _mainThreadSocket = null;
  }
  
  static void _isolateEntry(_IsolateParams params) async {
    final sendPort = params.sendPort;
    final address = InternetAddress(params.address);
    final port = params.port;
    
    // Heartbeat tracking - 从传入的初始值开始
    int loopCount = params.initialLoopCount;
    DateTime lastHeartbeat = DateTime.now();
    const heartbeatInterval = Duration(seconds: 2);
    
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      sendPort.send('✨ [Worker] 数据发送引擎初始化完成');
      
      // 极速流式回环发送
      while (true) {
        loopCount++;
        
        // Send heartbeat to main thread every 2 seconds
        final now = DateTime.now();
        if (now.difference(lastHeartbeat) >= heartbeatInterval) {
          sendPort.send({'type': 'heartbeat', 'loopCount': loopCount, 'timestamp': now.toIso8601String()});
          lastHeartbeat = now;
        }
        
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
    
    // 停止当前模式
    if (_currentMode == LoopbackRunMode.isolate) {
      _stopIsolateMode();
    } else {
      _stopMainThreadMode();
    }
    
    // 重置状态
    _loopCount = 0;
    _cachedData = null;
    _cachedFilePath = null;
    _cachedFileName = null;
    _cachedHeaderPacket = null;
    
    _log('🛑 本地回环已停止');
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
  final int initialLoopCount;

  _IsolateParams({
    required this.sendPort,
    required this.headerPacket,
    this.data,
    this.filePath,
    required this.address,
    required this.port,
    this.initialLoopCount = 0,
  });
}
