import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../app_settings.dart';
import '../diagnostic_log_service.dart';
import '../desktop_control/desktop_control_bridge.dart';
import '../desktop_control/desktop_control_policy.dart';

enum OpenClawRuntimeState {
  unsupported,
  notBundled,
  stopped,
  starting,
  running,
  failed,
}

class OpenClawRuntimeStatus {
  final OpenClawRuntimeState state;
  final String message;
  final int? port;
  final String? platformKey;
  final String? runtimePath;
  final Map<String, dynamic>? desktopToolsStatus;
  final DateTime checkedAt;

  const OpenClawRuntimeStatus({
    required this.state,
    required this.message,
    this.port,
    this.platformKey,
    this.runtimePath,
    this.desktopToolsStatus,
    required this.checkedAt,
  });

  bool get isHealthy => state == OpenClawRuntimeState.running;

  String get label {
    switch (state) {
      case OpenClawRuntimeState.unsupported:
        return '不支持';
      case OpenClawRuntimeState.notBundled:
        return '未内置';
      case OpenClawRuntimeState.stopped:
        return '未启动';
      case OpenClawRuntimeState.starting:
        return '启动中';
      case OpenClawRuntimeState.running:
        return '运行中';
      case OpenClawRuntimeState.failed:
        return '异常';
    }
  }
}

class OpenClawGatewayTarget {
  final Uri baseUri;
  final String token;
  final String model;
  final String? modelOverride;
  final Uri? desktopToolsUri;
  final String? desktopToolsToken;
  final Map<String, dynamic>? desktopToolsStatus;

  const OpenClawGatewayTarget({
    required this.baseUri,
    required this.token,
    required this.model,
    this.modelOverride,
    this.desktopToolsUri,
    this.desktopToolsToken,
    this.desktopToolsStatus,
  });
}

class _OpenClawBundleSpec {
  final String version;
  final int defaultPort;
  final String defaultModel;
  final String? defaultModelOverride;
  final String nodeExecutable;
  final String cliEntrypoint;
  final List<String> gatewayArgs;

  const _OpenClawBundleSpec({
    required this.version,
    required this.defaultPort,
    required this.defaultModel,
    this.defaultModelOverride,
    required this.nodeExecutable,
    required this.cliEntrypoint,
    required this.gatewayArgs,
  });
}

class _DesktopToolsLaunch {
  final Uri? uri;
  final String? token;
  final Map<String, dynamic> statusJson;

  const _DesktopToolsLaunch({
    required this.uri,
    required this.token,
    required this.statusJson,
  });
}

class OpenClawRuntimeException implements Exception {
  final String message;

  const OpenClawRuntimeException(this.message);

  @override
  String toString() => message;
}

class OpenClawRuntime {
  OpenClawRuntime._();

  static final OpenClawRuntime instance = OpenClawRuntime._();

  static const String _manifestAsset = 'assets/openclaw/bundle_manifest.json';
  static const Duration _startupTimeout = Duration(seconds: 45);
  static const Duration _probeTimeout = Duration(seconds: 3);

  Process? _process;
  Future<OpenClawGatewayTarget>? _starting;
  OpenClawRuntimeStatus? _lastStatus;
  final List<String> _recentLogs = <String>[];

