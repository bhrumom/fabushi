import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Wi-Fi 场能广播服务
/// 无网场能模式 - 通过 Wi-Fi/热点向周围空间广播数据
///
/// 工作原理：
/// 1. 如果设备已连接 Wi-Fi：向同一网络内的所有设备广播
/// 2. 如果设备开启了热点：向连接热点的所有设备广播
/// 3. 同时向多播地址发送，覆盖更广范围
///
/// 使用场景：
/// - 在寺庙、禅修中心等场所，开启热点后向周围空间发送经文能量
/// - 多人共修时，一人发送，周围设备可接收
/// - 类似 UDP 广播，无需建立连接，直接向空间"辐射"
///
/// 注意：要实现真正的"无网"广播，需要手动开启设备的 Wi-Fi 热点功能
class WiFiFieldBroadcastService {
  static const int _broadcastPort = 8888;
  static const int _multicastPort = 8889;
  static const String _multicastGroup = '239.255.255.250'; // 标准多播地址

  // 常用热点网段
  static const List<String> _hotspotBroadcasts = [
    '172.20.10.255', // iOS 热点默认网段
    '192.168.43.255', // Android 热点默认网段
    '192.168.49.255', // Android 热点备用网段
    '10.0.0.255', // 部分设备热点网段
  ];

  RawDatagramSocket? _socket;
  bool _isRunning = false;
  Timer? _broadcastTimer;

  final void Function(String)? onLog;
  final void Function(int)? onBroadcastCount;

  int _broadcastCount = 0;

  WiFiFieldBroadcastService({this.onLog, this.onBroadcastCount});

  /// 初始化广播服务
  Future<bool> initialize() async {
    try {
      // 创建 UDP socket 用于广播
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: true,
      );

      // 启用广播
      _socket!.broadcastEnabled = true;

      _log('✨ 场能广播服务初始化完成');
      return true;
    } catch (e) {
      _log('❌ 场能广播服务初始化失败: $e');
      return false;
    }
  }

  /// 开始场能广播
  /// [data] 要广播的数据（经文内容）
  /// [fileName] 文件名
  Future<void> startBroadcast({
    required Uint8List data,
    required String fileName,
  }) async {
    if (_isRunning) return;
    if (_socket == null) {
      await initialize();
    }

    _isRunning = true;
    _broadcastCount = 0;

    _log('🌟 开始场能广播: $fileName');

    // 构建广播数据包
    final packet = _buildBroadcastPacket(data, fileName);

    // 获取所有可用的网络接口地址
    final broadcastAddresses = await _getBroadcastAddresses();

    _log('📡 发现 ${broadcastAddresses.length} 个广播地址');

    // 定时广播
    _broadcastTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _sendBroadcast(packet, broadcastAddresses),
    );

    // 立即发送一次
    _sendBroadcast(packet, broadcastAddresses);
  }

  /// 发送单次广播
  void _sendBroadcast(Uint8List packet, List<InternetAddress> addresses) {
    if (!_isRunning || _socket == null) return;

    try {
      // 向所有广播地址发送
      for (final address in addresses) {
        _socket!.send(packet, address, _broadcastPort);
      }

      // 向多播组发送
      try {
        final multicastAddr = InternetAddress(_multicastGroup);
        _socket!.send(packet, multicastAddr, _multicastPort);
      } catch (e) {
        // 多播可能不支持，忽略错误
      }

      // 向本地广播地址发送
      try {
        final localBroadcast = InternetAddress('255.255.255.255');
        _socket!.send(packet, localBroadcast, _broadcastPort);
      } catch (e) {
        // 忽略错误
      }

      _broadcastCount++;
      onBroadcastCount?.call(_broadcastCount);

      if (_broadcastCount % 10 == 0) {
        _log('📡 已广播 $_broadcastCount 次');
      }
    } catch (e) {
      _log('⚠️ 广播发送失败: $e');
    }
  }

  /// 停止广播
  void stopBroadcast() {
    _isRunning = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _log('🛑 场能广播已停止，共广播 $_broadcastCount 次');
  }

  /// 释放资源
  void dispose() {
    stopBroadcast();
    _socket?.close();
    _socket = null;
  }

  /// 构建广播数据包
  Uint8List _buildBroadcastPacket(Uint8List data, String fileName) {
    final header = {
      'type': 'dharma_field_energy',
      'fileName': fileName,
      'timestamp': DateTime.now().toIso8601String(),
      'size': data.length,
      'checksum': _calculateChecksum(data),
    };

    final headerJson = jsonEncode(header);
    final headerBytes = utf8.encode(headerJson);

    // 数据包格式: [4字节头部长度][头部JSON][数据]
    final packet = BytesBuilder();

    // 头部长度 (4 字节)
    packet.add(_intToBytes(headerBytes.length));

    // 头部
    packet.add(headerBytes);

    // 数据（如果太大则截取前1400字节）
    if (data.length > 1400) {
      packet.add(data.sublist(0, 1400));
    } else {
      packet.add(data);
    }

    return packet.toBytes();
  }

  /// 获取所有广播地址
  Future<List<InternetAddress>> _getBroadcastAddresses() async {
    final addresses = <InternetAddress>[];

    try {
      final interfaces = await NetworkInterface.list();

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            // 计算广播地址
            final broadcastAddr = _calculateBroadcastAddress(addr.address);
            if (broadcastAddr != null) {
              addresses.add(InternetAddress(broadcastAddr));
              _log(
                '📍 接口 ${interface.name}: ${addr.address} -> $broadcastAddr',
              );
            }
          }
        }
      }
    } catch (e) {
      _log('⚠️ 获取网络接口失败: $e');
    }

    // 添加热点常用网段的广播地址
    for (final hotspotAddr in _hotspotBroadcasts) {
      try {
        final addr = InternetAddress(hotspotAddr);
        if (!addresses.any((a) => a.address == hotspotAddr)) {
          addresses.add(addr);
          _log('📱 添加热点广播地址: $hotspotAddr');
        }
      } catch (e) {
        // 忽略无效地址
      }
    }

    // 添加默认广播地址
    final defaultAddrs = [
      '192.168.1.255',
      '192.168.0.255',
      '10.0.0.255',
      '172.16.0.255',
    ];

    for (final addr in defaultAddrs) {
      if (!addresses.any((a) => a.address == addr)) {
        try {
          addresses.add(InternetAddress(addr));
        } catch (e) {
          // 忽略
        }
      }
    }

    return addresses;
  }

  /// 计算广播地址（假设 /24 子网）
  String? _calculateBroadcastAddress(String ipAddress) {
    try {
      final parts = ipAddress.split('.');
      if (parts.length != 4) return null;

      // 简单处理：将最后一位设为 255
      return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    } catch (e) {
      return null;
    }
  }

  String _calculateChecksum(Uint8List data) {
    int sum = 0;
    for (final byte in data) {
      sum = (sum + byte) & 0xFFFFFFFF;
    }
    return sum.toRadixString(16);
  }

  Uint8List _intToBytes(int value) {
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.big);
  }

  void _log(String message) {
    debugPrint('[WiFiField] $message');
    onLog?.call(message);
  }

  bool get isRunning => _isRunning;
  int get broadcastCount => _broadcastCount;
}
