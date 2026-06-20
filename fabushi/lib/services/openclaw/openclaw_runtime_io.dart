import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
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
import 'openclaw_port_resolver.dart';

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
  final bool downloaded;

  const _OpenClawBundleSpec({
    required this.version,
    required this.defaultPort,
    required this.defaultModel,
    this.defaultModelOverride,
    required this.nodeExecutable,
    required this.cliEntrypoint,
    required this.gatewayArgs,
    this.downloaded = false,
  });

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'version': version,
    'defaultPort': defaultPort,
    'defaultModel': defaultModel,
    if (defaultModelOverride != null)
      'defaultModelOverride': defaultModelOverride,
    'nodeExecutable': nodeExecutable,
    'cliEntrypoint': cliEntrypoint,
    'gatewayArgs': gatewayArgs,
    'downloaded': downloaded,
  };
}

class _OpenClawRuntimeRelease {
  final String version;
  final Uri archiveUri;
  final String sha256Hex;
  final int size;
  final int defaultPort;
  final String defaultModel;
  final String? defaultModelOverride;
  final String nodeExecutable;
  final String cliEntrypoint;
  final List<String> gatewayArgs;

  const _OpenClawRuntimeRelease({
    required this.version,
    required this.archiveUri,
    required this.sha256Hex,
    required this.size,
    required this.defaultPort,
    required this.defaultModel,
    this.defaultModelOverride,
    required this.nodeExecutable,
    required this.cliEntrypoint,
    required this.gatewayArgs,
  });

  _OpenClawBundleSpec toBundleSpec() => _OpenClawBundleSpec(
    version: version,
    defaultPort: defaultPort,
    defaultModel: defaultModel,
    defaultModelOverride: defaultModelOverride,
    nodeExecutable: nodeExecutable,
    cliEntrypoint: cliEntrypoint,
    gatewayArgs: gatewayArgs,
    downloaded: true,
  );
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
  static const String _runtimeDirOverrideDefine = String.fromEnvironment(
    'DACHENG_OPENCLAW_RUNTIME_DIR',
  );
  static const String _defaultGatewayModel =
      AppSettings.defaultOpenClawGatewayModel;
  static const String _defaultDeepSeekModel =
      AppSettings.defaultOpenClawDeepSeekModel;
  static const String _backendDeepSeekProviderId = 'dacheng-deepseek-proxy';
  static const Duration _startupTimeout = Duration(seconds: 120);
  static const Duration _probeTimeout = Duration(seconds: 3);

  Process? _process;
  Future<OpenClawGatewayTarget>? _starting;
  String _processAuthToken = '';
  OpenClawRuntimeStatus? _lastStatus;
  final List<String> _recentLogs = <String>[];
  final OpenClawPortResolver _portResolver = const OpenClawPortResolver();

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
      final spec = await _loadSpec(platformKey, checkUpdates: false);
      final overrideRuntimeDir = await _runtimeDirOverride(spec, platformKey);
      final bundledRuntimeDir = overrideRuntimeDir == null
          ? await _bundledRuntimeDir(spec, platformKey)
          : null;
      final runtimeDir =
          overrideRuntimeDir ??
          bundledRuntimeDir ??
          await _runtimeDir(spec, platformKey);
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
          'runtimeSource': overrideRuntimeDir != null
              ? 'override'
              : (bundledRuntimeDir == null ? 'cache' : 'bundle'),
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
    _processAuthToken = '';
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

    final spec = await _loadSpec(platformKey, checkUpdates: true);
    final requestedPort = await AppSettings.getOpenClawGatewayPort(
      defaultValue: spec.defaultPort,
    );
    final token = await AppSettings.getOpenClawGatewayToken();
    final savedModel = await AppSettings.getOpenClawModel(
      defaultValue: spec.defaultModel,
    );
    final model = _gatewayChatModel(savedModel);
    final requestedAuthToken = authToken?.trim() ?? '';
    final backendDeepSeekModel = _backendDeepSeekModelRef(
      await AppSettings.getOpenClawDeepSeekModel(
        defaultValue: _defaultDeepSeekModelFor(spec.defaultModel),
      ),
    );
    final deepSeekProxyBaseUrl = _deepSeekProxyBaseUrl();
    final modelOverride = await AppSettings.getOpenClawModelOverride(
      defaultValue: spec.defaultModelOverride ?? '',
    );
    final desktopTools = await _ensureDesktopTools();
    _diag(
      'ensure-start.config',
      data: {
        'platformKey': platformKey,
        'requestedPort': requestedPort,
        'model': model,
        'rawModel': savedModel,
        'backendDeepSeekModel': backendDeepSeekModel,
        'deepSeekProxyBaseUrl': deepSeekProxyBaseUrl,
        'hasAuthToken': requestedAuthToken.isNotEmpty,
        'modelOverrideSet': modelOverride.trim().isNotEmpty,
        'desktopToolsUri': desktopTools.uri?.toString(),
        'desktopToolsStatus': desktopTools.statusJson,
      },
    );

