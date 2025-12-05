import 'package:flutter/foundation.dart' show kIsWeb, ValueChanged, VoidCallback;
import 'package:file_picker/file_picker.dart';
import 'real_global_send_service.dart';
import 'udp_global_send_service.dart';

/// 平台自适应全球发送服务
/// - Web 平台：使用 HTTP 发送
/// - 其他平台（iOS/Android/macOS）：使用 UDP 基于 GeoLite2 IP 发送
class PlatformGlobalSendService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;
  final void Function(String) onLog;
  final Function(double, double, double, double, {String? fromLabel, String? toLabel, Duration? displayDuration})? onTransferBeam;
  final Function(int)? onCountrySent;
  final Function(int)? onLoopStart;  // 每轮循环开始时的回调，参数为轮次

  double? _userLatitude;
  double? _userLongitude;

  // 内部服务实例
  RealGlobalSendService? _httpService;
  UDPGlobalSendService? _udpService;

  bool _isInitialized = false;

  PlatformGlobalSendService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
    required this.onLog,
    this.onTransferBeam,
    this.onCountrySent,
    this.onLoopStart,
    double? userLatitude,
    double? userLongitude,
  }) {
    _userLatitude = userLatitude;
    _userLongitude = userLongitude;
  }

  /// 获取当前使用的发送模式
  String get sendMode => kIsWeb ? 'HTTP' : 'UDP';

  /// 初始化服务
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (kIsWeb) {
        // Web 平台使用 HTTP
        onLog('🌐 Web 平台 - 使用 HTTP 全球发送');
        _httpService = RealGlobalSendService(
          onProgress: onProgress,
          onDataSent: onDataSent,
          onStopped: onStopped,
          onLog: onLog,
          onTransferBeam: onTransferBeam,
          onCountrySent: onCountrySent,
          onLoopStart: onLoopStart,
          userLatitude: _userLatitude,
          userLongitude: _userLongitude,
        );
        final success = await _httpService!.initialize();
        _isInitialized = success;
        return success;
      } else {
        // 其他平台使用 UDP
        onLog('📱 原生平台 - 使用 UDP 全球发送 (GeoLite2 IP)');
        _udpService = UDPGlobalSendService(
          onProgress: onProgress,
          onDataSent: onDataSent,
          onStopped: onStopped,
          onLog: onLog,
          onTransferBeam: onTransferBeam,
          onCountrySent: onCountrySent,
          onLoopStart: onLoopStart,
          userLatitude: _userLatitude,
          userLongitude: _userLongitude,
        );
        final success = await _udpService!.initialize();
        _isInitialized = success;
        return success;
      }
    } catch (e) {
      onLog('❌ 平台发送服务初始化失败: $e');
      return false;
    }
  }

  /// 开始发送
  Future<void> startSending({required List<PlatformFile> files, required bool isLoop}) async {
    if (!_isInitialized) {
      onLog('⚠️ 服务未初始化，正在初始化...');
      await initialize();
    }

    if (kIsWeb) {
      await _httpService?.startSending(files: files, isLoop: isLoop);
    } else {
      await _udpService?.startSending(files: files, isLoop: isLoop);
    }
  }

  /// 停止发送
  void stopSending() {
    if (kIsWeb) {
      _httpService?.stopSending();
    } else {
      _udpService?.stopSending();
    }
  }

  /// 是否正在运行
  bool get isRunning {
    if (kIsWeb) {
      return _httpService?.isRunning ?? false;
    } else {
      return _udpService?.isRunning ?? false;
    }
  }
}
