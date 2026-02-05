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

/// 本地回环速度级别
enum LoopbackSpeedLevel {
  /// 极致速度 - 无延迟，持续满载发送
  extreme,
  /// 高速 - 微延迟(1ms)，平衡性能与资源
  high,
  /// 普通 - 适中延迟(5ms)，节省资源
  normal,
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
  
  /// 极致优化：最大UDP包大小 (本地回环可使用更大包体)
  /// 本地回环MTU无限制，使用接近最大UDP包大小
  static const int _maxChunkSize = 8192;
  
  /// 批量发送次数 - 每轮发送多个完整文件循环
  static const int _batchCount = 10;
  
  bool _isRunning = false;
  int _loopCount = 0;
  LoopbackRunMode _currentMode = LoopbackRunMode.isolate;
  LoopbackSpeedLevel _speedLevel = LoopbackSpeedLevel.extreme;
  
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
  
  // 极致优化：预构建的数据包缓存
  List<Uint8List>? _prebuiltPackets;

  final void Function(String)? onLog;
  final void Function(int loopCount)? onHeartbeat;
  
  LocalLoopbackService({
    this.onLog,
    this.onHeartbeat,
  });
  
  /// 当前运行模式
  LoopbackRunMode get currentMode => _currentMode;
  
  /// 当前速度级别
  LoopbackSpeedLevel get speedLevel => _speedLevel;
  
  /// 当前循环计数
  int get loopCount => _loopCount;
  
  /// 设置速度级别
  void setSpeedLevel(LoopbackSpeedLevel level) {
    _speedLevel = level;
    _log('⚡ 速度级别设置为: $level');
  }
  
  /// 开始高速回环（默认使用 Isolate 模式）
  Future<void> start({
    Uint8List? data,
    String? filePath,
    required String fileName,
    LoopbackRunMode mode = LoopbackRunMode.mainThread,
    LoopbackSpeedLevel speedLevel = LoopbackSpeedLevel.extreme,
  }) async {
    if (_isRunning) return;
    
    // 缓存参数
    _cachedData = data;
    _cachedFilePath = filePath;
    _cachedFileName = fileName;
    _cachedHeaderPacket = _buildHeader(fileName);
    _speedLevel = speedLevel;
    
    // 极致优化：预构建数据包
    await _prebuildPackets();
    
    _isRunning = true;
    _currentMode = mode;
    
    if (mode == LoopbackRunMode.isolate) {
      await _startIsolateMode();
    } else {
      await _startMainThreadMode();
    }
  }
  
