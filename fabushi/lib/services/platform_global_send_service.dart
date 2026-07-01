import 'package:flutter/foundation.dart' show ValueChanged, VoidCallback;
import 'package:file_picker/file_picker.dart';

/// Deprecated compatibility shim.
///
/// Global Dharma delivery orchestration has moved out of the Flutter host and
/// into the official Global Dharma mini app. The host should expose only system
/// capability primitives such as `network.http.fetch`, `network.udp.open`,
/// `network.udp.send`, `network.udp.broadcast`, `network.udp.close`, files, and
/// keep-awake. Mini apps decide how to schedule real delivery.
///
/// This shim intentionally does not perform HTTP/UDP global delivery from the
/// host. It keeps older call sites from crashing while they are migrated to open
/// the mini app command surface.
@Deprecated('Global Dharma sending is owned by the mini app. Use host capability primitives instead.')
class PlatformGlobalSendService {
  PlatformGlobalSendService({
    required this.onProgress,
    required this.onDataSent,
    this.onCountryProgress,
    required this.onStopped,
    required this.onLog,
    this.onTransferBeam,
    this.onCountrySent,
    this.onLoopStart,
    double? userLatitude,
    double? userLongitude,
  });

  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final ValueChanged<double>? onCountryProgress;
  final VoidCallback onStopped;
  final void Function(String) onLog;
  final Function(
    double,
    double,
    double,
    double, {
    String? fromLabel,
    String? toLabel,
    Duration? displayDuration,
  })?
  onTransferBeam;
  final Function(int)? onCountrySent;
  final Function(int)? onLoopStart;

  bool _isRunning = false;

  String get sendMode => 'mini_app_capability_bridge';

  Future<bool> initialize() async {
    onLog('全球法布施调度已迁移到小程序；宿主仅提供系统能力原语。');
    return true;
  }

  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
    List<String>? countryCodes,
  }) async {
    _isRunning = true;
    onLoopStart?.call(1);
    onProgress(0);
    onDataSent(0);
    onCountryProgress?.call(0);
    onLog(
      '已阻止宿主侧全球发送：请通过全球法布施小程序调用 network.http.fetch / network.udp.* 系统能力执行真实发送。',
    );
    _isRunning = false;
    onStopped();
  }

  void stopSending() {
    if (!_isRunning) return;
    _isRunning = false;
    onLog('宿主侧兼容发送器已停止。');
    onStopped();
  }

  bool get isRunning => _isRunning;
}
