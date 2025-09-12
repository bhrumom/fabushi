import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class WifiBroadcastService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;

  bool _isRunning = false;

  WifiBroadcastService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
  });

  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isWeb,
    required bool isLoop,
  }) async {
    debugPrint('📶 WiFi广播服务已停止');
    onStopped();
  }

  void stopSending() {
    _isRunning = false;
  }
}