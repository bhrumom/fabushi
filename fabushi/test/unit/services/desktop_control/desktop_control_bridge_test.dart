import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/desktop_control/desktop_control_bridge.dart';
import 'package:global_dharma_sharing/services/desktop_control/desktop_control_host_api.dart';
import 'package:global_dharma_sharing/services/desktop_control/desktop_control_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop read-only tools run without confirmation', () async {
    final host = _FakeDesktopControlHostApi();
    final bridge = DesktopControlBridge.test(
      hostApi: host,
      enabledByBuild: () => true,
      platformProvider: () => 'macos',
      random: Random(1),
    );

    final result = await bridge.executeTool('desktop.windows', const {});

    expect(result.ok, isTrue);
    expect(result.requiresConfirmation, isFalse);
    expect(result.data['windows'], isA<List<dynamic>>());
    expect(host.calls, ['windows']);
  });

  test(
    'mutating desktop tools require explicit approval before execution',
    () async {
      final host = _FakeDesktopControlHostApi();
      final bridge = DesktopControlBridge.test(
        hostApi: host,
        enabledByBuild: () => true,
        platformProvider: () => 'macos',
        random: Random(2),
      );
      final arguments = {'x': 10, 'y': 20};

      final first = await bridge.executeTool('desktop.click', arguments);

      expect(first.ok, isFalse);
      expect(first.requiresConfirmation, isTrue);
      expect(first.pendingConfirmationId, isNotEmpty);
      expect(host.calls, isEmpty);

      await bridge.approvePendingRequest(first.pendingConfirmationId!);
      final second = await bridge.executeTool(
        'desktop.click',
        arguments,
        confirmationId: first.pendingConfirmationId,
      );

      expect(second.ok, isTrue);
      expect(second.data['clicked'], isTrue);
      expect(host.calls, ['click']);
    },
  );

  test('rejected desktop confirmations do not execute the action', () async {
    final host = _FakeDesktopControlHostApi();
    final bridge = DesktopControlBridge.test(
      hostApi: host,
      enabledByBuild: () => true,
      platformProvider: () => 'macos',
      random: Random(3),
    );
    final arguments = {'text': 'hello'};

    final first = await bridge.executeTool('desktop.type', arguments);
    await bridge.rejectPendingRequest(first.pendingConfirmationId!);
    final second = await bridge.executeTool(
      'desktop.type',
      arguments,
      confirmationId: first.pendingConfirmationId,
    );

    expect(second.requiresConfirmation, isTrue);
    expect(host.calls, isEmpty);
  });

  test('non-macOS desktop tools return unsupported platform', () async {
    final bridge = DesktopControlBridge.test(
      hostApi: _FakeDesktopControlHostApi(),
      enabledByBuild: () => true,
      platformProvider: () => 'windows',
      random: Random(4),
    );

    final result = await bridge.executeTool('desktop.windows', const {});

    expect(result.ok, isFalse);
    expect(result.errorCode, 'unsupported_platform');
    expect(result.message, contains('windows'));
  });

  test(
    'Chrome tools report recoverable connector state when disconnected',
    () async {
      final bridge = DesktopControlBridge.test(
        hostApi: _FakeDesktopControlHostApi(),
        enabledByBuild: () => true,
        platformProvider: () => 'macos',
        random: Random(5),
      );

      final result = await bridge.executeTool('chrome.tabs', const {});

      expect(result.ok, isFalse);
      expect(result.errorCode, 'chrome_connector_not_connected');
      expect(result.recoverable, isTrue);
    },
  );

  test('build flag disables all desktop and Chrome tools', () async {
    final bridge = DesktopControlBridge.test(
      hostApi: _FakeDesktopControlHostApi(),
      enabledByBuild: () => false,
      platformProvider: () => 'macos',
      random: Random(6),
    );

    final status = await bridge.getStatus();
    final result = await bridge.executeTool('chrome.tabs', const {});

    expect(status.enabledByBuild, isFalse);
    expect(result.ok, isFalse);
    expect(result.errorCode, 'disabled_by_build');
  });

  test('tool policy exposes the expected migration surface', () {
    expect(
      DesktopControlPolicy.supportedTools,
      containsAll({
        'desktop.observe',
        'desktop.screenshot',
        'desktop.windows',
        'desktop.click',
        'desktop.type',
        'desktop.hotkey',
        'desktop.scroll',
        'chrome.tabs',
        'chrome.navigate',
        'chrome.dom_snapshot',
        'chrome.screenshot',
        'chrome.click',
        'chrome.type',
      }),
    );
    expect(DesktopControlPolicy.isReadOnly('desktop.screenshot'), isTrue);
    expect(DesktopControlPolicy.requiresConfirmation('chrome.type'), isTrue);
  });
}

class _FakeDesktopControlHostApi implements DesktopControlHostApi {
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> status() async => {
    'screenRecordingGranted': true,
    'accessibilityGranted': true,
  };

  @override
  Future<Map<String, dynamic>> observe() async {
    calls.add('observe');
    return {'activeApplication': 'Test'};
  }

  @override
  Future<Map<String, dynamic>> screenshot(
    Map<String, dynamic> arguments,
  ) async {
    calls.add('screenshot');
    return {'format': 'png', 'base64': ''};
  }

  @override
  Future<Map<String, dynamic>> windows() async {
    calls.add('windows');
    return {
      'windows': [
        {'ownerName': 'Finder', 'windowName': 'Desktop'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> click(Map<String, dynamic> arguments) async {
    calls.add('click');
    return {'clicked': true};
  }

  @override
  Future<Map<String, dynamic>> type(Map<String, dynamic> arguments) async {
    calls.add('type');
    return {'typed': true};
  }

  @override
  Future<Map<String, dynamic>> hotkey(Map<String, dynamic> arguments) async {
    calls.add('hotkey');
    return {'hotkey': arguments['keys']};
  }

  @override
  Future<Map<String, dynamic>> scroll(Map<String, dynamic> arguments) async {
    calls.add('scroll');
    return {'scrolled': true};
  }
}