  Future<OpenClawRuntimeStatus> getStatus({bool probe = true}) async {
    final platformKey = _platformKey;
    final port = await AppSettings.getOpenClawGatewayPort();
    _diag(
      'status.start',
      data: {'platformKey': platformKey, 'port': port, 'probe': probe},
    );

    if (platformKey == null) {
      return _remember(
        OpenClawRuntimeStatus(
          state: OpenClawRuntimeState.unsupported,
          message: '当前平台不是 macOS / Windows / Linux 桌面端',
          port: port,
          checkedAt: DateTime.now(),
        ),
      );
    }

    try {
      final spec = await _loadSpec(platformKey);
      final runtimeDir = await _runtimeDirForStatus(spec, platformKey);
      final nodePath = p.join(runtimeDir.path, spec.nodeExecutable);
      final cliPath = p.join(runtimeDir.path, spec.cliEntrypoint);
      final nodeExists = await File(nodePath).exists();
      final cliExists = await File(cliPath).exists();
      _diag(
        'status.paths',
        data: {
          'platformKey': platformKey,
          'runtimeDir': runtimeDir.path,
          'nodePath': nodePath,
          'nodeExists': nodeExists,
          'cliPath': cliPath,
          'cliExists': cliExists,
        },
      );

      if (!nodeExists || !cliExists) {
        final hasBundleAssets = await _hasRequiredBundleAssets(
          platformKey,
          spec,
        );
        _diag(
          'status.bundle-assets',
          data: {
            'platformKey': platformKey,
            'hasBundleAssets': hasBundleAssets,
            'nodeAsset': 'assets/openclaw/$platformKey/${spec.nodeExecutable}',
            'cliAsset': 'assets/openclaw/$platformKey/${spec.cliEntrypoint}',
          },
        );
        return _remember(
          OpenClawRuntimeStatus(
            state: hasBundleAssets
                ? OpenClawRuntimeState.stopped
                : OpenClawRuntimeState.notBundled,
            message: hasBundleAssets
                ? '内置 OpenClaw 已随 App 打包，尚未释放或启动'
                : '当前 App 包未包含 $platformKey 的 OpenClaw runtime',
            port: port,
            platformKey: platformKey,
            runtimePath: runtimeDir.path,
            checkedAt: DateTime.now(),
          ),
        );
      }

      if (probe) {
        final healthy = await _probe(
          port,
          await AppSettings.getOpenClawGatewayToken(),
        );
        if (healthy) {
          return _remember(
            OpenClawRuntimeStatus(
              state: OpenClawRuntimeState.running,
              message: '本机 OpenClaw Gateway 正在运行',
              port: port,
              platformKey: platformKey,
              runtimePath: runtimeDir.path,
              checkedAt: DateTime.now(),
            ),
          );
        }
      }

      return _remember(
        OpenClawRuntimeStatus(
          state: _process == null
              ? OpenClawRuntimeState.stopped
              : OpenClawRuntimeState.starting,
          message: _process == null ? '本机 OpenClaw 未启动' : '本机 OpenClaw 正在启动',
          port: port,
          platformKey: platformKey,
          runtimePath: runtimeDir.path,
          checkedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      _diag('status.error', error: error);
      return _remember(
        OpenClawRuntimeStatus(
          state: OpenClawRuntimeState.failed,
          message: error.toString(),
          port: port,
          platformKey: platformKey,
          checkedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<OpenClawGatewayTarget> ensureStarted({
    String? authToken,
    String? username,
    bool isMember = false,
  }) {
    _starting ??= _ensureStartedInternal(
      authToken: authToken,
      username: username,
      isMember: isMember,
    ).whenComplete(() => _starting = null);
    return _starting!;
  }

  Future<OpenClawRuntimeStatus> restart() async {
    await stop();
    try {
      await ensureStarted();
      return getStatus();
    } catch (error) {
      return _remember(
        OpenClawRuntimeStatus(
          state: OpenClawRuntimeState.failed,
          message: error.toString(),
          port: await AppSettings.getOpenClawGatewayPort(),
          platformKey: _platformKey,
          checkedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> stop() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      process.kill();
    }
  }

  Future<OpenClawGatewayTarget> _ensureStartedInternal({
    String? authToken,
    String? username,
    bool isMember = false,
  }) async {
    final platformKey = _platformKey;
    _diag('ensure-start.start', data: {'platformKey': platformKey});
    if (platformKey == null) {
      throw const OpenClawRuntimeException('当前平台不支持内置 OpenClaw Gateway');
    }

    final spec = await _loadSpec(platformKey);
    final port = await AppSettings.getOpenClawGatewayPort(
      defaultValue: spec.defaultPort,
    );
    final token = await AppSettings.getOpenClawGatewayToken();
    final model = await AppSettings.getOpenClawModel(
      defaultValue: spec.defaultModel,
    );
    final modelOverride = await AppSettings.getOpenClawModelOverride(
      defaultValue: spec.defaultModelOverride ?? '',
    );
    final desktopTools = await _ensureDesktopTools();
    _diag(
      'ensure-start.config',
      data: {
        'platformKey': platformKey,
        'port': port,
        'model': model,
        'modelOverrideSet': modelOverride.trim().isNotEmpty,
        'desktopToolsUri': desktopTools.uri?.toString(),
        'desktopToolsStatus': desktopTools.statusJson,
      },
    );

    if (await _probe(port, token, context: 'pre-start')) {
      _diag('ensure-start.reuse-existing', data: {'port': port});
      return OpenClawGatewayTarget(
        baseUri: Uri.parse('http://127.0.0.1:$port'),
        token: token,
        model: model,
        modelOverride: modelOverride.trim().isEmpty
            ? null
            : modelOverride.trim(),
        desktopToolsUri: desktopTools.uri,
        desktopToolsToken: desktopTools.token,
        desktopToolsStatus: desktopTools.statusJson,
      );
    }

    final runtimeDir = await _runtimeDirForLaunch(spec, platformKey);
    final stateRoot = await _stateRoot();
    final configPath = await _ensureConfigFile(
      stateRoot: stateRoot,
      port: port,
      token: token,
      model: model,
    );
    final desktopToolsManifestPath = await _ensureDesktopToolsManifest(
      stateRoot: stateRoot,
      desktopTools: desktopTools,
    );

    final nodePath = p.join(runtimeDir.path, spec.nodeExecutable);
    final cliPath = p.join(runtimeDir.path, spec.cliEntrypoint);
    if (!await File(nodePath).exists()) {
      _diag('ensure-start.missing-node', data: {'nodePath': nodePath});
      throw OpenClawRuntimeException('OpenClaw 内置 Node 不存在: $nodePath');
    }
    if (!await File(cliPath).exists()) {
      _diag('ensure-start.missing-cli', data: {'cliPath': cliPath});
      throw OpenClawRuntimeException('OpenClaw CLI 入口不存在: $cliPath');
    }

    _remember(
      OpenClawRuntimeStatus(
        state: OpenClawRuntimeState.starting,
        message: '正在启动内置 OpenClaw Gateway',
        port: port,
        platformKey: platformKey,
        runtimePath: runtimeDir.path,
        checkedAt: DateTime.now(),
      ),
    );

    final args = <String>[
      cliPath,
      ...spec.gatewayArgs.map((arg) => arg.replaceAll('{port}', '$port')),
    ];
    _diag(
      'process.starting',
      data: {
        'nodePath': nodePath,
        'args': args,
        'workingDirectory': runtimeDir.path,
        'configPath': configPath.path,
        'desktopToolsManifestPath': desktopToolsManifestPath.path,
      },
    );

    final deepSeekApiKey = _resolveDeepSeekApiKey();
    final deepSeekEnv = deepSeekApiKey == null
        ? null
        : <String, String>{'DEEPSEEK_API_KEY': deepSeekApiKey};
    final env = Map<String, String>.from(Platform.environment)
      ..addAll({
        'OPENCLAW_GATEWAY_PORT': '$port',
        'OPENCLAW_GATEWAY_BIND': 'loopback',
        'OPENCLAW_GATEWAY_TOKEN': token,
        'OPENCLAW_CONFIG_PATH': configPath.path,
        'OPENCLAW_STATE_DIR': p.join(stateRoot.path, 'state'),
        'OPENCLAW_AGENT_DIR': p.join(stateRoot.path, 'agents'),
        'OPENCLAW_WORKSPACE': p.join(stateRoot.path, 'workspace'),
        'DACHENG_DESKTOP_TOOLS_ENABLED': desktopTools.uri == null ? '0' : '1',
        'DACHENG_DESKTOP_TOOLS_MANIFEST': desktopToolsManifestPath.path,
        if (desktopTools.uri != null)
          'DACHENG_DESKTOP_TOOLS_URL': desktopTools.uri.toString(),
        if (desktopTools.token != null)
          'DACHENG_DESKTOP_TOOLS_TOKEN': desktopTools.token!,
        'DACHENG_APP_RUNTIME': '1',
        if (authToken != null && authToken.isNotEmpty)
          'DACHENG_AUTH_TOKEN': authToken,
        if (username != null && username.isNotEmpty)
          'DACHENG_USERNAME': username,
        'DACHENG_IS_MEMBER': isMember ? '1' : '0',
        ...?deepSeekEnv,
      });

    _process = await Process.start(
      nodePath,
      args,
      workingDirectory: runtimeDir.path,
      environment: env,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    _captureLogs(_process!);
    _diag('process.started', data: {'pid': _process!.pid, 'port': port});

    final deadline = DateTime.now().add(_startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _probe(port, token, context: 'startup')) {
        _diag('process.ready', data: {'pid': _process?.pid, 'port': port});
        _remember(
          OpenClawRuntimeStatus(
            state: OpenClawRuntimeState.running,
            message: '本机 OpenClaw Gateway 已启动',
            port: port,
            platformKey: platformKey,
            runtimePath: runtimeDir.path,
            desktopToolsStatus: desktopTools.statusJson,
            checkedAt: DateTime.now(),
          ),
        );
        return OpenClawGatewayTarget(
          baseUri: Uri.parse('http://127.0.0.1:$port'),
          token: token,
          model: model,
          modelOverride: modelOverride.trim().isEmpty
              ? null
              : modelOverride.trim(),
          desktopToolsUri: desktopTools.uri,
          desktopToolsToken: desktopTools.token,
          desktopToolsStatus: desktopTools.statusJson,
        );
      }

      if (_process != null) {
        final exited = await _process!.exitCode.timeout(
          const Duration(milliseconds: 1),
          onTimeout: () => -999999,
        );
        if (exited != -999999) {
          final logs = _recentLogs.take(12).join('\n');
          _diag(
            'process.exited-early',
            data: {
              'exitCode': exited,
              'recentLogs': _recentLogs.take(12).toList(),
            },
          );
          throw OpenClawRuntimeException(
            'OpenClaw Gateway 提前退出，exitCode=$exited${logs.isEmpty ? '' : '\n$logs'}',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    final logs = _recentLogs.take(12).join('\n');
    _diag(
      'process.startup-timeout',
      data: {
        'timeoutSeconds': _startupTimeout.inSeconds,
        'recentLogs': _recentLogs.take(12).toList(),
      },
    );
    throw OpenClawRuntimeException(
      'OpenClaw Gateway 启动超时${logs.isEmpty ? '' : '\n$logs'}',
    );
  }

  Future<_OpenClawBundleSpec> _loadSpec(String platformKey) async {
    final raw = await rootBundle.loadString(_manifestAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final platforms = Map<String, dynamic>.from(
      decoded['platforms'] as Map? ?? const {},
    );
    final platform = Map<String, dynamic>.from(
      platforms[platformKey] as Map? ?? const {},
    );
    if (platform.isEmpty) {
      throw OpenClawRuntimeException('bundle_manifest.json 缺少 $platformKey 配置');
    }

    final gatewayArgs =
        (platform['gatewayArgs'] as List? ??
                decoded['gatewayArgs'] as List? ??
                const ['gateway', '--port', '{port}'])
            .map((item) => item.toString())
            .toList();

    final spec = _OpenClawBundleSpec(
      version: (decoded['version'] ?? 'dev').toString(),
      defaultPort: _readInt(decoded['defaultPort']) ?? 18789,
      defaultModel: (decoded['defaultModel'] ?? 'deepseek/deepseek-chat')
          .toString(),
      defaultModelOverride: decoded['defaultModelOverride']?.toString(),
      nodeExecutable: (platform['nodeExecutable'] ?? 'node/bin/node')
          .toString(),
      cliEntrypoint: (platform['cliEntrypoint'] ?? 'openclaw/bin/openclaw.js')
          .toString(),
      gatewayArgs: gatewayArgs,
    );
    _diag(
      'manifest.loaded',
      data: {
        'platformKey': platformKey,
        'version': spec.version,
        'defaultPort': spec.defaultPort,
        'defaultModel': spec.defaultModel,
        'nodeExecutable': spec.nodeExecutable,
        'cliEntrypoint': spec.cliEntrypoint,
        'gatewayArgs': spec.gatewayArgs,
      },
    );
    return spec;
  }

  Future<Directory> _runtimeDirForStatus(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    final bundledRuntimeDir = await _bundledMacOSRuntimeDir(spec, platformKey);
    if (bundledRuntimeDir != null) return bundledRuntimeDir;
    return _runtimeDir(spec, platformKey);
  }

  Future<Directory> _runtimeDirForLaunch(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    final bundledRuntimeDir = await _bundledMacOSRuntimeDir(spec, platformKey);
    if (bundledRuntimeDir != null) {
      _diag(
        'bundle.launch.bundled-runtime',
        data: {
          'platformKey': platformKey,
          'runtimeDir': bundledRuntimeDir.path,
        },
      );
      return bundledRuntimeDir;
    }

    if (Platform.isMacOS && kReleaseMode) {
      final hasBundleAssets = await _hasRequiredBundleAssets(platformKey, spec);
      if (hasBundleAssets) {
        throw OpenClawRuntimeException(
          'macOS 沙盒要求从已签名的 App bundle 内启动 OpenClaw runtime，但未找到可执行的包内资源路径。请重新安装最新桌面版。',
        );
      }
    }

    return _prepareBundle(spec, platformKey);
  }

  Future<Directory?> _bundledMacOSRuntimeDir(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    if (!Platform.isMacOS) return null;

    final appBundle = _macOSAppBundleRoot();
    if (appBundle == null) {
      _diag('bundle.macos-app-root-missing');
      return null;
    }

    final candidates = <Directory>[
      Directory(
        p.join(
          appBundle.path,
          'Contents',
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
          'assets',
          'openclaw',
          platformKey,
        ),
      ),
      Directory(
        p.join(
          appBundle.path,
          'Contents',
          'Frameworks',
          'App.framework',
          'Versions',
          'A',
          'Resources',
          'flutter_assets',
          'assets',
          'openclaw',
          platformKey,
        ),
      ),
      Directory(
        p.join(
          appBundle.path,
          'Contents',
          'Resources',
          'flutter_assets',
          'assets',
          'openclaw',
          platformKey,
        ),
      ),
    ];

    for (final candidate in candidates) {
      final nodePath = File(p.join(candidate.path, spec.nodeExecutable));
      final cliPath = File(p.join(candidate.path, spec.cliEntrypoint));
      if (await nodePath.exists() && await cliPath.exists()) {
        return candidate;
      }
    }

    _diag(
      'bundle.macos-bundled-runtime-missing',
      data: {
        'platformKey': platformKey,
        'appBundle': appBundle.path,
        'candidates': candidates.map((item) => item.path).toList(),
      },
    );
    return null;
  }

  Directory? _macOSAppBundleRoot() {
    var dir = File(Platform.resolvedExecutable).absolute.parent;
    while (true) {
      if (dir.path.endsWith('.app')) return dir;
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  Future<Directory> _prepareBundle(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    final runtimeDir = await _runtimeDir(spec, platformKey);
    final marker = File(p.join(runtimeDir.path, '.bundle_ready'));
    final nodePath = File(p.join(runtimeDir.path, spec.nodeExecutable));
    final cliPath = File(p.join(runtimeDir.path, spec.cliEntrypoint));

    if (await marker.exists() &&
        await nodePath.exists() &&
        await cliPath.exists()) {
      _diag(
        'bundle.prepare.cached',
        data: {
          'platformKey': platformKey,
          'runtimeDir': runtimeDir.path,
          'marker': marker.path,
        },
      );
      return runtimeDir;
    }

    final prefix = 'assets/openclaw/$platformKey/';
    final assets = await _listAssets(prefix);
    final hasNodeAsset = assets.contains('$prefix${spec.nodeExecutable}');
    final hasCliAsset = assets.contains('$prefix${spec.cliEntrypoint}');
    _diag(
      'bundle.prepare.assets',
      data: {
        'platformKey': platformKey,
        'prefix': prefix,
        'assetCount': assets.length,
        'hasNodeAsset': hasNodeAsset,
        'hasCliAsset': hasCliAsset,
        'nodeAsset': '$prefix${spec.nodeExecutable}',
        'cliAsset': '$prefix${spec.cliEntrypoint}',
        'sample': assets.take(8).toList(),
      },
    );
    if (!hasNodeAsset || !hasCliAsset) {
      throw OpenClawRuntimeException(
        '当前安装包没有内置 $platformKey 的 OpenClaw runtime。请在 release 构建中运行 scripts/build_openclaw_desktop_bundle.sh 后再打包。',
      );
    }

    if (await runtimeDir.exists()) {
      _diag('bundle.prepare.remove-old', data: {'runtimeDir': runtimeDir.path});
      await runtimeDir.delete(recursive: true);
    }
    await runtimeDir.create(recursive: true);

    for (final asset in assets) {
      final relative = asset.substring(prefix.length);
      if (relative.isEmpty || relative.endsWith('/')) continue;
      final bytes = await rootBundle.load(asset);
      final file = File(p.join(runtimeDir.path, relative));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: false,
      );
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', nodePath.path]);
    }
    await marker.writeAsString(DateTime.now().toIso8601String());
    _diag(
      'bundle.prepare.complete',
      data: {
        'platformKey': platformKey,
        'runtimeDir': runtimeDir.path,
        'assetCount': assets.length,
        'nodeExists': await nodePath.exists(),
        'nodeSize': await nodePath.exists() ? await nodePath.length() : 0,
        'cliExists': await cliPath.exists(),
        'cliSize': await cliPath.exists() ? await cliPath.length() : 0,
      },
    );
    return runtimeDir;
  }

  Future<bool> _hasRequiredBundleAssets(
    String platformKey,
    _OpenClawBundleSpec spec,
  ) async {
    final prefix = 'assets/openclaw/$platformKey/';
    final assets = await _listAssets(prefix);
    final hasRequired =
        assets.contains('$prefix${spec.nodeExecutable}') &&
        assets.contains('$prefix${spec.cliEntrypoint}');
    _diag(
      'bundle.has-required-assets',
      data: {
        'platformKey': platformKey,
        'assetCount': assets.length,
        'hasRequired': hasRequired,
      },
    );
    return hasRequired;
  }

  Future<List<String>> _listAssets(String prefix) async {
    final assets = <String>{};
    var jsonCount = 0;
    var binCount = 0;
    var indexCount = 0;
    final failures = <String>[];

    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded.keys
          .where((key) => key.startsWith(prefix))
          .toList();
      jsonCount = items.length;
      assets.addAll(items);
    } catch (error) {
      failures.add('AssetManifest.json: $error');
      // Newer Flutter release builds may only include AssetManifest.bin.
    }

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final items = manifest
          .listAssets()
          .where((key) => key.startsWith(prefix))
          .toList();
      binCount = items.length;
      assets.addAll(items);
    } catch (error) {
      failures.add('AssetManifest.bin: $error');
      // App Store archives patched after flutter build carry a JSON/index file.
    }

    try {
      final raw = await rootBundle.loadString(
        'assets/openclaw/asset_index.json',
      );
      final decoded = jsonDecode(raw);
      final indexedAssets = decoded is Map
          ? decoded['assets']
          : decoded is List
          ? decoded
          : const [];
      if (indexedAssets is List) {
        final items = indexedAssets
            .map((item) => item.toString())
            .where((key) => key.startsWith(prefix))
            .toList();
        indexCount = items.length;
        assets.addAll(items);
      }
    } catch (error) {
      failures.add('asset_index.json: $error');
      // Older builds do not have an OpenClaw asset index.
    }

    final sortedAssets = assets.toList()..sort();
    _diag(
      'asset.list',
      data: {
        'prefix': prefix,
        'total': sortedAssets.length,
        'jsonCount': jsonCount,
        'binCount': binCount,
        'indexCount': indexCount,
        if (failures.isNotEmpty) 'failures': failures,
        'sample': sortedAssets.take(8).toList(),
      },
    );
    return sortedAssets;
  }

  Future<bool> _probe(
    int port,
    String token, {
    String context = 'probe',
  }) async {
    try {
      final modelsResponse = await http
          .get(
            Uri.parse('http://127.0.0.1:$port/v1/models'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_probeTimeout);
      if (modelsResponse.statusCode < 200 || modelsResponse.statusCode >= 300) {
        _diag(
          'probe.models-unhealthy',
          data: {
            'context': context,
            'port': port,
            'statusCode': modelsResponse.statusCode,
          },
        );
        return false;
      }

      // `/v1/models` can be healthy while `/v1/chat/completions` is disabled
      // by an old config. The home screen uses chat completions, so treat 404
      // or auth failures as an unhealthy embedded runtime and restart it with
      // the repaired config below. A 4xx validation error is acceptable here:
      // it proves the OpenAI-compatible chat route is wired.
      final chatResponse = await http
          .post(
            Uri.parse('http://127.0.0.1:$port/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: '{}',
          )
          .timeout(_probeTimeout);
      final healthy =
          chatResponse.statusCode != 401 &&
          chatResponse.statusCode != 403 &&
          chatResponse.statusCode != 404;
      _diag(
        healthy ? 'probe.healthy' : 'probe.chat-unhealthy',
        data: {
          'context': context,
          'port': port,
          'chatStatusCode': chatResponse.statusCode,
        },
      );
      return healthy;
    } catch (error) {
      if (context != 'startup') {
        _diag(
          'probe.error',
          data: {'context': context, 'port': port},
          error: error,
        );
      }
      return false;
    }
  }

  Future<File> _ensureConfigFile({
    required Directory stateRoot,
    required int port,
    required String token,
    required String model,
  }) async {
    final configDir = Directory(p.join(stateRoot.path, 'config'));
    await configDir.create(recursive: true);
    final workspace = Directory(p.join(stateRoot.path, 'workspace'));
    await workspace.create(recursive: true);
    final configPath = File(p.join(configDir.path, 'openclaw.json'));

    final config = <String, dynamic>{
      'gateway': {
        'mode': 'local',
        'port': port,
        'bind': 'loopback',
        'auth': {'mode': 'token', 'token': token},
        'http': {
          'endpoints': {
            'chatCompletions': {'enabled': true},
            'responses': {'enabled': true},
          },
        },
      },
      'agents': {
        'defaults': {
          'workspace': workspace.path,
          'model': {'primary': model},
        },
        'list': [
          {
            'id': 'dacheng',
            'default': true,
            'workspace': workspace.path,
            'model': {'primary': model},
          },
        ],
      },
    };

    // Repair older embedded configs in-place. OpenClaw 2026.6 requires
    // gateway.mode=local, and the home screen requires the OpenAI-compatible
    // chat endpoint. Preserve unrelated user edits while fixing the fields
    // needed for the app-owned embedded gateway to start reliably.
    final merged = await _mergeEmbeddedConfig(configPath, config);
    await configPath.writeAsString(
      const JsonEncoder.withIndent('  ').convert(merged),
    );
    _diag(
      'config.written',
      data: {
        'configPath': configPath.path,
        'port': port,
        'gatewayMode': _mutableMap(merged['gateway'])['mode'],
      },
    );
    return configPath;
  }

  String? _resolveDeepSeekApiKey() {
    for (final value in [
      Platform.environment['DACHENG_OPENCLAW_DEEPSEEK_API_KEY'],
      Platform.environment['DEEPSEEK_API_KEY'],
      AppConfig.configuredOpenClawDeepSeekApiKey,
    ]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  Future<File> _ensureDesktopToolsManifest({
    required Directory stateRoot,
    required _DesktopToolsLaunch desktopTools,
  }) async {
    final configDir = Directory(p.join(stateRoot.path, 'config'));
    await configDir.create(recursive: true);
    final manifestPath = File(p.join(configDir.path, 'desktop_tools.json'));
    final tools =
        DesktopControlPolicy.supportedTools
            .map(
              (name) => {
                'name': name,
                'endpoint': '/v1/tools/execute',
                'readOnly': DesktopControlPolicy.isReadOnly(name),
                'requiresConfirmation':
                    DesktopControlPolicy.requiresConfirmation(name),
              },
            )
            .toList()
          ..sort(
            (a, b) => a['name'].toString().compareTo(b['name'].toString()),
          );

    await manifestPath.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'transport': 'http-loopback',
        'baseUrl': desktopTools.uri?.toString(),
        'auth': {'type': 'bearer', 'env': 'DACHENG_DESKTOP_TOOLS_TOKEN'},
        'status': desktopTools.statusJson,
        'tools': tools,
      }),
    );
    _diag(
      'desktop-tools.manifest-written',
      data: {
        'manifestPath': manifestPath.path,
        'hasBaseUrl': desktopTools.uri != null,
      },
    );
    return manifestPath;
  }

  Future<Map<String, dynamic>> _mergeEmbeddedConfig(
    File configPath,
    Map<String, dynamic> defaults,
  ) async {
    Map<String, dynamic> current = <String, dynamic>{};
    if (await configPath.exists()) {
      try {
        final decoded = jsonDecode(await configPath.readAsString());
        if (decoded is Map<String, dynamic>) {
          current = decoded;
        } else if (decoded is Map) {
          current = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        current = <String, dynamic>{};
      }
    }

    final gateway = _mutableMap(current['gateway']);
    final defaultGateway = _mutableMap(defaults['gateway']);
    gateway['mode'] = 'local';
    gateway['port'] = defaultGateway['port'];
    gateway['bind'] = defaultGateway['bind'];
    gateway['auth'] = Map<String, dynamic>.from(defaultGateway['auth'] as Map);

    final gatewayHttp = _mutableMap(gateway['http']);
    final endpoints = _mutableMap(gatewayHttp['endpoints']);
    endpoints['chatCompletions'] = {'enabled': true};
    endpoints['responses'] = {'enabled': true};
    gatewayHttp['endpoints'] = endpoints;
    gateway['http'] = gatewayHttp;
    current['gateway'] = gateway;

    final agents = _mutableMap(current['agents']);
    final defaultAgents = _mutableMap(defaults['agents']);
    final agentDefaults = _mutableMap(agents['defaults']);
    final defaultAgentDefaults = _mutableMap(defaultAgents['defaults']);
    agentDefaults['workspace'] = defaultAgentDefaults['workspace'];
    agentDefaults['model'] = defaultAgentDefaults['model'];
    agents['defaults'] = agentDefaults;
    agents['list'] = defaultAgents['list'];
    current['agents'] = agents;

    return current;
  }

  Map<String, dynamic> _mutableMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  void _captureLogs(Process process) {
    void addLog(String line) {
      final text = line.trim();
      if (text.isEmpty) return;
      _recentLogs.insert(0, text);
      if (_recentLogs.length > 80) {
        _recentLogs.removeRange(80, _recentLogs.length);
      }
      if (kDebugMode) {
        debugPrint('[OpenClaw] $text');
      }
      _diag('process.output', data: {'line': text});
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(addLog, onError: (_) {});
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(addLog, onError: (_) {});
  }

  Future<Directory> _stateRoot() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'openclaw_embedded'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<_DesktopToolsLaunch> _ensureDesktopTools() async {
    try {
      final status = await DesktopControlBridge.instance.ensureStarted();
      _diag(
        'desktop-tools.started',
        data: {
          'bridgeRunning': status.bridgeRunning,
          'bridgeUri': status.bridgeUri?.toString(),
          'message': status.message,
        },
      );
      return _DesktopToolsLaunch(
        uri: status.bridgeUri,
        token: await DesktopControlBridge.instance.bridgeToken,
        statusJson: status.toJson(),
      );
    } catch (error) {
      _diag('desktop-tools.error', error: error);
      return _DesktopToolsLaunch(
        uri: null,
        token: null,
        statusJson: {
          'enabledByBuild': false,
          'bridgeRunning': false,
          'message': error.toString(),
        },
      );
    }
  }

  Future<Directory> _runtimeDir(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      p.join(
        support.path,
        'openclaw_embedded',
        'runtime',
        spec.version,
        platformKey,
      ),
    );
  }

  OpenClawRuntimeStatus _remember(OpenClawRuntimeStatus status) {
    _lastStatus = status;
    return status;
  }

  String? get _platformKey {
    final abi = Abi.current().toString().toLowerCase();
    if (Platform.isMacOS) {
      return abi.contains('arm64') ? 'macos-arm64' : 'macos-x64';
    }
    if (Platform.isWindows) {
      return abi.contains('arm64') ? 'windows-arm64' : 'windows-x64';
    }
    if (Platform.isLinux) {
      return abi.contains('arm64') ? 'linux-arm64' : 'linux-x64';
    }
    return null;
  }

  OpenClawRuntimeStatus? get lastStatus => _lastStatus;

  void _diag(
    String message, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    unawaited(
      DiagnosticLogService.instance.log(
        'openclaw.runtime',
        message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
