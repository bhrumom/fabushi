import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../app_settings.dart';
import 'desktop_control_confirmation_store.dart';
import 'desktop_control_host_api.dart';
import 'desktop_control_models.dart';
import 'desktop_control_policy.dart';

class MethodChannelDesktopControlHostApi implements DesktopControlHostApi {
  MethodChannelDesktopControlHostApi([
    this._channel = const MethodChannel('com.ombhrum.fabushi/desktop_control'),
  ]);

  final MethodChannel _channel;

  @override
  Future<Map<String, dynamic>> status() => _invoke('status');

  @override
  Future<Map<String, dynamic>> observe() => _invoke('observe');

  @override
  Future<Map<String, dynamic>> screenshot(Map<String, dynamic> arguments) {
    return _invoke('screenshot', arguments);
  }

  @override
  Future<Map<String, dynamic>> windows() => _invoke('windows');

  @override
  Future<Map<String, dynamic>> click(Map<String, dynamic> arguments) {
    return _invoke('click', arguments);
  }

  @override
  Future<Map<String, dynamic>> type(Map<String, dynamic> arguments) {
    return _invoke('type', arguments);
  }

  @override
  Future<Map<String, dynamic>> hotkey(Map<String, dynamic> arguments) {
    return _invoke('hotkey', arguments);
  }

  @override
  Future<Map<String, dynamic>> scroll(Map<String, dynamic> arguments) {
    return _invoke('scroll', arguments);
  }

  Future<Map<String, dynamic>> _invoke(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final value = await _channel.invokeMapMethod<String, dynamic>(
      method,
      arguments ?? const {},
    );
    return Map<String, dynamic>.from(value ?? const {});
  }
}

class DesktopControlBridge {
  DesktopControlBridge._({
    DesktopControlHostApi? hostApi,
    DesktopControlConfirmationStore? confirmations,
    bool Function()? enabledByBuild,
    String Function()? platformProvider,
    Random? random,
  }) : _hostApi = hostApi ?? MethodChannelDesktopControlHostApi(),
       _confirmations = confirmations ?? DesktopControlConfirmationStore(),
       _enabledByBuild =
           enabledByBuild ?? (() => AppConfig.desktopControlEnabled),
       _platformProvider = platformProvider ?? _detectPlatform,
       _random = random ?? Random.secure();

  @visibleForTesting
  DesktopControlBridge.test({
    DesktopControlHostApi? hostApi,
    DesktopControlConfirmationStore? confirmations,
    bool Function()? enabledByBuild,
    String Function()? platformProvider,
    Random? random,
  }) : this._(
         hostApi: hostApi,
         confirmations: confirmations,
         enabledByBuild: enabledByBuild,
         platformProvider: platformProvider,
         random: random,
       );

  static final DesktopControlBridge instance = DesktopControlBridge._();

  static const Duration _chromeCommandTimeout = Duration(seconds: 12);
  static const Duration _chromeHeartbeatTtl = Duration(seconds: 20);
  static const String _extensionAssetPrefix =
      'assets/desktop_control/chrome_extension/';

  final DesktopControlHostApi _hostApi;
  final DesktopControlConfirmationStore _confirmations;
  final bool Function() _enabledByBuild;
  final String Function() _platformProvider;
  final Random _random;
  final StreamController<void> _confirmationsController =
      StreamController<void>.broadcast();
  final Queue<_ChromeCommand> _chromeCommands = Queue<_ChromeCommand>();
  final Map<String, Completer<Map<String, dynamic>>> _chromeWaiters = {};

  HttpServer? _server;
  Uri? _bridgeUri;
  String? _token;
  DateTime? _chromeLastSeenAt;
  String? _chromeConnectorId;
  String? _chromeExtensionVersion;

  Stream<void> get confirmationsChanged => _confirmationsController.stream;

  Future<String?> get bridgeToken async {
    if (!_enabledByBuild()) return null;
    _token ??= await AppSettings.getDesktopControlBridgeToken();
    return _token;
  }