    final canReuseStartedProcess =
        _process != null && _processAuthToken == requestedAuthToken;
    if (canReuseStartedProcess &&
        await _probe(requestedPort, token, context: 'pre-start')) {
      _diag('ensure-start.reuse-existing', data: {'port': requestedPort});
      return OpenClawGatewayTarget(
        baseUri: Uri.parse('http://127.0.0.1:$requestedPort'),
        token: token,
        model: model,
        modelOverride: modelOverride.trim().isEmpty
            ? null
            : modelOverride.trim(),
        desktopToolsUri: desktopTools.uri,
        desktopToolsToken: desktopTools.token,
        desktopToolsStatus: desktopTools.statusJson,
      );
    } else if (_process != null) {
      _diag(
        'ensure-start.restart-auth-changed',
        data: {
          'hasPreviousAuthToken': _processAuthToken.isNotEmpty,
          'hasRequestedAuthToken': requestedAuthToken.isNotEmpty,
        },
      );
      await stop();
    }

    final runtimeDir = await _prepareBundle(spec, platformKey);
    final stateRoot = await _stateRoot();
    if (_process != null) {
      _diag(
        'process.stop-stale-before-start',
        data: {'requestedPort': requestedPort},
      );
      await stop();
    }
    final portCandidate = await _portResolver.resolve(requestedPort);
    final port = portCandidate.port;
    if (portCandidate.isFallback) {
      await AppSettings.setOpenClawGatewayPort(port);
      _diag(
        'ensure-start.fallback-port',
        data: {
          'requestedPort': requestedPort,
          'selectedPort': port,
          if (portCandidate.reason != null) 'reason': portCandidate.reason,
        },
      );
    } else {
      _diag(
        'ensure-start.port-bindable',
        data: {'requestedPort': requestedPort, 'selectedPort': port},
      );
    }
    final configPath = await _ensureConfigFile(
      stateRoot: stateRoot,
      port: port,
      token: token,
      backendDeepSeekModel: backendDeepSeekModel,
      deepSeekProxyBaseUrl: deepSeekProxyBaseUrl,
    );
    await _ensureAgentModelConfig(
      stateRoot: stateRoot,
      deepSeekProxyBaseUrl: deepSeekProxyBaseUrl,
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
    _recentLogs.clear();
    _diag(
      'process.starting',
      data: {
        'nodePath': nodePath,
        'args': args,
        'workingDirectory': runtimeDir.path,
        'configPath': configPath.path,
        'desktopToolsManifestPath': desktopToolsManifestPath.path,
        'requestedPort': requestedPort,
        'selectedPort': port,
      },
    );

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
        'DACHENG_AUTH_TOKEN': (authToken != null && authToken.isNotEmpty)
            ? authToken
            : token,
        if (username != null && username.isNotEmpty)
          'DACHENG_USERNAME': username,
        'DACHENG_IS_MEMBER': isMember ? '1' : '0',
        'DACHENG_OPENCLAW_PROXY_TOKEN': 'dacheng-openclaw-proxy',
        'OPENCLAW_DISABLE_BONJOUR': '1',
      });

    _process = await Process.start(
      nodePath,
      args,
      workingDirectory: runtimeDir.path,
      environment: env,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    _processAuthToken = requestedAuthToken;
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

  Future<_OpenClawBundleSpec> _loadSpec(
    String platformKey, {
    bool checkUpdates = false,
  }) async {
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
      defaultModel: (decoded['defaultModel'] ?? 'openclaw/default').toString(),
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
    final allowDownloadedRuntime = await _allowDownloadedRuntime(platformKey);
    var effectiveSpec = spec;
    if (allowDownloadedRuntime) {
      effectiveSpec =
          await _loadActiveDownloadedSpec(platformKey, fallbackSpec: spec) ??
          spec;
    } else {
      await _clearActiveDownloadedRuntimeSpec(
        platformKey: platformKey,
        reason: 'macos-sandbox',
      );
    }
    if (checkUpdates && allowDownloadedRuntime) {
      effectiveSpec =
          await _maybeInstallRuntimeUpdate(
            platformKey: platformKey,
            currentSpec: effectiveSpec,
          ) ??
          effectiveSpec;
    } else if (checkUpdates) {
      _diag(
        'runtime-update.skip-disabled',
        data: {'platformKey': platformKey, 'reason': 'macos-sandbox'},
      );
    }
    return effectiveSpec;
  }

  Future<bool> _allowDownloadedRuntime(String platformKey) async {
    if (!Platform.isMacOS) return true;

    final support = await getApplicationSupportDirectory();
    final sandboxContainerId =
        Platform.environment['APP_SANDBOX_CONTAINER_ID']?.trim() ?? '';
    final pathLooksSandboxed = p
        .split(p.normalize(support.path))
        .contains('Containers');
    final sandboxed = sandboxContainerId.isNotEmpty || pathLooksSandboxed;
    if (!sandboxed) return true;

    // App Store/TestFlight sandboxed apps cannot reliably execute downloaded
    // Mach-O payloads. Use the bundled runtime that was signed with inherited
    // sandbox entitlements during packaging.
    _diag(
      'runtime-update.disabled-macos-sandbox',
      data: {
        'platformKey': platformKey,
        'supportPath': support.path,
        'hasSandboxContainerId': sandboxContainerId.isNotEmpty,
      },
    );
    return false;
  }

  Future<void> _clearActiveDownloadedRuntimeSpec({
    required String platformKey,
    required String reason,
  }) async {
    final saved = await AppSettings.getOpenClawActiveRuntimeSpec();
    if (saved == null) return;
    await AppSettings.clearOpenClawActiveRuntimeSpec();
    _diag(
      'runtime-update.active-cleared',
      data: {
        'platformKey': platformKey,
        'reason': reason,
        'version': saved['version']?.toString(),
        'downloaded': saved['downloaded'] == true,
      },
    );
  }

  Future<_OpenClawBundleSpec?> _loadActiveDownloadedSpec(
    String platformKey, {
    required _OpenClawBundleSpec fallbackSpec,
  }) async {
    final saved = await AppSettings.getOpenClawActiveRuntimeSpec();
    if (saved == null) return null;
    final spec = _specFromJson(saved, downloaded: true);
    if (spec == null) {
      await AppSettings.clearOpenClawActiveRuntimeSpec();
      return null;
    }
    final runtimeDir = await _cachedRuntimeDirIfComplete(spec, platformKey);
    if (runtimeDir == null) {
      await AppSettings.clearOpenClawActiveRuntimeSpec();
      _diag(
        'runtime-update.active-missing',
        data: {'platformKey': platformKey, 'version': spec.version},
      );
      return null;
    }
    _diag(
      'runtime-update.active-loaded',
      data: {
        'platformKey': platformKey,
        'version': spec.version,
        'runtimeDir': runtimeDir.path,
        'bundledVersion': fallbackSpec.version,
      },
    );
    return spec;
  }

  _OpenClawBundleSpec? _specFromJson(
    Map<String, dynamic> json, {
    required bool downloaded,
  }) {
    final version = json['version']?.toString().trim() ?? '';
    final nodeExecutable = json['nodeExecutable']?.toString().trim() ?? '';
    final cliEntrypoint = json['cliEntrypoint']?.toString().trim() ?? '';
    if (version.isEmpty || nodeExecutable.isEmpty || cliEntrypoint.isEmpty) {
      return null;
    }
    return _OpenClawBundleSpec(
      version: version,
      defaultPort: _readInt(json['defaultPort']) ?? 18789,
      defaultModel: (json['defaultModel'] ?? _defaultGatewayModel).toString(),
      defaultModelOverride: json['defaultModelOverride']?.toString(),
      nodeExecutable: nodeExecutable,
      cliEntrypoint: cliEntrypoint,
      gatewayArgs:
          (json['gatewayArgs'] as List? ??
                  const ['gateway', '--port', '{port}', '--force'])
              .map((item) => item.toString())
              .toList(),
      downloaded: downloaded,
    );
  }

  Future<_OpenClawBundleSpec?> _maybeInstallRuntimeUpdate({
    required String platformKey,
    required _OpenClawBundleSpec currentSpec,
  }) async {
    if (_configuredRuntimeDirOverride(platformKey) != null) {
      _diag('runtime-update.skip-override', data: {'platformKey': platformKey});
      return null;
    }

    try {
      final release = await _fetchRuntimeRelease(
        platformKey: platformKey,
        currentVersion: currentSpec.version,
      );
      if (release == null || release.version == currentSpec.version) {
        return null;
      }

      final releaseSpec = release.toBundleSpec();
      final cached = await _cachedRuntimeDirIfComplete(
        releaseSpec,
        platformKey,
      );
      if (cached != null) {
        await AppSettings.setOpenClawActiveRuntimeSpec(releaseSpec.toJson());
        _diag(
          'runtime-update.use-cached',
          data: {
            'platformKey': platformKey,
            'version': release.version,
            'runtimeDir': cached.path,
          },
        );
        return releaseSpec;
      }

      return await _downloadAndInstallRuntimeUpdate(
        release: release,
        platformKey: platformKey,
      );
    } catch (error, stackTrace) {
      _diag(
        'runtime-update.failed',
        data: {
          'platformKey': platformKey,
          'currentVersion': currentSpec.version,
          'error': error.toString(),
        },
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<_OpenClawRuntimeRelease?> _fetchRuntimeRelease({
    required String platformKey,
    required String currentVersion,
  }) async {
    final baseUrl = AppConfig.currentAiBackendUrl.replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final uri = Uri.parse('$baseUrl/api/openclaw/runtime/manifest').replace(
      queryParameters: {
        'platform': platformKey,
        'currentVersion': currentVersion,
        'appVersion': AppConfig.appVersion,
      },
    );
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _diag(
        'runtime-update.manifest-http',
        data: {'statusCode': response.statusCode, 'uri': uri.toString()},
      );
      return null;
    }
    final decoded = _decodeJsonOrNull(response.body);
    if (decoded is! Map) return null;
    final payload = Map<String, dynamic>.from(decoded);
    if (payload['updateAvailable'] != true) {
      _diag(
        'runtime-update.none',
        data: {
          'platformKey': platformKey,
          'reason': payload['reason']?.toString(),
          'currentVersion': currentVersion,
          'latestVersion': payload['latestVersion']?.toString(),
        },
      );
      return null;
    }
    final latest = payload['latest'];
    if (latest is! Map) return null;
    return _releaseFromJson(Map<String, dynamic>.from(latest));
  }

  _OpenClawRuntimeRelease? _releaseFromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString().trim() ?? '';
    final archiveUrl = json['archiveUrl']?.toString().trim() ?? '';
    final sha256Hex = json['sha256']?.toString().trim().toLowerCase() ?? '';
    final archiveUri = Uri.tryParse(archiveUrl);
    final gatewayArgs =
        (json['gatewayArgs'] as List? ??
                const ['gateway', '--port', '{port}', '--force'])
            .map((item) => item.toString())
            .toList();
    if (version.isEmpty ||
        archiveUri == null ||
        !archiveUri.hasScheme ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256Hex)) {
      _diag(
        'runtime-update.invalid-release',
        data: {
          'version': version,
          'archiveUrlSet': archiveUrl.isNotEmpty,
          'sha256Length': sha256Hex.length,
        },
      );
      return null;
    }
    return _OpenClawRuntimeRelease(
      version: version,
      archiveUri: archiveUri,
      sha256Hex: sha256Hex,
      size: _readInt(json['size']) ?? 0,
      defaultPort: _readInt(json['defaultPort']) ?? 18789,
      defaultModel: (json['defaultModel'] ?? _defaultGatewayModel).toString(),
      defaultModelOverride: json['defaultModelOverride']?.toString(),
      nodeExecutable: (json['nodeExecutable'] ?? 'node/bin/node').toString(),
      cliEntrypoint: (json['cliEntrypoint'] ?? 'openclaw/openclaw.mjs')
          .toString(),
      gatewayArgs: gatewayArgs,
    );
  }

  Future<_OpenClawBundleSpec> _downloadAndInstallRuntimeUpdate({
    required _OpenClawRuntimeRelease release,
    required String platformKey,
  }) async {
    final spec = release.toBundleSpec();
    final runtimeDir = await _runtimeDir(spec, platformKey);
    final support = await getApplicationSupportDirectory();
    final downloadDir = Directory(p.join(support.path, 'openclaw_downloads'));
    await downloadDir.create(recursive: true);
    final archivePath = p.join(
      downloadDir.path,
      '${_safePathPart(release.version)}-$platformKey${_archiveExtension(release.archiveUri)}',
    );
    final archiveFile = File(archivePath);
    final digest = await _downloadRuntimeArchive(release, archiveFile);
    if (digest != release.sha256Hex) {
      await _deleteFileIfExists(archiveFile);
      throw OpenClawRuntimeException(
        'OpenClaw runtime 校验失败: expected=${release.sha256Hex}, actual=$digest',
      );
    }

    final extractDir = Directory(
      p.join(
        downloadDir.path,
        '${_safePathPart(release.version)}-$platformKey-extract',
      ),
    );
    final stagingDir = Directory(
      p.join(
        downloadDir.path,
        '${_safePathPart(release.version)}-$platformKey-stage',
      ),
    );
    if (await extractDir.exists()) await extractDir.delete(recursive: true);
    if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
    await extractDir.create(recursive: true);
    await _extractRuntimeArchive(archiveFile, extractDir);

    final extractedRoot = await _findExtractedRuntimeRoot(
      extractDir: extractDir,
      spec: spec,
    );
    if (extractedRoot == null) {
      throw OpenClawRuntimeException('下载的 OpenClaw runtime 不包含必要的 node/cli 文件');
    }

    await runtimeDir.parent.create(recursive: true);
    if (await runtimeDir.exists()) await runtimeDir.delete(recursive: true);
    await _moveOrCopyRuntimeDirectory(extractedRoot, stagingDir);
    await stagingDir.rename(runtimeDir.path);
    final marker = File(p.join(runtimeDir.path, '.bundle_ready'));
    await marker.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'installedAt': DateTime.now().toIso8601String(),
        'version': release.version,
        'platform': platformKey,
        'sha256': digest,
        'source': release.archiveUri.toString(),
      }),
    );
    await _repairRuntimeLaunchMetadata(
      runtimeDir: runtimeDir,
      nodePath: File(p.join(runtimeDir.path, spec.nodeExecutable)),
      platformKey: platformKey,
      cached: false,
    );
    await AppSettings.setOpenClawActiveRuntimeSpec(spec.toJson());
    await _deleteDirectoryIfExists(extractDir);
    await _deleteFileIfExists(archiveFile);
    _diag(
      'runtime-update.installed',
      data: {
        'platformKey': platformKey,
        'version': release.version,
        'runtimeDir': runtimeDir.path,
        'size': release.size,
      },
    );
    return spec;
  }

  Future<String> _downloadRuntimeArchive(
    _OpenClawRuntimeRelease release,
    File destination,
  ) async {
    final client = http.Client();
    IOSink? output;
    try {
      final request = http.Request('GET', release.archiveUri)
        ..headers['Accept'] = 'application/octet-stream';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenClawRuntimeException(
          'OpenClaw runtime 下载失败 (${response.statusCode})',
        );
      }
      await destination.parent.create(recursive: true);
      output = destination.openWrite();
      final digestSink = AccumulatorSink<Digest>();
      final hashSink = sha256.startChunkedConversion(digestSink);
      var bytes = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(minutes: 5),
      )) {
        bytes += chunk.length;
        hashSink.add(chunk);
        output.add(chunk);
      }
      await output.flush();
      await output.close();
      output = null;
      hashSink.close();
      final digest = digestSink.events.single.toString();
      _diag(
        'runtime-update.downloaded',
        data: {
          'archiveUri': release.archiveUri.toString(),
          'bytes': bytes,
          'sha256': digest,
        },
      );
      return digest;
    } finally {
      await output?.close().catchError((_) {});
      client.close();
    }
  }

  Future<void> _extractRuntimeArchive(
    File archiveFile,
    Directory destination,
  ) async {
    final lowerPath = archiveFile.path.toLowerCase();
    if (Platform.isMacOS && lowerPath.endsWith('.zip')) {
      try {
        final result = await Process.run('/usr/bin/ditto', [
          '-x',
          '-k',
          archiveFile.path,
          destination.path,
        ]).timeout(const Duration(minutes: 5));
        _diag(
          'runtime-update.extract-native',
          data: {
            'archivePath': archiveFile.path,
            'destination': destination.path,
            'exitCode': result.exitCode,
            if ((result.stderr as Object).toString().isNotEmpty)
              'stderr': _previewProcessOutput(result.stderr),
          },
        );
        if (result.exitCode == 0) return;
      } catch (error, stackTrace) {
        _diag(
          'runtime-update.extract-native-failed',
          data: {
            'archivePath': archiveFile.path,
            'destination': destination.path,
            'error': error.toString(),
          },
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    await extractFileToDisk(archiveFile.path, destination.path);
    _diag(
      'runtime-update.extract-dart',
      data: {'archivePath': archiveFile.path, 'destination': destination.path},
    );
  }

  Future<Directory?> _findExtractedRuntimeRoot({
    required Directory extractDir,
    required _OpenClawBundleSpec spec,
  }) async {
    final direct = await _runtimeRootIfComplete(extractDir, spec);
    if (direct != null) return direct;
    await for (final entity in extractDir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final nested = await _runtimeRootIfComplete(entity, spec);
      if (nested != null) return nested;
    }
    return null;
  }

  Future<Directory?> _runtimeRootIfComplete(
    Directory dir,
    _OpenClawBundleSpec spec,
  ) async {
    final nodePath = File(p.join(dir.path, spec.nodeExecutable));
    final cliPath = File(p.join(dir.path, spec.cliEntrypoint));
    if (await nodePath.exists() && await cliPath.exists()) return dir;
    return null;
  }

  Future<Directory?> _cachedRuntimeDirIfComplete(
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
      return runtimeDir;
    }
    return null;
  }

  String _safePathPart(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '-');
    return safe.isEmpty ? 'runtime' : safe;
  }

  String _archiveExtension(Uri uri) {
    final lower = uri.path.toLowerCase();
    if (lower.endsWith('.tar.gz')) return '.tar.gz';
    if (lower.endsWith('.tgz')) return '.tgz';
    if (lower.endsWith('.tar')) return '.tar';
    return '.zip';
  }

  Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _deleteDirectoryIfExists(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<Directory> _prepareBundle(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    final overrideRuntimeDir = await _runtimeDirOverride(spec, platformKey);
    if (overrideRuntimeDir != null) {
      final nodePath = File(
        p.join(overrideRuntimeDir.path, spec.nodeExecutable),
      );
      await _repairRuntimeLaunchMetadata(
        runtimeDir: overrideRuntimeDir,
        nodePath: nodePath,
        platformKey: platformKey,
        cached: true,
      );
      _diag(
        'bundle.launch.override-runtime',
        data: {
          'platformKey': platformKey,
          'runtimeDir': overrideRuntimeDir.path,
        },
      );
      return overrideRuntimeDir;
    }

    if (spec.downloaded) {
      final downloadedRuntimeDir = await _cachedRuntimeDirIfComplete(
        spec,
        platformKey,
      );
      if (downloadedRuntimeDir != null) {
        await _repairRuntimeLaunchMetadata(
          runtimeDir: downloadedRuntimeDir,
          nodePath: File(
            p.join(downloadedRuntimeDir.path, spec.nodeExecutable),
          ),
          platformKey: platformKey,
          cached: true,
        );
        _diag(
          'bundle.launch.downloaded-runtime',
          data: {
            'platformKey': platformKey,
            'version': spec.version,
            'runtimeDir': downloadedRuntimeDir.path,
          },
        );
        return downloadedRuntimeDir;
      }
      await AppSettings.clearOpenClawActiveRuntimeSpec();
      throw OpenClawRuntimeException(
        '已下载的 OpenClaw runtime 不完整，已回退到内置版本，请重新启动。',
      );
    }

    final bundledRuntimeDir = await _bundledRuntimeDir(spec, platformKey);
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

    if (Platform.isMacOS) {
      throw OpenClawRuntimeException(
        '当前安装包没有可执行的 $platformKey OpenClaw runtime。请先运行 scripts/build_openclaw_desktop_bundle.sh $platformKey，再通过 flutter run 启动。',
      );
    }

    final runtimeDir = await _runtimeDir(spec, platformKey);
    final marker = File(p.join(runtimeDir.path, '.bundle_ready'));
    final nodePath = File(p.join(runtimeDir.path, spec.nodeExecutable));
    final cliPath = File(p.join(runtimeDir.path, spec.cliEntrypoint));

    if (await marker.exists() &&
        await nodePath.exists() &&
        await cliPath.exists()) {
      await _repairRuntimeLaunchMetadata(
        runtimeDir: runtimeDir,
        nodePath: nodePath,
        platformKey: platformKey,
        cached: true,
      );
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

    final legacyRuntimeDir = await _legacyRuntimeDir(spec, platformKey);
    if (legacyRuntimeDir.path != runtimeDir.path &&
        await File(
          p.join(legacyRuntimeDir.path, spec.nodeExecutable),
        ).exists() &&
        await File(
          p.join(legacyRuntimeDir.path, spec.cliEntrypoint),
        ).exists()) {
      _diag(
        'bundle.prepare.migrate-legacy',
        data: {
          'platformKey': platformKey,
          'from': legacyRuntimeDir.path,
          'to': runtimeDir.path,
        },
      );
      if (await runtimeDir.exists()) {
        await runtimeDir.delete(recursive: true);
      }
      await _copyRuntimeDirectory(legacyRuntimeDir, runtimeDir);
      await _repairRuntimeLaunchMetadata(
        runtimeDir: runtimeDir,
        nodePath: nodePath,
        platformKey: platformKey,
        cached: false,
      );
      await marker.writeAsString(DateTime.now().toIso8601String());
      _diag(
        'bundle.prepare.migrate-complete',
        data: {
          'platformKey': platformKey,
          'runtimeDir': runtimeDir.path,
          'nodeExists': await nodePath.exists(),
          'cliExists': await cliPath.exists(),
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

    await _repairRuntimeLaunchMetadata(
      runtimeDir: runtimeDir,
      nodePath: nodePath,
      platformKey: platformKey,
      cached: false,
    );
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

  Future<void> _copyRuntimeDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = p.relative(entity.path, from: source.path);
      if (relative == '.') continue;
      final target = p.join(destination.path, relative);
      if (entity is Directory) {
        await Directory(target).create(recursive: true);
      } else if (entity is File) {
        final targetFile = File(target);
        await targetFile.parent.create(recursive: true);
        await entity.openRead().pipe(targetFile.openWrite());
      }
    }
  }

  Future<void> _moveOrCopyRuntimeDirectory(
    Directory source,
    Directory destination,
  ) async {
    if (await destination.exists()) {
      await destination.delete(recursive: true);
    }
    await destination.parent.create(recursive: true);
    try {
      await source.rename(destination.path);
      return;
    } on FileSystemException {
      await _copyRuntimeDirectory(source, destination);
    }
  }

  Future<void> _repairRuntimeLaunchMetadata({
    required Directory runtimeDir,
    required File nodePath,
    required String platformKey,
    required bool cached,
  }) async {
    if (Platform.isWindows) return;

    final chmodResult = await Process.run('/bin/chmod', ['+x', nodePath.path]);
    ProcessResult? xattrResult;
    if (Platform.isMacOS) {
      // Files created by a quarantined app can inherit the quarantine xattr.
      // macOS then rejects Process.start with "Operation not permitted".
      xattrResult = await Process.run('/usr/bin/xattr', [
        '-dr',
        'com.apple.quarantine',
        runtimeDir.path,
      ]);
      await Process.run('/usr/bin/xattr', [
        '-dr',
        'com.apple.provenance',
        runtimeDir.path,
      ]);
    }

    _diag(
      'bundle.prepare.launch-metadata',
      data: {
        'platformKey': platformKey,
        'runtimeDir': runtimeDir.path,
        'nodePath': nodePath.path,
        'cached': cached,
        'chmodExitCode': chmodResult.exitCode,
        if ((chmodResult.stderr as Object).toString().isNotEmpty)
          'chmodStderr': _previewProcessOutput(chmodResult.stderr),
        if (xattrResult != null) 'xattrExitCode': xattrResult.exitCode,
        if (xattrResult != null &&
            (xattrResult.stderr as Object).toString().isNotEmpty)
          'xattrStderr': _previewProcessOutput(xattrResult.stderr),
      },
    );
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
      final healthResponse = await http
          .get(
            Uri.parse('http://127.0.0.1:$port/health'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_probeTimeout);
      final healthPayload = _decodeJsonOrNull(healthResponse.body);
      if (healthResponse.statusCode < 200 ||
          healthResponse.statusCode >= 300 ||
          !_looksLikeHealthPayload(healthPayload)) {
        _diag(
          'probe.health-unhealthy',
          data: {
            'context': context,
            'port': port,
            'statusCode': healthResponse.statusCode,
            'contentType': healthResponse.headers['content-type'],
            'bodyPreview': _previewBody(healthResponse.body),
          },
        );
        return false;
      }

      final modelsResponse = await http
          .get(
            Uri.parse('http://127.0.0.1:$port/v1/models'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_probeTimeout);
      final modelsPayload = _decodeJsonOrNull(modelsResponse.body);
      if (modelsResponse.statusCode < 200 ||
          modelsResponse.statusCode >= 300 ||
          !_looksLikeModelsPayload(modelsPayload)) {
        _diag(
          'probe.models-unhealthy',
          data: {
            'context': context,
            'port': port,
            'statusCode': modelsResponse.statusCode,
            'contentType': modelsResponse.headers['content-type'],
            'bodyPreview': _previewBody(modelsResponse.body),
          },
        );
        return false;
      }

      // `/v1/models` can be healthy while `/v1/chat/completions` is disabled
      // by an old config. Use GET so the probe only checks route wiring and
      // never starts a real model request.
      final chatResponse = await http
          .get(
            Uri.parse('http://127.0.0.1:$port/v1/chat/completions'),
            headers: {'Authorization': 'Bearer $token'},
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
    required String backendDeepSeekModel,
    required String deepSeekProxyBaseUrl,
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
      'models': {
        'mode': 'merge',
        'providers': {
          _backendDeepSeekProviderId: {
            'baseUrl': deepSeekProxyBaseUrl,
            'api': 'openai-completions',
            'apiKey': 'DACHENG_OPENCLAW_PROXY_TOKEN',
            'authHeader': true,
            'headers': {'x-dacheng-auth-token': 'DACHENG_AUTH_TOKEN'},
            'models': [
              {
                'id': 'deepseek-chat',
                'name': 'DeepSeek Chat',
                'contextWindow': 131072,
                'maxTokens': 8192,
                'input': ['text'],
                'compat': {
                  'requiresStringContent': true,
                  'strictMessageKeys': true,
                },
              },
              {
                'id': 'deepseek-reasoner',
                'name': 'DeepSeek Reasoner',
                'contextWindow': 131072,
                'maxTokens': 8192,
                'reasoning': true,
                'input': ['text'],
                'compat': {
                  'requiresStringContent': true,
                  'strictMessageKeys': true,
                },
              },
            ],
          },
        },
      },
      'plugins': {
        'enabled': false,
        'allow': <String>[],
        'deny': <String>[],
        'load': {'paths': <String>[]},
        'slots': {'memory': 'none'},
        'entries': <String, dynamic>{
          'memory-core': {'enabled': false},
          'bonjour': {'enabled': false},
          'browser': {'enabled': false},
          'canvas': {'enabled': false},
          'device-pair': {'enabled': false},
          'file-transfer': {'enabled': false},
          'phone-control': {'enabled': false},
          'talk-voice': {'enabled': false},
        },
      },
      'agents': {
        'defaults': {
          'workspace': workspace.path,
          'model': {'primary': backendDeepSeekModel},
        },
        'list': [
          {
            'id': 'dacheng',
            'default': true,
            'workspace': workspace.path,
            'model': {'primary': backendDeepSeekModel},
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
        'backendDeepSeekModel': backendDeepSeekModel,
        'deepSeekProxyBaseUrl': deepSeekProxyBaseUrl,
      },
    );
    return configPath;
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

  Future<File> _ensureAgentModelConfig({
    required Directory stateRoot,
    required String deepSeekProxyBaseUrl,
  }) async {
    final agentDir = Directory(
      p.join(stateRoot.path, 'state', 'agents', 'dacheng', 'agent'),
    );
    await agentDir.create(recursive: true);
    final modelsPath = File(p.join(agentDir.path, 'models.json'));
    final providerConfig = <String, dynamic>{
      'baseUrl': deepSeekProxyBaseUrl,
      'api': 'openai-completions',
      'apiKey': 'DACHENG_OPENCLAW_PROXY_TOKEN',
      'authHeader': true,
      'headers': {'x-dacheng-auth-token': 'DACHENG_AUTH_TOKEN'},
      'models': [
        {
          'id': 'deepseek-chat',
          'name': 'DeepSeek Chat',
          'contextWindow': 131072,
          'maxTokens': 8192,
          'input': ['text'],
          'compat': {'requiresStringContent': true, 'strictMessageKeys': true},
        },
        {
          'id': 'deepseek-reasoner',
          'name': 'DeepSeek Reasoner',
          'contextWindow': 131072,
          'maxTokens': 8192,
          'reasoning': true,
          'input': ['text'],
          'compat': {'requiresStringContent': true, 'strictMessageKeys': true},
        },
      ],
    };
    await modelsPath.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'providers': {_backendDeepSeekProviderId: providerConfig},
      }),
    );
    _diag(
      'agent-models.written',
      data: {
        'modelsPath': modelsPath.path,
        'provider': _backendDeepSeekProviderId,
        'deepSeekProxyBaseUrl': deepSeekProxyBaseUrl,
      },
    );
    return modelsPath;
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

    final env = _mutableMap(current['env']);
    env.remove('DEEPSEEK_API_KEY');
    if (env.isEmpty) {
      current.remove('env');
    } else {
      current['env'] = env;
    }

    final defaultModels = _mutableMap(defaults['models']);
    final models = _mutableMap(current['models']);
    models['mode'] ??= defaultModels['mode'];
    final providers = _mutableMap(models['providers']);
    final defaultProviders = _mutableMap(defaultModels['providers']);
    providers.remove('deepseek');
    providers.remove('dacheng-deepseek');
    providers.remove(_backendDeepSeekProviderId);
    for (final entry in defaultProviders.entries) {
      providers[entry.key] = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : entry.value;
    }
    models['providers'] = providers;
    current['models'] = models;

    final defaultPlugins = _mutableMap(defaults['plugins']);
    final plugins = _mutableMap(current['plugins']);
    plugins['enabled'] = false;
    plugins['allow'] = <String>[];
    plugins['deny'] = <String>[];
    plugins['load'] = Map<String, dynamic>.from(
      _mutableMap(defaultPlugins['load']),
    );
    plugins['slots'] = Map<String, dynamic>.from(
      _mutableMap(defaultPlugins['slots']),
    );
    final entries = _mutableMap(plugins['entries']);
    final defaultEntries = _mutableMap(defaultPlugins['entries']);
    for (final entry in defaultEntries.entries) {
      entries[entry.key] = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : entry.value;
    }
    plugins['entries'] = entries;
    current['plugins'] = plugins;

    final agents = _mutableMap(current['agents']);
    final defaultAgents = _mutableMap(defaults['agents']);
    final defaultAgentDefaults = _mutableMap(defaultAgents['defaults']);
    final agentDefaults = _mutableMap(agents['defaults']);
    agentDefaults['workspace'] = defaultAgentDefaults['workspace'];
    agentDefaults['model'] = defaultAgentDefaults['model'];
    agents['defaults'] = agentDefaults;

    final defaultList = (defaultAgents['list'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final defaultDacheng = defaultList.isNotEmpty
        ? defaultList.first
        : <String, dynamic>{
            'id': 'dacheng',
            'default': true,
            'workspace': agentDefaults['workspace'],
            'model': agentDefaults['model'],
          };
    final list = (agents['list'] as List? ?? const [])
        .map((item) => item is Map ? Map<String, dynamic>.from(item) : item)
        .toList();
    var foundDacheng = false;
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map<String, dynamic>) continue;
      if (item['id'] != 'dacheng') continue;
      foundDacheng = true;
      item['default'] = true;
      item['workspace'] = defaultDacheng['workspace'];
      item['model'] = defaultDacheng['model'];
      list[i] = item;
    }
    if (!foundDacheng) {
      list.add(defaultDacheng);
    }
    agents['list'] = list.isEmpty ? defaultList : list;
    current['agents'] = agents;

    return current;
  }

  String _gatewayChatModel(String model) {
    final trimmed = model.trim();
    if (trimmed == 'openclaw' || trimmed.startsWith('openclaw/')) {
      return trimmed;
    }
    return _defaultGatewayModel;
  }

  String _defaultDeepSeekModelFor(String model) {
    final trimmed = model.trim();
    if (trimmed.startsWith('deepseek/')) return trimmed;
    return _defaultDeepSeekModel;
  }

  String _backendDeepSeekModelRef(String model) {
    final trimmed = model.trim().isEmpty ? _defaultDeepSeekModel : model.trim();
    final modelId = trimmed.contains('/')
        ? trimmed.split('/').last.trim()
        : trimmed;
    final normalizedModelId = modelId.isEmpty ? 'deepseek-chat' : modelId;
    return '$_backendDeepSeekProviderId/$normalizedModelId';
  }

  String _deepSeekProxyBaseUrl() {
    final baseUrl = AppConfig.currentAiBackendUrl.replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    return '$baseUrl/api/openclaw/deepseek/v1';
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
    final runtimeBase = Platform.isMacOS
        ? Directory(
            p.join(
              support.parent.path,
              '${p.basename(support.path)}.openclaw_runtime',
            ),
          )
        : Directory(p.join(support.path, 'openclaw_embedded'));
    return Directory(
      p.join(runtimeBase.path, 'runtime', spec.version, platformKey),
    );
  }

  Future<Directory?> _bundledRuntimeDir(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    if (!Platform.isMacOS) return null;

    final contentsDir = Directory(
      p.dirname(p.dirname(Platform.resolvedExecutable)),
    );
    final candidates = <Directory>[
      Directory(
        p.join(
          contentsDir.path,
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
          contentsDir.path,
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
          contentsDir.path,
          'Resources',
          'flutter_assets',
          'assets',
          'openclaw',
          platformKey,
        ),
      ),
    ];

    for (final dir in candidates) {
      final nodePath = File(p.join(dir.path, spec.nodeExecutable));
      final cliPath = File(p.join(dir.path, spec.cliEntrypoint));
      if (await nodePath.exists() && await cliPath.exists()) {
        return dir;
      }
    }
    _diag(
      'bundle.macos-bundled-runtime-missing',
      data: {
        'platformKey': platformKey,
        'contentsDir': contentsDir.path,
        'candidates': candidates.map((item) => item.path).toList(),
      },
    );
    return null;
  }

  Future<Directory?> _runtimeDirOverride(
    _OpenClawBundleSpec spec,
    String platformKey,
  ) async {
    final raw = _configuredRuntimeDirOverride(platformKey);
    if (raw == null) return null;

    final dir = Directory(raw);
    final nodePath = File(p.join(dir.path, spec.nodeExecutable));
    final cliPath = File(p.join(dir.path, spec.cliEntrypoint));
    final nodeExists = await nodePath.exists();
    final cliExists = await cliPath.exists();
    _diag(
      'bundle.override.paths',
      data: {
        'platformKey': platformKey,
        'runtimeDir': dir.path,
        'nodePath': nodePath.path,
        'nodeExists': nodeExists,
        'cliPath': cliPath.path,
        'cliExists': cliExists,
      },
    );

    if (!nodeExists || !cliExists) {
      throw OpenClawRuntimeException(
        'DACHENG_OPENCLAW_RUNTIME_DIR 指向的 OpenClaw runtime 不完整: ${dir.path}',
      );
    }
    return dir;
  }

  String? _configuredRuntimeDirOverride(String platformKey) {
    final raw = _runtimeDirOverrideDefine.trim().isNotEmpty
        ? _runtimeDirOverrideDefine.trim()
        : Platform.environment['DACHENG_OPENCLAW_RUNTIME_DIR']?.trim();
    if (raw == null || raw.isEmpty) return null;
    return p.normalize(raw.replaceAll('{platform}', platformKey));
  }

  Future<Directory> _legacyRuntimeDir(
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

Object? _decodeJsonOrNull(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

bool _looksLikeHealthPayload(Object? payload) {
  if (payload is! Map) return false;
  if (payload['ok'] == true) return true;
  final status = payload['status']?.toString().toLowerCase();
  return status == 'live' || status == 'ok' || status == 'healthy';
}

bool _looksLikeModelsPayload(Object? payload) {
  if (payload is List) return true;
  if (payload is! Map) return false;
  return payload['data'] is List ||
      payload['models'] is List ||
      payload['object'] == 'list';
}

String _previewBody(String body) {
  final trimmed = body.trim();
  return trimmed.length <= 80 ? trimmed : trimmed.substring(0, 80);
}

String _previewProcessOutput(Object? output) {
  final text = output?.toString().trim() ?? '';
  return text.length <= 200 ? text : text.substring(0, 200);
}
