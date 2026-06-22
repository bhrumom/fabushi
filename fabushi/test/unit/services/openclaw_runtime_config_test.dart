import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/desktop_control/desktop_control_policy.dart';
import 'package:global_dharma_sharing/services/openclaw/openclaw_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenClaw embedded config', () {
    test('uses plugin-scoped Canvas host config and allows desktop tools', () {
      final stateRoot = Directory.systemTemp.createTempSync(
        'openclaw-config-test-',
      );
      addTearDown(() async {
        if (await stateRoot.exists()) {
          await stateRoot.delete(recursive: true);
        }
      });

      final config = OpenClawRuntime.instance.buildEmbeddedConfigForTest(
        stateRoot: stateRoot,
        port: 18789,
        token: 'test-token',
        backendDeepSeekModel: 'dacheng-deepseek-proxy/deepseek-chat',
        deepSeekProxyBaseUrl: 'https://api.example.test/v1',
        pluginLoadPaths: ['/tmp/dacheng-desktop-tools'],
      );

      expect(config.containsKey('canvas'), isFalse);
      expect(config.containsKey('canvasHost'), isFalse);

      final tools = _map(config['tools']);
      expect(tools['profile'], 'full');
      expect(
        _strings(tools['alsoAllow']),
        containsAll({'chrome.navigate', 'chrome.click', 'desktop.click'}),
      );
      expect(
        _strings(tools['alsoAllow']),
        containsAll(DesktopControlPolicy.supportedTools),
      );

      final exec = _map(tools['exec']);
      expect(exec['host'], 'gateway');
      expect(exec['security'], 'full');
      expect(exec['ask'], 'off');
      expect(exec.containsKey('mode'), isFalse);

      final plugins = _map(config['plugins']);
      final entries = _map(plugins['entries']);
      final canvas = _map(entries['canvas']);
      expect(canvas['enabled'], isTrue);
      expect(_map(_map(canvas['config'])['host']), {
        'enabled': true,
        'root': '${stateRoot.path}/canvas',
      });
    });

    test('repairs legacy invalid config before gateway startup', () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'openclaw-config-merge-test-',
      );
      addTearDown(() async {
        if (await stateRoot.exists()) {
          await stateRoot.delete(recursive: true);
        }
      });
      final configPath = File('${stateRoot.path}/openclaw.json');
      await configPath.writeAsString(
        jsonEncode({
          'canvas': {
            'enabled': true,
            'host': {'enabled': true},
          },
          'canvasHost': {'enabled': true},
          'tools': {
            'toolSearch': 'invalid',
            'fs': {'workspaceOnly': true},
            'alsoAllow': ['custom.localTool'],
            'exec': {'mode': 'full', 'security': 'full', 'ask': 'off'},
          },
          'plugins': {
            'enabled': false,
            'deny': ['dacheng-desktop-tools', 'user-disabled-plugin'],
            'entries': {
              'canvas': {'enabled': false},
              'dacheng-desktop-tools': {'enabled': false},
            },
          },
        }),
      );

      final defaults = OpenClawRuntime.instance.buildEmbeddedConfigForTest(
        stateRoot: stateRoot,
        port: 18790,
        token: 'test-token',
        backendDeepSeekModel: 'dacheng-deepseek-proxy/deepseek-chat',
        deepSeekProxyBaseUrl: 'https://api.example.test/v1',
        pluginLoadPaths: ['/tmp/dacheng-desktop-tools'],
      );
      final merged = await OpenClawRuntime.instance.mergeEmbeddedConfigForTest(
        configPath,
        defaults,
      );

      expect(merged.containsKey('canvas'), isFalse);
      expect(merged.containsKey('canvasHost'), isFalse);

      final tools = _map(merged['tools']);
      expect(tools.containsKey('toolSearch'), isFalse);
      expect(tools.containsKey('fs'), isFalse);
      expect(_map(tools['exec']).containsKey('mode'), isFalse);
      expect(_strings(tools['alsoAllow']), contains('custom.localTool'));
      expect(
        _strings(tools['alsoAllow']),
        containsAll(DesktopControlPolicy.supportedTools),
      );

      final plugins = _map(merged['plugins']);
      expect(plugins['enabled'], isTrue);
      expect(
        _strings(plugins['deny']),
        allOf(
          isNot(contains('dacheng-desktop-tools')),
          contains('user-disabled-plugin'),
        ),
      );

      final entries = _map(plugins['entries']);
      expect(_map(entries['dacheng-desktop-tools'])['enabled'], isTrue);
      final canvas = _map(entries['canvas']);
      expect(canvas['enabled'], isTrue);
      expect(_map(_map(canvas['config'])['host'])['root'], endsWith('/canvas'));
    });

    test('disables inherited Node compile cache for embedded runtime', () {
      final stateRoot = Directory.systemTemp.createTempSync(
        'openclaw-env-test-',
      );
      final runtimeDir = Directory('${stateRoot.path}/runtime')
        ..createSync(recursive: true);
      final configPath = File('${stateRoot.path}/openclaw.json');
      addTearDown(() async {
        if (await stateRoot.exists()) {
          await stateRoot.delete(recursive: true);
        }
      });

      final env = OpenClawRuntime.instance.buildOpenClawEnvironmentForTest(
        runtimeDir: runtimeDir,
        stateRoot: stateRoot,
        configPath: configPath,
        port: 18791,
        token: 'test-token',
      );

      expect(env['NODE_DISABLE_COMPILE_CACHE'], '1');
      expect(env.containsKey('NODE_COMPILE_CACHE'), isFalse);
      expect(env['OPENCLAW_CONFIG_PATH'], configPath.path);
    });
  });
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<String> _strings(Object? value) {
  if (value is! Iterable) return <String>[];
  return value.map((item) => item.toString()).toList();
}