  Future<DesktopControlBridgeStatus> ensureStarted() async {
    if (!_enabledByBuild()) {
      return _statusWithoutServer(message: '当前构建已禁用桌面控制和 Chrome 连接器');
    }

    final platform = _platformProvider();
    final port = await AppSettings.getDesktopControlBridgePort();
    _token ??= await AppSettings.getDesktopControlBridgeToken();

    if (_server == null) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: true,
        );
        _bridgeUri = Uri.parse('http://127.0.0.1:${_server!.port}');
        unawaited(_serve(_server!));
      } catch (error) {
        return _status(
          platform: platform,
          bridgeRunning: false,
          message: '桌面控制桥启动失败: $error',
        );
      }
    }

    return _status(
      platform: platform,
      bridgeRunning: true,
      message: _platformSupportsSystemControl(platform)
          ? '桌面控制桥已在本机 loopback 运行'
          : '当前 $platform 暂不支持系统级电脑控制',
    );
  }

  Future<DesktopControlBridgeStatus> getStatus() async {
    if (!_enabledByBuild()) {
      return _statusWithoutServer(message: '当前构建已禁用桌面控制和 Chrome 连接器');
    }
    final platform = _platformProvider();
    return _status(
      platform: platform,
      bridgeRunning: _server != null,
      message: _server == null
          ? '桌面控制桥尚未启动'
          : _platformSupportsSystemControl(platform)
          ? '桌面控制桥已在本机 loopback 运行'
          : '当前 $platform 暂不支持系统级电脑控制',
    );
  }

  Future<DesktopControlToolResult> executeTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? confirmationId,
  }) async {
    if (!_enabledByBuild()) {
      return DesktopControlToolResult.failure(
        errorCode: 'disabled_by_build',
        message: '当前构建已禁用桌面控制和 Chrome 连接器',
      );
    }
    if (!DesktopControlPolicy.isSupported(toolName)) {
      return DesktopControlToolResult.failure(
        errorCode: 'unknown_tool',
        message: '未知工具: $toolName',
      );
    }

    final platform = _platformProvider();
    if (toolName.startsWith('desktop.') &&
        !_platformSupportsSystemControl(platform)) {
      return DesktopControlPolicy.unsupportedPlatform(platform);
    }

    if (DesktopControlPolicy.requiresConfirmation(toolName)) {
      final approved =
          confirmationId != null &&
          _confirmations.consumeApproved(
            id: confirmationId,
            toolName: toolName,
            arguments: arguments,
          );
      if (!approved) {
        final pending = _confirmations.create(
          toolName: toolName,
          arguments: arguments,
        );
        _notifyConfirmationChange();
        return DesktopControlToolResult.confirmationRequired(pending);
      }
      _notifyConfirmationChange();
    }

    try {
      if (toolName.startsWith('desktop.')) {
        return DesktopControlToolResult.success(
          await _executeDesktopTool(toolName, arguments),
        );
      }
      return await _executeChromeTool(toolName, arguments);
    } on PlatformException catch (error) {
      return DesktopControlToolResult.failure(
        errorCode: error.code,
        message: error.message ?? error.code,
        recoverable: true,
        data: Map<String, dynamic>.from(error.details as Map? ?? const {}),
      );
    } catch (error) {
      return DesktopControlToolResult.failure(
        errorCode: 'tool_execution_failed',
        message: error.toString(),
      );
    }
  }

  Future<List<DesktopControlPendingConfirmation>> pendingConfirmations() async {
    return _confirmations.list();
  }

  Future<DesktopControlPendingConfirmation?> approvePendingRequest(
    String id,
  ) async {
    final item = _confirmations.approve(id);
    _notifyConfirmationChange();
    return item;
  }

  Future<DesktopControlPendingConfirmation?> rejectPendingRequest(
    String id,
  ) async {
    final item = _confirmations.reject(id);
    _notifyConfirmationChange();
    return item;
  }

  Future<String?> prepareChromeConnectorInstall() async {
    if (!_enabledByBuild()) return null;
    final status = await ensureStarted();
    final token = await bridgeToken;
    if (status.bridgeUri == null || token == null) return null;

    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(support.path, 'desktop_control', 'chrome_extension'),
    );
    await dir.create(recursive: true);

    final assets = await _listAssets(_extensionAssetPrefix);
    for (final asset in assets) {
      if (asset.endsWith('/')) continue;
      final relative = asset.substring(_extensionAssetPrefix.length);
      if (relative.isEmpty) continue;
      final data = await rootBundle.load(asset);
      final file = File(p.join(dir.path, relative));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: false,
      );
    }

    final config = File(p.join(dir.path, 'dacheng-bridge-config.json'));
    await config.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'bridgeUrl': status.bridgeUri.toString(),
        'token': token,
        'note': 'Chrome 扩展选项页使用此本机 loopback 参数连接大乘桌面端。',
      }),
    );

    if (Platform.isMacOS) {
      unawaited(Process.run('open', [dir.path]));
    }
    return dir.path;
  }

  Future<Map<String, dynamic>> _executeDesktopTool(
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    switch (toolName) {
      case 'desktop.observe':
        return _hostApi.observe();
      case 'desktop.screenshot':
        return _hostApi.screenshot(arguments);
      case 'desktop.windows':
        return _hostApi.windows();
      case 'desktop.click':
        return _hostApi.click(arguments);
      case 'desktop.type':
        return _hostApi.type(arguments);
      case 'desktop.hotkey':
        return _hostApi.hotkey(arguments);
      case 'desktop.scroll':
        return _hostApi.scroll(arguments);
      default:
        throw StateError('Unknown desktop tool: $toolName');
    }
  }

  Future<DesktopControlToolResult> _executeChromeTool(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final chromeStatus = _chromeStatus();
    if (!chromeStatus.connected) {
      return DesktopControlToolResult.failure(
        errorCode: 'chrome_connector_not_connected',
        message: 'Chrome 连接器未连接；请在设置页安装并授权扩展',
        recoverable: true,
        data: {'status': chromeStatus.toJson()},
      );
    }

    final id = _newCommandId();
    final completer = Completer<Map<String, dynamic>>();
    _chromeWaiters[id] = completer;
    _chromeCommands.add(
      _ChromeCommand(id: id, toolName: toolName, arguments: arguments),
    );

    try {
      final result = await completer.future.timeout(_chromeCommandTimeout);
      if (result['ok'] == false) {
        return DesktopControlToolResult.failure(
          errorCode: (result['errorCode'] ?? 'chrome_command_failed')
              .toString(),
          message: (result['message'] ?? 'Chrome 命令执行失败').toString(),
          recoverable: true,
          data: Map<String, dynamic>.from(result['data'] as Map? ?? const {}),
        );
      }
      return DesktopControlToolResult.success(
        Map<String, dynamic>.from(result['data'] as Map? ?? result),
      );
    } on TimeoutException {
      _chromeWaiters.remove(id);
      return DesktopControlToolResult.failure(
        errorCode: 'chrome_connector_timeout',
        message: 'Chrome 连接器响应超时',
        recoverable: true,
      );
    }
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleHttpRequest(request));
    }
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    _addCorsHeaders(request);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (!_isAuthorized(request)) {
      await _writeJson(request, HttpStatus.unauthorized, {
        'ok': false,
        'errorCode': 'unauthorized',
        'message': 'Missing or invalid bearer token',
      });
      return;
    }

    try {
      final path = request.uri.path;
      if (request.method == 'GET' &&
          (path == '/status' || path == '/v1/status')) {
        await _writeJson(request, HttpStatus.ok, (await getStatus()).toJson());
        return;
      }
      if (request.method == 'POST' && path == '/v1/tools/execute') {
        final body = await _readJson(request);
        final toolName = (body['tool'] ?? body['toolName'] ?? '').toString();
        final arguments = Map<String, dynamic>.from(
          body['arguments'] as Map? ?? const {},
        );
        final result = await executeTool(
          toolName,
          arguments,
          confirmationId: body['confirmationId']?.toString(),
        );
        await _writeJson(request, HttpStatus.ok, result.toJson());
        return;
      }
      if (request.method == 'GET' && path == '/chrome/commands') {
        await _writeJson(request, HttpStatus.ok, {
          'ok': true,
          'commands': _drainChromeCommands(limit: 4),
        });
        return;
      }
      if (request.method == 'POST' && path == '/chrome/results') {
        final body = await _readJson(request);
        final id = body['id']?.toString() ?? '';
        final completer = _chromeWaiters.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(Map<String, dynamic>.from(body));
        }
        await _writeJson(request, HttpStatus.ok, {'ok': true});
        return;
      }
      if (request.method == 'POST' && path == '/chrome/heartbeat') {
        final body = await _readJson(request);
        _chromeLastSeenAt = DateTime.now();
        _chromeConnectorId = body['connectorId']?.toString();
        _chromeExtensionVersion = body['version']?.toString();
        await _writeJson(request, HttpStatus.ok, {
          'ok': true,
          'status': (await getStatus()).toJson(),
        });
        return;
      }

      await _writeJson(request, HttpStatus.notFound, {
        'ok': false,
        'errorCode': 'not_found',
        'message': 'Unknown route',
      });
    } catch (error) {
      await _writeJson(request, HttpStatus.internalServerError, {
        'ok': false,
        'errorCode': 'bridge_error',
        'message': error.toString(),
      });
    }
  }

  bool _isAuthorized(HttpRequest request) {
    final token = _token;
    if (token == null || token.isEmpty) return false;
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == 'Bearer $token') return true;
    return request.uri.queryParameters['token'] == token;
  }

  void _addCorsHeaders(HttpRequest request) {
    request.response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST, OPTIONS')
      ..set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'Authorization, Content-Type',
      )
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    return Map<String, dynamic>.from(decoded as Map? ?? const {});
  }

  Future<void> _writeJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = statusCode;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  List<Map<String, dynamic>> _drainChromeCommands({required int limit}) {
    final commands = <Map<String, dynamic>>[];
    while (_chromeCommands.isNotEmpty && commands.length < limit) {
      commands.add(_chromeCommands.removeFirst().toJson());
    }
    return commands;
  }

  Future<DesktopControlBridgeStatus> _status({
    required String platform,
    required bool bridgeRunning,
    required String message,
  }) async {
    final hostStatus = _platformSupportsSystemControl(platform)
        ? await _safeHostStatus()
        : const <String, dynamic>{};
    return DesktopControlBridgeStatus(
      enabledByBuild: _enabledByBuild(),
      supportedPlatform: _platformSupportsSystemControl(platform),
      bridgeRunning: bridgeRunning,
      platform: platform,
      message: message,
      bridgeUri: _bridgeUri,
      screenRecordingGranted: hostStatus['screenRecordingGranted'] == true,
      accessibilityGranted: hostStatus['accessibilityGranted'] == true,
      chrome: _chromeStatus(),
      pendingConfirmationCount: _confirmations.list().length,
    );
  }

  DesktopControlBridgeStatus _statusWithoutServer({required String message}) {
    return DesktopControlBridgeStatus(
      enabledByBuild: _enabledByBuild(),
      supportedPlatform: false,
      bridgeRunning: false,
      platform: _platformProvider(),
      message: message,
      screenRecordingGranted: false,
      accessibilityGranted: false,
      chrome: ChromeConnectorStatus.disconnected(message),
      pendingConfirmationCount: _confirmations.list().length,
    );
  }

  Future<Map<String, dynamic>> _safeHostStatus() async {
    try {
      return await _hostApi.status();
    } catch (error) {
      return {'message': error.toString()};
    }
  }

  ChromeConnectorStatus _chromeStatus() {
    final lastSeenAt = _chromeLastSeenAt;
    final connected =
        lastSeenAt != null &&
        DateTime.now().difference(lastSeenAt) <= _chromeHeartbeatTtl;
    return ChromeConnectorStatus(
      connected: connected,
      message: connected ? 'Chrome 连接器已连接' : 'Chrome 连接器未连接',
      connectorId: _chromeConnectorId,
      extensionVersion: _chromeExtensionVersion,
      lastSeenAt: lastSeenAt,
    );
  }

  Future<List<String>> _listAssets(String prefix) async {
    final assets = <String>{};

    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      assets.addAll(decoded.keys.where((key) => key.startsWith(prefix)));
    } catch (_) {
      // Newer Flutter release builds may only include AssetManifest.bin.
    }

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      assets.addAll(
        manifest.listAssets().where((key) => key.startsWith(prefix)),
      );
    } catch (_) {
      // Older Flutter builds or patched archives may still rely on JSON only.
    }

    return assets.toList()..sort();
  }

  void _notifyConfirmationChange() {
    if (!_confirmationsController.isClosed) {
      _confirmationsController.add(null);
    }
  }

  String _newCommandId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    return 'chrome_${millis}_${_random.nextInt(1 << 32)}';
  }

  bool _platformSupportsSystemControl(String platform) => platform == 'macos';

  static String _detectPlatform() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}

class _ChromeCommand {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;

  const _ChromeCommand({
    required this.id,
    required this.toolName,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': toolName,
    'arguments': arguments,
  };
}
