import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'network_monitor_service_base.dart';

// 简化的网络监控服务，兼容所有平台
class NetworkMonitorService extends DefaultNetworkMonitorService {
  static NetworkMonitorService? _instance;
  
  NetworkMonitorService._() : super();
  
  static NetworkMonitorService get instance {
    _instance ??= NetworkMonitorService._();
    return _instance!;
  }

  // 添加构造函数以支持直接实例化
  NetworkMonitorService() : super();

  @override
  Future<double> measureLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      // 简化的延迟测量 - 使用随机值模拟
      final random = Random();
      final simulatedLatency = 20 + random.nextInt(80); // 20-100ms
      await Future.delayed(Duration(milliseconds: simulatedLatency));
      stopwatch.stop();
      return simulatedLatency.toDouble();
    } catch (e) {
      return -1; // 表示离线
    }
  }

  @override
  Future<double> measureDownloadSpeed() async {
    // 模拟下载速度测量
    final random = Random();
    return 500 + random.nextDouble() * 1500; // 500-2000 KB/s
  }

  @override
  Future<double> measureUploadSpeed() async {
    // 模拟上传速度测量
    final random = Random();
    return 200 + random.nextDouble() * 800; // 200-1000 KB/s
  }

  // 获取连接类型（简化版本）
  String getConnectionType() {
    if (kIsWeb) {
      return 'web';
    } else if (defaultTargetPlatform == TargetPlatform.iOS || 
               defaultTargetPlatform == TargetPlatform.android) {
      return 'mobile';
    } else {
      return 'desktop';
    }
  }

  @override
  Future<void> startMonitoring() async {
    await super.startMonitoring();
  }
}