  /// 极致优化：预构建所有数据包，避免运行时动态分配
  Future<void> _prebuildPackets() async {
    if (_cachedHeaderPacket == null) return;
    
    final packets = <Uint8List>[];
    final header = _cachedHeaderPacket!;
    
    if (_cachedData != null) {
      // 内存数据预构建
      final data = _cachedData!;
      int offset = 0;
      
      while (offset < data.length) {
        final end = (offset + _maxChunkSize < data.length) ? offset + _maxChunkSize : data.length;
        final packetSize = header.length + (end - offset);
        final packet = Uint8List(packetSize);
        
        // 零拷贝：直接写入目标buffer
        packet.setRange(0, header.length, header);
        packet.setRange(header.length, packetSize, data, offset);
        
        packets.add(packet);
        offset = end;
      }
      
      _log('📦 预构建 ${packets.length} 个数据包 (每包最大 $_maxChunkSize 字节)');
    } else if (_cachedFilePath != null) {
      // 文件数据：读入内存并预构建
      final file = File(_cachedFilePath!);
      if (await file.exists()) {
        final fileData = await file.readAsBytes();
        _cachedData = fileData; // 缓存到内存
        
        int offset = 0;
        while (offset < fileData.length) {
          final end = (offset + _maxChunkSize < fileData.length) ? offset + _maxChunkSize : fileData.length;
          final packetSize = header.length + (end - offset);
          final packet = Uint8List(packetSize);
          
          packet.setRange(0, header.length, header);
          packet.setRange(header.length, packetSize, fileData, offset);
          
          packets.add(packet);
          offset = end;
        }
        
        _log('📦 文件 ${file.lengthSync()} 字节 -> ${packets.length} 个预构建包');
      }
    }
    
    _prebuiltPackets = packets;
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
    
    _log('🚀 [Isolate] 准备启动极速本地回环: $_cachedFileName (速度级别: $_speedLevel)');
    
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
          prebuiltPackets: _prebuiltPackets,
          address: _loopbackAddress,
          port: _loopbackPort,
          initialLoopCount: _loopCount,
          speedLevel: _speedLevel,
          batchCount: _batchCount,
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
      
      // 根据速度级别调整发送间隔
      final intervalMs = switch (_speedLevel) {
        LoopbackSpeedLevel.extreme => 1,  // 1ms - 极致速度
        LoopbackSpeedLevel.high => 10,    // 10ms
        LoopbackSpeedLevel.normal => 50,  // 50ms
      };
      
      // 使用 Timer.periodic 在主线程执行
      _mainThreadTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
        if (!_isRunning || _currentMode != LoopbackRunMode.mainThread) {
          timer.cancel();
          return;
        }
        
        try {
          // 批量发送
          for (int batch = 0; batch < _batchCount; batch++) {
            _loopCount++;
            
            // 使用预构建包发送
            if (_prebuiltPackets != null && _prebuiltPackets!.isNotEmpty) {
              for (final packet in _prebuiltPackets!) {
                _mainThreadSocket?.send(packet, address, _loopbackPort);
              }
            }
          }
          
          // 发送心跳
          final now = DateTime.now();
          if (now.difference(lastHeartbeat) >= heartbeatInterval) {
            onHeartbeat?.call(_loopCount);
            lastHeartbeat = now;
          }
        } catch (e) {
          _log('⚠️ [MainThread] 发送异常: $e');
        }
      });
    } catch (e) {
      _log('❌ 启动主线程模式失败: $e');
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
    final prebuiltPackets = params.prebuiltPackets;
    final batchCount = params.batchCount;
    
    // Heartbeat tracking - 从传入的初始值开始
    int loopCount = params.initialLoopCount;
    DateTime lastHeartbeat = DateTime.now();
    const heartbeatInterval = Duration(seconds: 2);
    
    // 根据速度级别确定延迟
    final delayMicroseconds = switch (params.speedLevel) {
      LoopbackSpeedLevel.extreme => 0,    // 极致：无延迟
      LoopbackSpeedLevel.high => 100,     // 高速：100微秒
      LoopbackSpeedLevel.normal => 1000,  // 普通：1毫秒
    };
    
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      
      // 极致优化：设置发送缓冲区大小
      // socket.setOption(SocketOption(O_SO_SNDBUF), 1024 * 1024); // 1MB发送缓冲区
      
      sendPort.send('✨ [Worker] 极速发送引擎初始化完成 (速度级别: ${params.speedLevel})');
      
      // 检查是否有预构建包
      if (prebuiltPackets == null || prebuiltPackets.isEmpty) {
        sendPort.send('⚠️ [Worker] 无预构建数据包');
        return;
      }
      
      sendPort.send('🔥 [Worker] 开始极速回环: ${prebuiltPackets.length} 包/轮 x $batchCount 批');
      
      // 极速流式回环发送 - 无延迟版本
      while (true) {
        // 批量发送多轮
        for (int batch = 0; batch < batchCount; batch++) {
          loopCount++;
          
          // 发送所有预构建包
          for (int i = 0; i < prebuiltPackets.length; i++) {
            socket.send(prebuiltPackets[i], address, port);
          }
        }
        
        // Send heartbeat to main thread every 2 seconds
        final now = DateTime.now();
        if (now.difference(lastHeartbeat) >= heartbeatInterval) {
          sendPort.send({'type': 'heartbeat', 'loopCount': loopCount, 'timestamp': now.toIso8601String()});
          lastHeartbeat = now;
        }
        
        // 根据速度级别决定是否延迟
        if (delayMicroseconds > 0) {
          // 使用微秒级延迟
          await Future.delayed(Duration(microseconds: delayMicroseconds));
        } else {
          // 极致模式：让出CPU一个调度周期，避免完全卡死
          await Future.delayed(Duration.zero);
        }
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
    _prebuiltPackets = null;
    
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
      'mode': 'extreme_speed',
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
  final List<Uint8List>? prebuiltPackets;
  final String address;
  final int port;
  final int initialLoopCount;
  final LoopbackSpeedLevel speedLevel;
  final int batchCount;

  _IsolateParams({
    required this.sendPort,
    required this.headerPacket,
    this.prebuiltPackets,
    required this.address,
    required this.port,
    this.initialLoopCount = 0,
    this.speedLevel = LoopbackSpeedLevel.extreme,
    this.batchCount = 10,
  });
}
