import 'dart:async';

import 'desktop_control_models.dart';

class DesktopControlBridge {
  DesktopControlBridge._();

  DesktopControlBridge.test({
    Object? hostApi,
    Object? confirmations,
    bool Function()? enabledByBuild,
    String Function()? platformProvider,
    Object? random,
  });

  static final DesktopControlBridge instance = DesktopControlBridge._();

  Stream<void> get confirmationsChanged => const Stream<void>.empty();

  Future<String?> get bridgeToken => Future.value();

  Future<DesktopControlBridgeStatus> getStatus() async {
    return DesktopControlBridgeStatus(
      enabledByBuild: false,
      supportedPlatform: false,
      bridgeRunning: false,
      platform: 'web',
      message: '当前平台不支持系统级电脑控制',
      screenRecordingGranted: false,
      accessibilityGranted: false,
      chrome: ChromeConnectorStatus.disconnected(),
    );
  }

  Future<DesktopControlBridgeStatus> ensureStarted() => getStatus();

  Future<DesktopControlToolResult> executeTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? confirmationId,
  }) async {
    return DesktopControlToolResult.failure(
      errorCode: 'unsupported_platform',
      message: '当前平台不支持系统级电脑控制',
    );
  }

  Future<List<DesktopControlPendingConfirmation>> pendingConfirmations() async {
    return const [];
  }

  Future<DesktopControlPendingConfirmation?> approvePendingRequest(String id) {
    return Future.value();
  }

  Future<DesktopControlPendingConfirmation?> rejectPendingRequest(String id) {
    return Future.value();
  }

  Future<String?> prepareChromeConnectorInstall() => Future.value();
}
