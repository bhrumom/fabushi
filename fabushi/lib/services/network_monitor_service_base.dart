import 'dart:async';
import 'package:flutter/foundation.dart';

class NetworkStats {
  final double uploadSpeed; // KB/s
  final double downloadSpeed; // KB/s
  final double totalUploaded; // MB
  final double totalDownloaded; // MB
  final int latency; // ms
  final String connectionType;
  final bool isOnline;

  NetworkStats({
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.totalUploaded,
    required this.totalDownloaded,
    required this.latency,
    required this.connectionType,
    required this.isOnline,
  });

  @override
  String toString() {
    return 'NetworkStats(upload: ${uploadSpeed.toStringAsFixed(1)} KB/s, '
        'download: ${downloadSpeed.toStringAsFixed(1)} KB/s, '
        'latency: ${latency}ms, type: $connectionType, online: $isOnline)';
  }
}

abstract class NetworkMonitorService {
  Stream<NetworkStats> get networkStatsStream;
  NetworkStats get currentStats;
  bool get isOnline;

  Future<void> startMonitoring();
  Future<void> stopMonitoring();
  Future<double> measureLatency();
  Future<double> measureDownloadSpeed();
  Future<double> measureUploadSpeed();
}

// 默认实现（用于非Web平台）
class DefaultNetworkMonitorService implements NetworkMonitorService {
  final StreamController<NetworkStats> _statsController =
      StreamController<NetworkStats>.broadcast();
  Timer? _monitoringTimer;

  NetworkStats _currentStats = NetworkStats(
    uploadSpeed: 0,
    downloadSpeed: 0,
    totalUploaded: 0,
    totalDownloaded: 0,
    latency: 0,
    connectionType: 'unknown',
    isOnline: true,
  );

  @override
  Stream<NetworkStats> get networkStatsStream => _statsController.stream;

  @override
  NetworkStats get currentStats => _currentStats;

  @override
  bool get isOnline => _currentStats.isOnline;

  @override
  Future<void> startMonitoring() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final latency = await measureLatency();
        final downloadSpeed = await measureDownloadSpeed();

        _currentStats = NetworkStats(
          uploadSpeed: 0, // 简化实现
          downloadSpeed: downloadSpeed,
          totalUploaded: _currentStats.totalUploaded,
          totalDownloaded:
              _currentStats.totalDownloaded + (downloadSpeed * 5 / 1024), // 估算
          latency: latency.round(),
          connectionType: 'mobile/wifi',
          isOnline: latency > 0,
        );

        _statsController.add(_currentStats);
      } catch (e) {
        debugPrint('Network monitoring error: $e');
      }
    });
  }

  @override
  Future<void> stopMonitoring() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  @override
  Future<double> measureLatency() async {
    // 简化的延迟测量
    final stopwatch = Stopwatch()..start();
    try {
      // 这里可以添加实际的网络请求来测量延迟
      await Future.delayed(Duration(milliseconds: 50)); // 模拟网络延迟
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds.toDouble();
    } catch (e) {
      return -1; // 表示离线
    }
  }

  @override
  Future<double> measureDownloadSpeed() async {
    // 简化的下载速度测量
    return 1000.0; // 返回固定值 1MB/s
  }

  @override
  Future<double> measureUploadSpeed() async {
    // 简化的上传速度测量
    return 500.0; // 返回固定值 500KB/s
  }

  void dispose() {
    stopMonitoring();
    _statsController.close();
  }
}
