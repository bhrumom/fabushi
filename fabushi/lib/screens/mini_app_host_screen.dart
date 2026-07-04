import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../features/auth/application/auth_model.dart';
import '../features/flashcards/application/content_pipeline.dart';
import '../features/flashcards/application/flashcard_service.dart';
import '../features/flashcards/data/flashcard_repository.dart';
import '../features/flashcards/domain/flashcard_models.dart';
import '../features/flashcards/presentation/flashcard_study_screen.dart';
import '../models/file_transfer_model.dart'
    if (dart.library.html) '../models/file_transfer_model_web.dart';
import '../models/mini_app_host_spec_generated.dart';
import '../models/mini_app_model.dart';
import '../services/ai_backend_policy.dart';
import '../services/alipay_service.dart'
    if (dart.library.html) '../services/alipay_service_web.dart';
import '../services/dacheng_ai_service.dart';
import '../services/desktop_control/desktop_control_bridge.dart';
import '../services/dharma_publish_service.dart';
import '../services/hotspot_manager_service.dart';
import '../services/miniapp/miniapp_host_policy.dart';
import '../services/miniapp/rust_miniapp_runtime.dart';
import '../services/membership_service.dart';
import '../services/openclaw/openclaw_runtime.dart';
import '../services/project_service.dart';
import '../widgets/social/social_feature_bot.dart';

typedef MiniAppHostEventCallback = void Function(Map<String, dynamic> event);

class MiniAppHostCommand {
  MiniAppHostCommand({
    required this.text,
    String? commandId,
    String? command,
    String? args,
    this.background = true,
    DateTime? createdAt,
  }) : commandId = commandId ?? 'cmd_${DateTime.now().microsecondsSinceEpoch}',
       command = command ?? _defaultCommandFor(text),
       args = args ?? _defaultArgsFor(text),
       createdAt = createdAt ?? DateTime.now();

  final String commandId;
  final String text;
  final String command;
  final String args;
  final bool background;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': commandId,
    'commandId': commandId,
    'command': command,
    'args': args,
    'text': text,
    'rawText': text,
    'background': background,
    'source': 'chat',
    'createdAt': createdAt.toIso8601String(),
  };

  static String _defaultCommandFor(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('/')) return '/start';
    final firstSpace = trimmed.indexOf(RegExp(r'\s'));
    return firstSpace < 0 ? trimmed : trimmed.substring(0, firstSpace);
  }

  static String _defaultArgsFor(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('/')) return trimmed;
    final firstSpace = trimmed.indexOf(RegExp(r'\s'));
    if (firstSpace < 0) return '';
    return trimmed.substring(firstSpace).trim();
  }
}

class MiniAppHostController {
  _MiniAppHostScreenState? _state;
  Completer<_MiniAppHostScreenState> _attachedCompleter =
      Completer<_MiniAppHostScreenState>();

  bool get isAttached => _state != null;

  void _attach(_MiniAppHostScreenState state) {
    _state = state;
    if (!_attachedCompleter.isCompleted) {
      _attachedCompleter.complete(state);
    }
  }

  void _detach(_MiniAppHostScreenState state) {
    if (!identical(_state, state)) return;
    _state = null;
    if (_attachedCompleter.isCompleted) {
      _attachedCompleter = Completer<_MiniAppHostScreenState>();
    }
  }

  Future<Map<String, dynamic>> runCommand(
    String text, {
    String? command,
    String? args,
    String? commandId,
    bool background = true,
  }) async {
    final state = await _waitForAttached();
    return state._runCommand(
      MiniAppHostCommand(
        text: text,
        command: command,
        args: args,
        commandId: commandId,
        background: background,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getCommands() async {
    final state = await _waitForAttached();
    await state._waitForHostReady();
    return state._getExposedBotCommands();
  }

  Future<Map<String, dynamic>> getComposerState() async {
    final state = await _waitForAttached();
    await state._waitForHostReady();
    return state._botGetComposerState(const {});
  }

  Future<_MiniAppHostScreenState> _waitForAttached() async {
    final state = _state;
    if (state != null) return state;
    return _attachedCompleter.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw const MiniAppHostException('host_not_ready', '小程序后台尚未挂载');
      },
    );
  }
}

class MiniAppHostScreen extends StatefulWidget {
  const MiniAppHostScreen({
    super.key,
    required this.bot,
    this.inline = false,
    this.headless = false,
    this.onMinimize,
    this.onClose,
    this.startParam,
    this.controller,
    this.onMiniAppEvent,
    this.onCliStart,
    this.onCliLog,
    this.reloadToken,
    this.onComposerStateRequest,
  });

  final SocialFeatureBot bot;
  final bool inline;
  final bool headless;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;
  final String? startParam;
  final MiniAppHostController? controller;
  final MiniAppHostEventCallback? onMiniAppEvent;
  final void Function(String title, String taskId)? onCliStart;
  final void Function(String taskId, String data)? onCliLog;
  final String? reloadToken;
  final Map<String, dynamic> Function()? onComposerStateRequest;

  @override
  State<MiniAppHostScreen> createState() => _MiniAppHostScreenState();
}

class _MiniAppHostScreenState extends State<MiniAppHostScreen> {
  final DachengAiService _aiService = DachengAiService();
  final DharmaPublishService _publishService = DharmaPublishService();
  final MembershipService _membershipService = MembershipService();
  final AlipayService _alipayService = AlipayService();
  final HotspotManagerService _hotspotManager = HotspotManagerService();
  final http.Client _httpClient = http.Client();
  final RustMiniAppRuntime _rustRuntime = RustMiniAppRuntime.instance;
  final Map<String, RawDatagramSocket> _udpSockets = {};
  late final FlashcardRepository _flashcardRepository;
  late final ContentPipeline _contentPipeline;
  late final FlashcardService _flashcardService;
  int? _rustRuntimeClientId;
  var _rustRuntimeRequestSequence = 0;
  bool _rustRuntimeStorageConfigured = false;
  Future<void>? _rustRuntimeStorageConfigureFuture;
  var _udpSocketSequence = 0;
  var _keepAwakeEnabled = false;
  bool _loading = true;
  String? _error;

  InAppWebViewController? _webViewController;
  bool _hostReady = false;
  Completer<void> _hostReadyCompleter = Completer<void>();
  final Map<String, Map<String, dynamic>> _exposedBotCommands = {};
  final List<Map<String, dynamic>> _pendingBotCommands = [];
  final String _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

  bool get _trustedOfficial => widget.bot.source == MiniAppSource.official;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _seedBuiltInBotCommands();
    _flashcardRepository = FlashcardRepository();
    _contentPipeline = ContentPipeline(
      repository: _flashcardRepository,
      httpClient: _httpClient,
    );
    _flashcardService = FlashcardService(
      repository: _flashcardRepository,
      aiService: _aiService,
    );
  }

  @override
  void didUpdateWidget(covariant MiniAppHostScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    final oldEntryUrl = _entryUrlFor(oldWidget.bot);
    final nextEntryUrl = _entryUrlFor(widget.bot);

    if (oldEntryUrl != nextEntryUrl ||
        oldWidget.bot.stableMiniAppId != widget.bot.stableMiniAppId ||
        oldWidget.startParam != widget.startParam ||
        oldWidget.reloadToken != widget.reloadToken) {
      _markHostNotReady();
      _exposedBotCommands.clear();
      _seedBuiltInBotCommands();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    for (final socket in _udpSockets.values) {
      socket.close();
    }
    _udpSockets.clear();
    final runtimeClientId = _rustRuntimeClientId;
    if (runtimeClientId != null) {
      unawaited(
        _rustRuntime
            .closeClient(runtimeClientId)
            .catchError((_) => <String, dynamic>{'closed': false}),
      );
      _rustRuntimeClientId = null;
    }
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        InAppWebView(
          key: ValueKey(_entryUrl),
          initialUrlRequest: URLRequest(url: WebUri(_entryUrl)),
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: _hostSdkScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              contentWorld: ContentWorld.PAGE,
            ),
          ]),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: false,
            mediaPlaybackRequiresUserGesture: false,
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
            controller.addJavaScriptHandler(
              handlerName: 'FabushiMiniAppInvoke',
              callback: (args) async {
                final request = args.isNotEmpty && args.first is Map
                    ? Map<String, dynamic>.from(args.first as Map)
                    : <String, dynamic>{};
                return _handleInvoke(request);
              },
            );
          },
          onLoadStart: (controller, url) {
            _markHostNotReady();
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onLoadStop: (controller, _) async {
            _webViewController = controller;
            await controller.evaluateJavascript(source: _hostSdkScript);
            _markHostReady();
            if (mounted) setState(() => _loading = false);
          },
          onReceivedError: (controller, request, error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = error.description;
              });
            }
          },
        ),
        if (_loading)
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                '小程序加载失败：$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
      ],
    );

    if (widget.headless) {
      return ColoredBox(color: const Color(0xFF0F1722), child: content);
    }

    if (widget.inline) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: const Color(0xFF0F1722),
          child: Column(
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF17212B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.bot.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.white70,
                      ),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (widget.onMinimize != null) ...[
                      const SizedBox(width: 16),
                      IconButton(
                        tooltip: '收起到后台',
                        icon: const Icon(
                          Icons.keyboard_tab,
                          size: 20,
                          color: Colors.white70,
                        ),
                        onPressed: widget.onMinimize,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: '关闭并销毁',
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1722),
      appBar: AppBar(
        title: Text(widget.bot.title),
        backgroundColor: const Color(0xFF17212B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: content),
    );
  }

  String get _entryUrl {
    return _entryUrlFor(widget.bot);
  }

  String _entryUrlFor(SocialFeatureBot bot) {
    final explicitEntryUrl = bot.stableMiniAppEntryUrl;
    var base = explicitEntryUrl.isNotEmpty
        ? explicitEntryUrl
        : 'https://fabushi.ombhrum.com/miniapps/${Uri.encodeComponent(bot.stableMiniAppId)}';

    final uri = Uri.parse(base);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['_t'] = _cacheBuster;
    if (widget.startParam != null && widget.startParam!.isNotEmpty) {
      queryParams['tgWebAppStartParam'] = base64UrlEncode(
        utf8.encode(widget.startParam!),
      );
    }
    if (widget.reloadToken != null && widget.reloadToken!.isNotEmpty) {
      queryParams['_cmd'] = widget.reloadToken!;
    }
    return uri.replace(queryParameters: queryParams).toString();
  }

  void _markHostNotReady() {
    _hostReady = false;
    if (_hostReadyCompleter.isCompleted) {
      _hostReadyCompleter = Completer<void>();
    }
  }

  void _markHostReady() {
    _hostReady = true;
    if (!_hostReadyCompleter.isCompleted) {
      _hostReadyCompleter.complete();
    }
  }

  Future<void> _waitForHostReady() async {
    if (_hostReady && _webViewController != null) return;
    await _hostReadyCompleter.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw const MiniAppHostException('host_not_ready', '小程序后台加载超时');
      },
    );
  }

  void _seedBuiltInBotCommands() {
    final description = switch (widget.bot.effectiveKind) {
      MiniAppBotKind.globalDharma => '启动全球法布施',
      MiniAppBotKind.flashcards => '开始制作背诵闪卡',
      MiniAppBotKind.platformPublish => '生成平台发布草稿',
      MiniAppBotKind.botFather ||
      MiniAppBotKind.assistant ||
      MiniAppBotKind.thirdParty => null,
    };
    if (description == null) return;
    _exposedBotCommands['/start'] = {
      'command': '/start',
      'description': description,
      'source': 'manifest',
      'registeredAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _waitForCommandExposed(String command) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (_exposedBotCommands.containsKey(command)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw MiniAppHostException(
      'command_not_exposed',
      '小程序未暴露 $command 能力',
      data: {
        'command': command,
        'exposedCommands': _exposedBotCommands.keys.toList(),
      },
    );
  }

  Future<Map<String, dynamic>> _runCommand(MiniAppHostCommand command) async {
    await _waitForHostReady();
    final controller = _webViewController;
    if (controller == null) {
      throw const MiniAppHostException('host_not_ready', '小程序后台尚未就绪');
    }
    await _waitForCommandExposed(command.command);
    final commandJson = command.toJson();
    _enqueueBotCommand(commandJson);
    final payload = jsonEncode(commandJson);
    await controller.evaluateJavascript(
      source:
          '''
(function () {
  var detail = $payload;
  if (window.FabushiMiniApp && window.FabushiMiniApp.__deliverCommand) {
    window.FabushiMiniApp.__deliverCommand(detail);
    return;
  }
  window.__fabushiLastMiniAppCommand = detail;
  window.__fabushiMiniAppCommandQueue = window.__fabushiMiniAppCommandQueue || [];
  window.__fabushiMiniAppCommandQueue.push(detail);
  try {
    var commandQueue = JSON.parse(window.localStorage.getItem('__fabushiMiniAppCommandQueue') || '[]');
    commandQueue.push(detail);
    window.localStorage.setItem('__fabushiMiniAppCommandQueue', JSON.stringify(commandQueue.slice(-50)));
  } catch (e) {}
  window.dispatchEvent(new CustomEvent('fabushi-miniapp-command', { detail: detail }));
})();
''',
    );
    return {
      'accepted': true,
      'delivered': true,
      'queued': true,
      'commandId': command.commandId,
      'command': command.command,
      'args': command.args,
      'background': command.background,
    };
  }

  void _enqueueBotCommand(Map<String, dynamic> command) {
    _pendingBotCommands.add(command);
    if (_pendingBotCommands.length > 50) {
      _pendingBotCommands.removeRange(0, _pendingBotCommands.length - 50);
    }
  }

  Map<String, dynamic> _takePendingBotCommands(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    final requestedCommand = params['command']?.toString().trim();
    final taken = <Map<String, dynamic>>[];
    final kept = <Map<String, dynamic>>[];
    for (final command in _pendingBotCommands) {
      if (requestedCommand == null ||
          requestedCommand.isEmpty ||
          command['command']?.toString() == requestedCommand) {
        taken.add(command);
      } else {
        kept.add(command);
      }
    }
    _pendingBotCommands
      ..clear()
      ..addAll(kept);
    return {'commands': taken};
  }

  String get _hostSdkScript {
    return '''
(function () {
  if (window.FabushiMiniApp) return;
  function invoke(method, params) {
    return window.flutter_inappwebview.callHandler('FabushiMiniAppInvoke', {
      method: method,
      params: params || {}
    });
  }
  function commandKey(detail) {
    if (!detail || typeof detail !== "object") return "";
    return detail.commandId ||
      detail.id ||
      [detail.createdAt, detail.command, detail.rawText || detail.text]
        .filter(Boolean)
        .join(":");
  }
  function readStoredCommandQueue() {
    try {
      var raw = window.localStorage.getItem('__fabushiMiniAppCommandQueue') || '[]';
      var parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }
  function writeStoredCommandQueue(queue) {
    try {
      window.localStorage.setItem('__fabushiMiniAppCommandQueue', JSON.stringify(queue.slice(-50)));
    } catch (e) {}
  }
  function rememberCommand(detail) {
    window.__fabushiLastMiniAppCommand = detail;
    window.__fabushiMiniAppCommandQueue = window.__fabushiMiniAppCommandQueue || [];
    window.__fabushiMiniAppCommandQueue.push(detail);
    var stored = readStoredCommandQueue();
    stored.push(detail);
    writeStoredCommandQueue(stored);
    try {
      var log = JSON.parse(window.localStorage.getItem('__fabushiMiniAppCommandLog') || '[]');
      log.push(detail);
      window.localStorage.setItem('__fabushiMiniAppCommandLog', JSON.stringify(log.slice(-50)));
    } catch (e) {}
  }
  function queuedCommands() {
    var commands = [];
    if (window.__fabushiLastMiniAppCommand) commands.push(window.__fabushiLastMiniAppCommand);
    if (Array.isArray(window.__fabushiMiniAppCommandQueue)) {
      commands = commands.concat(window.__fabushiMiniAppCommandQueue);
      window.__fabushiMiniAppCommandQueue = [];
    }
    commands = commands.concat(readStoredCommandQueue());
    writeStoredCommandQueue([]);
    return commands;
  }
  function deliverCommand(callback, seen, detail) {
    if (!detail || typeof detail !== "object") return;
    var key = commandKey(detail);
    if (key) {
      if (seen.has(key)) return;
      seen.add(key);
    }
    callback(detail);
  }
  function drainQueuedCommands(callback, seen) {
    var commands = queuedCommands();
    commands.forEach(function(detail) {
      deliverCommand(callback, seen, detail);
    });
  }
  function onAnyCommand(callback) {
    var seen = new Set();
    var handler = function(event) {
      deliverCommand(callback, seen, event && event.detail);
    };
    window.addEventListener("fabushi-miniapp-command", handler);
    (window.queueMicrotask || function(fn) { setTimeout(fn, 0); })(function() {
      drainQueuedCommands(callback, seen);
    });
    return function() {
      window.removeEventListener("fabushi-miniapp-command", handler);
    };
  }
  function onCommand(command, callback) {
    return onAnyCommand(function(detail) {
      if (detail.command === command) callback(detail.args || "", detail);
    });
  }
  function exposeCommand(command, callback, options) {
    options = options || {};
    var commands = [{
      command: command,
      description: options.description || ''
    }];
    invoke('bot.setCommands', { commands: commands }).catch(function() {});
    return onCommand(command, callback);
  }
  function deliverFromHost(detail) {
    rememberCommand(detail);
    window.dispatchEvent(new CustomEvent('fabushi-miniapp-command', { detail: detail }));
  }
  window.FabushiMiniApp = {
    version: '$miniAppHostSdkVersion',
    invoke: invoke,
    __deliverCommand: deliverFromHost,
    app: {
      getContext: function() { return invoke('app.getContext'); },
      getCapabilities: function() { return invoke('app.getCapabilities'); },
      requestCapabilities: function(params) { return invoke('app.requestCapabilities', params || {}); },
      getHostApiSpec: function() { return invoke('app.getHostApiSpec'); },
      getTheme: function() { return invoke('app.getTheme'); }
    },
    ui: {
      alert: function(params) { return invoke('ui.alert', params || {}); },
      confirm: function(params) { return invoke('ui.confirm', params || {}); },
      mainButton: {
        set: function(params) { return invoke('ui.mainButton.set', params || {}); }
      }
    },
    haptics: {
      impact: function(params) { return invoke('haptics.impact', params || {}); },
      notification: function(params) { return invoke('haptics.notification', params || {}); },
      selection: function(params) { return invoke('haptics.selection', params || {}); }
    },
    device: {
      biometrics: {
        authenticate: function(params) { return invoke('device.biometrics.authenticate', params || {}); }
      },
      qrScanner: {
        scan: function(params) { return invoke('device.qrScanner.scan', params || {}); }
      }
    },
    cloud: {
      kv: {
        get: function(params) { return invoke('cloud.kv.get', params || {}); },
        set: function(params) { return invoke('cloud.kv.set', params || {}); },
        delete: function(params) { return invoke('cloud.kv.delete', params || {}); }
      }
    },
    share: {
      chat: function(params) { return invoke('share.chat.send', params || {}); }
    },
    auth: {
      getSession: function() { return invoke('auth.getSession'); },
      requireLogin: function() { return invoke('auth.requireLogin'); },
      getAccessToken: function() { return invoke('auth.getAccessToken'); }
    },
    payments: {
      requestPayment: function(params) { return invoke('payments.requestPayment', params || {}); },
      checkEntitlement: function(params) { return invoke('payments.checkEntitlement', params || {}); },
      alipay: {
        createOrder: function(params) { return invoke('payments.alipay.createOrder', params || {}); },
        pay: function(params) { return invoke('payments.alipay.pay', params || {}); },
        queryOrder: function(params) { return invoke('payments.alipay.queryOrder', params || {}); },
        checkEntitlement: function(params) { return invoke('payments.alipay.checkEntitlement', params || {}); }
      }
    },
    wallet: {
      getBalance: function(params) { return invoke('wallet.getBalance', params || {}); }
    },
    bot: {
      sendMessage: function(params) { return invoke('bot.sendMessage', params || {}); },
      postMessage: function(params) { return invoke('bot.postMessage', params || {}); },
      reportCommandResult: function(params) { return invoke('bot.reportCommandResult', params || {}); },
      takePendingCommands: function(params) { return invoke('bot.takePendingCommands', params || {}); },
      openPanel: function(params) { return invoke('bot.openPanel', params || {}); },
      setPanelState: function(params) { return invoke('bot.setPanelState', params || {}); },
      setCommands: function(params) { return invoke('bot.setCommands', params || {}); },
      getCommands: function(params) { return invoke('bot.getCommands', params || {}); },
      setInputPlaceholder: function(params) { return invoke('bot.setInputPlaceholder', typeof params === 'string' ? { placeholder: params } : (params || {})); },
      setComposerText: function(params) { return invoke('bot.setComposerText', typeof params === 'string' ? { text: params } : (params || {})); },
      getComposerState: function(params) { return invoke('bot.getComposerState', params || {}); },
      close: function(params) { return invoke('bot.close', params || {}); },
      onAnyCommand: onAnyCommand,
      onCommand: onCommand,
      exposeCommand: exposeCommand
    },
    network: {
      http: {
        fetch: function(params) { return invoke('network.http.fetch', params || {}); }
      },
      udp: {
        open: function(params) { return invoke('network.udp.open', params || {}); },
        send: function(params) { return invoke('network.udp.send', params || {}); },
        broadcast: function(params) { return invoke('network.udp.broadcast', params || {}); },
        close: function(params) { return invoke('network.udp.close', params || {}); }
      },
      interfaces: {
        list: function(params) { return invoke('network.interfaces.list', params || {}); }
      }
    },
    system: {
      keepAwake: function(params) { return invoke('system.keepAwake', params || {}); }
    },
    hotspot: {
      openSettings: function(params) { return invoke('hotspot.openSettings', params || {}); }
    },
    ready: true
  };
  window.dispatchEvent(new CustomEvent('fabushi-miniapp-ready'));
})();
''';
  }

  Future<Map<String, dynamic>> _handleInvoke(
    Map<String, dynamic> request,
  ) async {
    final requestId =
        request['requestId']?.toString() ??
        'mini_${DateTime.now().microsecondsSinceEpoch}';
    final method = request['method']?.toString().trim() ?? '';
    final params = Map<String, dynamic>.from(
      request['params'] as Map? ?? const {},
    );

    try {
      final policy = _evaluateMethodPolicy(method);
      if (!policy.allowed) {
        throw MiniAppHostException(
          policy.errorCode,
          policy.message,
          data: policy.toJson(),
        );
      }
      final data = await _dispatch(method, params);
      return {'ok': true, 'requestId': requestId, 'data': data};
    } catch (error) {
      return {
        'ok': false,
        'requestId': requestId,
        'errorCode': _errorCodeFor(error),
        'message': _friendlyError(error),
        if (_errorDataFor(error) != null) 'data': _errorDataFor(error),
      };
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'app.getContext':
        return _appContext();
      case 'app.getCapabilities':
        return {'capabilities': _capabilities()};
      case 'app.requestCapabilities':
        return _requestCapabilities(params);
      case 'app.getHostApiSpec':
        return _hostApiSpec();
      case 'app.getTheme':
        return {'theme': _theme()};
      case 'ui.alert':
        return _uiAlert(params);
      case 'ui.confirm':
        return _uiConfirm(params);
      case 'ui.mainButton.set':
        return _setMainButton(params);
      case 'haptics.impact':
        return _hapticImpact(params);
      case 'haptics.notification':
        return _hapticNotification(params);
      case 'haptics.selection':
        return _hapticSelection(params);
      case 'device.biometrics.authenticate':
        return _adapterUnavailable('device.biometrics');
      case 'device.qrScanner.scan':
        return _adapterUnavailable('device.qrScanner');
      case 'cloud.kv.get':
        return _cloudKvGet(params);
      case 'cloud.kv.set':
        return _cloudKvSet(params);
      case 'cloud.kv.delete':
        return _cloudKvDelete(params);
      case 'runtime.storage.configure':
      case 'runtime.storage.getStatus':
      case 'runtime.storage.put':
      case 'runtime.storage.get':
      case 'runtime.storage.delete':
      case 'runtime.storage.list':
      case 'runtime.storage.snapshot':
      case 'runtime.file.register':
      case 'runtime.file.updateState':
      case 'runtime.file.get':
      case 'runtime.file.list':
      case 'globalDharma.delivery.enqueue':
      case 'globalDharma.delivery.getJob':
      case 'globalDharma.delivery.listJobs':
      case 'globalDharma.delivery.nextRetry':
      case 'globalDharma.delivery.markAttempt':
      case 'globalDharma.delivery.recordReceipt':
      case 'globalDharma.delivery.listReceipts':
        return _invokeRustRuntimeOnly(method, params);
      case 'share.chat.send':
        return _shareChat(params);
      case 'auth.getSession':
        return _authSession();
      case 'auth.requireLogin':
        return _requireLogin();
      case 'auth.getInitData':
        return _signedInitData();
      case 'auth.getScopedToken':
        return _scopedToken(params);
      case 'auth.getAccessToken':
        return _authAccessToken();
      case 'wallet.getBalance':
        return _getWalletBalance(params);
      case 'payments.requestPayment':
        return _requestFudeGoldPayment(params);
      case 'payments.createInvoice':
        return _createInvoice(params);
      case 'payments.openInvoice':
        return _openInvoice(params);
      case 'payments.queryInvoice':
        return _queryInvoice(params);
      case 'payments.checkEntitlement':
      case 'payments.alipay.checkEntitlement':
        return _checkPurchaseEntitlement(params);
      case 'payments.alipay.createOrder':
        return _createAlipayOrder(params);
      case 'payments.alipay.pay':
        return _payWithAlipay(params);
      case 'payments.alipay.queryOrder':
        return _queryAlipayOrder(params);
      case 'network.udp.open':
        return _openUdpSocket(params);
      case 'network.udp.send':
        return _sendUdpPacket(params);
      case 'network.udp.broadcast':
        return _broadcastUdpPacket(params);
      case 'network.udp.close':
        return _closeUdpSocket(params);
      case 'network.interfaces.list':
        return _listNetworkInterfaces(params);
      case 'network.http.fetch':
        return _networkHttpFetch(params);
      case 'system.keepAwake':
        return _setKeepAwake(params);
      case 'hotspot.openSettings':
        return _openHotspotSettings(params);
      case 'bot.sendMessage':
        return _botSendMessage(params);
      case 'bot.postMessage':
        return _botPostMessage(params);
      case 'bot.reportCommandResult':
        return _botReportCommandResult(params);
      case 'bot.takePendingCommands':
        return _takePendingBotCommands(params);
      case 'bot.openPanel':
      case 'bot.setPanelState':
        return {'accepted': true};
      case 'bot.setCommands':
        return _botSetCommands(params);
      case 'bot.getCommands':
        return _botGetCommands(params);
      case 'bot.setInputPlaceholder':
        return _botSetInputPlaceholder(params);
      case 'bot.setComposerText':
        return _botSetComposerText(params);
      case 'bot.getComposerState':
        return _botGetComposerState(params);
      case 'bot.close':
        if (widget.onClose != null) {
          widget.onClose!();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return {'accepted': true};
      case 'ai.chat':
        return _aiChat(params);
      case 'openclaw.chat':
        _requirePermission('openclaw.chat');
        return _aiChat(params);
      case 'platformPublish.createDraft':
        return _createPlatformDraft(params);
      case 'platformPublish.publishDraft':
        return _publishPlatformDraft(params);
      case 'files.pick':
        return _pickFiles(params);
      case 'projects.list':
        return _listProjects();
      case 'projects.select':
        return {'accepted': true};
      case 'openclaw.status':
        return _openClawStatus();
      case 'openclaw.restart':
        return _restartOpenClaw();
      case 'desktopControl.executeTool':
        return _executeDesktopControl(params);
      case 'localLoopback.fetch':
        return _localLoopbackFetch(params);
      case 'fs.writeFile':
        return _fsWriteFile(params);
      case 'fs.readFile':
        return _fsReadFile(params);
      case 'runtime.process.execute':
        return _runtimeProcessExecute(params);
      case 'shell.execute':
        return _runtimeProcessExecute(params, legacyShellPermission: true);
      case 'browser.open':
        return _browserOpen(params);
      case 'flashcards.createDeck':
        return _createFlashcardDeck(params);
      case 'flashcards.openDeck':
        return _openFlashcardDeck(params);
      default:
        throw MiniAppHostException('unknown_method', '未知小程序能力：$method');
    }
  }

  Map<String, dynamic> _appContext() {
    return {
      'hostApiVersion': miniAppHostApiVersion,
      'hostSdkVersion': miniAppHostSdkVersion,
      'bot': {
        'botId': widget.bot.stableBotId,
        'title': widget.bot.title,
        'miniAppId': widget.bot.stableMiniAppId,
        'kind': widget.bot.effectiveKind.storageValue,
        'source': widget.bot.source.storageValue,
      },
      'platform': _platformLabel,
      'trustedOfficial': _trustedOfficial,
    };
  }

  Set<String> _declaredPermissions() {
    return MiniAppHostPolicy.declaredPermissions(widget.bot.permissions);
  }

  MiniAppHostPolicyDecision _evaluateMethodPolicy(String method) {
    return MiniAppHostPolicy.evaluateMethod(
      method: method,
      declaredPermissions: _declaredPermissions(),
      platform: _platformLabel,
      desktopNative: AiBackendPolicy.isDesktopNative,
      nativeIo: !kIsWeb,
      trustedOfficial: _trustedOfficial,
    );
  }

  List<String> _capabilities() {
    return MiniAppHostPolicy.grantedCapabilityIds(
      declaredPermissions: _declaredPermissions(),
      desktopNative: AiBackendPolicy.isDesktopNative,
      nativeIo: !kIsWeb,
      trustedOfficial: _trustedOfficial,
    );
  }

  Map<String, dynamic> _requestCapabilities(Map<String, dynamic> params) {
    return MiniAppHostPolicy.requestCapabilities(
      requested: params['capabilities'] as List? ?? const [],
      declaredPermissions: _declaredPermissions(),
      platform: _platformLabel,
      desktopNative: AiBackendPolicy.isDesktopNative,
      nativeIo: !kIsWeb,
      trustedOfficial: _trustedOfficial,
    );
  }

  Map<String, dynamic> _theme() {
    return {'bg': '#1E1E1E', 'text': '#FFFFFF'};
  }

  Map<String, dynamic> _signedInitData() {
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final user = auth?.currentUser;
    final issuedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'hostApiVersion': miniAppHostApiVersion,
      'userId': user?.userNo ?? user?.username ?? 'anonymous',
      'username': user?.username,
      'botId': widget.bot.stableBotId,
      'miniAppId': widget.bot.stableMiniAppId,
      'origin': Uri.tryParse(_entryUrlFor(widget.bot))?.origin,
      'sessionId': _cacheBuster,
      'auth_date': issuedAt,
    };
    final canonical = jsonEncode(payload);
    final seed = auth?.authToken?.isNotEmpty == true
        ? auth!.authToken!
        : '${widget.bot.stableMiniAppId}:$_cacheBuster';
    final signature = crypto_pkg.Hmac(
      crypto_pkg.sha256,
      utf8.encode(seed),
    ).convert(utf8.encode(canonical)).toString();
    return {
      ...payload,
      'hash': signature,
      'signature': signature,
      'signatureAlgorithm': 'hmac-sha256',
    };
  }

  Map<String, dynamic> _scopedToken(Map<String, dynamic> params) {
    throw const MiniAppHostException(
      'unsupported_auth',
      '暂时不支持生成带有短时过期的 scoped token',
    );
  }

  Future<Map<String, dynamic>> _createInvoice(
    Map<String, dynamic> params,
  ) async {
    final currency =
        params['currency']?.toString().trim().toUpperCase() ?? 'CNY';
    final productId = params['productId']?.toString().trim().isNotEmpty == true
        ? params['productId'].toString().trim()
        : params['sku']?.toString().trim() ??
              params['plan']?.toString().trim() ??
              '';
    if (productId.isEmpty) {
      throw const MiniAppHostException(
        'invalid_request',
        'productId 或 sku 不能为空',
      );
    }
    if (currency == 'CNY') {
      final order = await _createAlipayOrder({
        ...params,
        'productId': productId,
        'plan': productId,
      });
      return {
        ...order,
        'id':
            order['orderId'] ?? 'inv_${DateTime.now().microsecondsSinceEpoch}',
        'invoiceId':
            order['orderId'] ?? 'inv_${DateTime.now().microsecondsSinceEpoch}',
        'sku': productId,
        'currency': currency,
        'status': 'created',
      };
    }
    if (currency == 'FUDE_GOLD') {
      return {
        'id': 'inv_${DateTime.now().microsecondsSinceEpoch}',
        'invoiceId': 'inv_${DateTime.now().microsecondsSinceEpoch}',
        'sku': productId,
        'amount': params['amount'],
        'currency': currency,
        'status': 'created',
        'requiresBackendWallet': true,
      };
    }
    throw MiniAppHostException(
      'invoice_unsupported_currency',
      '不支持的账单币种：$currency',
    );
  }

  Future<Map<String, dynamic>> _openInvoice(Map<String, dynamic> params) async {
    final currency =
        params['currency']?.toString().trim().toUpperCase() ?? 'CNY';
    if (currency == 'FUDE_GOLD') {
      // 兼容 FUDE_GOLD (旧称 FUDE_JIN) 原生拉起
      return _requestFudeGoldPayment(params);
    }
    return _payWithAlipay(params);
  }

  Future<Map<String, dynamic>> _queryInvoice(
    Map<String, dynamic> params,
  ) async {
    final orderId =
        params['orderId']?.toString().trim() ??
        params['invoiceId']?.toString().trim() ??
        '';
    if (orderId.isEmpty) {
      throw const MiniAppHostException(
        'invalid_request',
        'invoiceId/orderId 不能为空',
      );
    }
    return _queryAlipayOrder({'orderId': orderId});
  }

  Map<String, dynamic> _hostApiSpec() {
    return MiniAppHostPolicy.hostApiSpec(
      declaredPermissions: _declaredPermissions(),
      platform: _platformLabel,
      desktopNative: AiBackendPolicy.isDesktopNative,
      nativeIo: !kIsWeb,
      trustedOfficial: _trustedOfficial,
    );
  }

  Future<Map<String, dynamic>> _uiAlert(Map<String, dynamic> params) async {
    _requirePermission('ui.native');
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    final title = params['title']?.toString().trim();
    final message = params['message']?.toString().trim().isNotEmpty == true
        ? params['message'].toString().trim()
        : params['text']?.toString().trim() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title == null || title.isEmpty ? '提示' : title),
        content: Text(message.isEmpty ? ' ' : message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              params['buttonText']?.toString().trim().isNotEmpty == true
                  ? params['buttonText'].toString().trim()
                  : '知道了',
            ),
          ),
        ],
      ),
    );
    return {'accepted': true};
  }

  Future<Map<String, dynamic>> _uiConfirm(Map<String, dynamic> params) async {
    _requirePermission('ui.native');
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    final title = params['title']?.toString().trim();
    final message = params['message']?.toString().trim().isNotEmpty == true
        ? params['message'].toString().trim()
        : params['text']?.toString().trim() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title == null || title.isEmpty ? '确认' : title),
        content: Text(message.isEmpty ? ' ' : message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              params['cancelText']?.toString().trim().isNotEmpty == true
                  ? params['cancelText'].toString().trim()
                  : '取消',
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              params['confirmText']?.toString().trim().isNotEmpty == true
                  ? params['confirmText'].toString().trim()
                  : '确认',
            ),
          ),
        ],
      ),
    );
    return {'confirmed': confirmed == true};
  }

  Map<String, dynamic> _setMainButton(Map<String, dynamic> params) {
    _requirePermission('ui.native');
    return {
      'accepted': true,
      'state': {
        'text': params['text']?.toString() ?? '',
        'visible': params['visible'] == true,
        'enabled': params['enabled'] != false,
        'loading': params['loading'] == true,
      },
    };
  }

  Map<String, dynamic> _hapticImpact(Map<String, dynamic> params) {
    _requirePermission('haptics.feedback');
    final style = params['style']?.toString().trim().toLowerCase();
    switch (style) {
      case 'heavy':
        HapticFeedback.heavyImpact();
        break;
      case 'medium':
        HapticFeedback.mediumImpact();
        break;
      case 'light':
      default:
        HapticFeedback.lightImpact();
        break;
    }
    return {'accepted': true, 'style': style ?? 'light'};
  }

  Map<String, dynamic> _hapticNotification(Map<String, dynamic> params) {
    _requirePermission('haptics.feedback');
    HapticFeedback.vibrate();
    return {
      'accepted': true,
      'type': params['type']?.toString().trim().isNotEmpty == true
          ? params['type'].toString().trim()
          : 'success',
    };
  }

  Map<String, dynamic> _hapticSelection(Map<String, dynamic> params) {
    _requirePermission('haptics.feedback');
    HapticFeedback.selectionClick();
    return {'accepted': true};
  }

  Future<Map<String, dynamic>> _cloudKvGet(Map<String, dynamic> params) async {
    _requirePermission('cloud.kv');
    final key = _requiredString(params['key'], 'key');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_miniAppKvKey(key));
    Object? value;
    if (raw != null) {
      try {
        value = jsonDecode(raw);
      } catch (_) {
        value = raw;
      }
    }
    return {'key': key, 'value': value};
  }

  Future<Map<String, dynamic>> _cloudKvSet(Map<String, dynamic> params) async {
    _requirePermission('cloud.kv');
    final key = _requiredString(params['key'], 'key');
    final value = params['value'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_miniAppKvKey(key), jsonEncode(value));
    return {'ok': true, 'key': key};
  }

  Future<Map<String, dynamic>> _cloudKvDelete(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('cloud.kv');
    final key = _requiredString(params['key'], 'key');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_miniAppKvKey(key));
    return {'ok': true, 'key': key};
  }

  Map<String, dynamic> _shareChat(Map<String, dynamic> params) {
    _requirePermission('share.chat');
    final title = params['title']?.toString().trim() ?? '';
    final text = params['text']?.toString().trim() ?? '';
    final url = params['url']?.toString().trim() ?? '';
    widget.onMiniAppEvent?.call({
      'type': 'share.chat',
      'miniAppId': widget.bot.stableMiniAppId,
      'botId': widget.bot.stableBotId,
      'title': title,
      'text': text,
      'url': url,
      if (params['data'] != null) 'data': params['data'],
      'createdAt': DateTime.now().toIso8601String(),
    });
    return {'accepted': true};
  }

  Map<String, dynamic> _adapterUnavailable(String capabilityId) {
    throw MiniAppHostException(
      'adapter_unavailable',
      '$capabilityId adapter 尚未在当前宿主接入',
      data: {'capability': capabilityId, 'platform': _platformLabel},
    );
  }

  String _miniAppKvKey(String key) {
    final normalized = key.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
    return 'miniapp:${widget.bot.stableMiniAppId}:kv:$normalized';
  }

  Map<String, dynamic> _authSession() {
    _requirePermission('auth.session');
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final user = auth?.currentUser;
    return {
      'authenticated': auth?.isLoggedIn == true,
      'user': user == null
          ? null
          : {
              'username': user.username,
              'userNo': user.userNo,
              'displayName': user.displayName,
              'email': user.email,
              'avatar': user.avatar,
              'alipayLinked': user.alipayUserId?.isNotEmpty == true,
              'isAdmin': user.isAdmin,
            },
      'membership': user == null
          ? null
          : {
              'type': user.membershipType,
              'active': user.hasPremiumMembership,
              'expiresAt': user.membershipExpiry?.toIso8601String(),
              'premium': auth?.hasPremiumAccess == true,
            },
    };
  }

  Future<Map<String, dynamic>> _requireLogin({bool force = false}) async {
    _requirePermission('auth.session');
    final auth = Provider.of<AuthModel?>(context, listen: false);
    if (!force && auth?.isLoggedIn == true) return _authSession();
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    if (force && auth?.isLoggedIn == true) {
      await auth!.logout();
      if (!mounted) {
        throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
      }
    }
    await Navigator.of(context, rootNavigator: true).pushNamed('/login');
    final session = _authSession();
    if (session['authenticated'] != true) {
      throw MiniAppHostException(
        'login_required',
        force ? '登录已过期，请重新登录' : '请先登录',
      );
    }
    return session;
  }

  Map<String, dynamic> _authAccessToken() {
    _requirePermission('auth.token');
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final token = auth?.authToken;
    if (auth?.isLoggedIn != true || token == null || token.isEmpty) {
      throw const MiniAppHostException('login_required', '请先登录');
    }
    return {'token': token, 'tokenType': 'Bearer'};
  }

  Future<Map<String, dynamic>> _getWalletBalance(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('wallet.balance');
    final currency = params['currency']?.toString().trim().toUpperCase();
    final result = await _runMembershipRequestWithAuthRetry(
      (token) => _membershipService.getWalletBalance(
        token,
        currency: currency == null || currency.isEmpty ? 'FUDE_GOLD' : currency,
      ),
    );
    _throwIfAuthFailure(result);
    if (result['success'] != true) {
      throw MiniAppHostException(
        'wallet_balance_failed',
        result['message']?.toString() ?? '查询福德金余额失败',
      );
    }
    return {
      'currency': result['currency'] ?? 'FUDE_GOLD',
      'displayName': result['displayName'] ?? '福德金',
      'balance': result['balance'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> _requestFudeGoldPayment(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('payments.fudeGold');
    final currency =
        (params['currency']?.toString().trim().toUpperCase() ?? 'FUDE_GOLD');
    if (currency != 'FUDE_GOLD') {
      throw const MiniAppHostException('unsupported_currency', '暂仅支持福德金支付');
    }
    final productId = _readProductId(params);
    final amount = _readPaymentAmount(params);
    final rawTitle = params['title']?.toString().trim() ?? '';
    final title = rawTitle.isNotEmpty
        ? rawTitle
        : AppConfig.zenBuddhaAssetDisplayName;
    final confirmed = await _confirmFudeGoldPayment(
      title: title,
      amount: amount,
    );
    if (!confirmed) {
      throw const MiniAppHostException('payment_cancelled', '已取消福德金支付');
    }

    final result = await _runMembershipRequestWithAuthRetry(
      (token) => _membershipService.spendWalletBalance(
        token,
        productId: productId,
        amount: amount,
        currency: currency,
        miniAppId: widget.bot.stableMiniAppId,
        idempotencyKey: params['idempotencyKey']?.toString(),
        description: title,
      ),
    );
    _throwIfAuthFailure(result);
    if (result['success'] != true) {
      final details = result['details'];
      throw MiniAppHostException(
        result['statusCode'] == 402
            ? 'wallet_insufficient_funds'
            : 'wallet_payment_failed',
        result['message']?.toString() ?? '福德金支付失败',
        data: details,
      );
    }

    return {
      'paid': result['paid'] == true,
      'provider': result['provider'] ?? 'fude_gold',
      'currency': result['currency'] ?? currency,
      'productId': result['productId'] ?? productId,
      'amount': result['amount'] ?? amount,
      'transactionId': result['transactionId'],
      'balance': result['balance'],
      'unlocked': result['unlocked'] == true,
      'alreadyProcessed': result['alreadyProcessed'] == true,
    };
  }

  Future<bool> _confirmFudeGoldPayment({
    required String title,
    required int amount,
  }) async {
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认福德金支付'),
        content: Text('是否支付 $amount 福德金解锁「$title」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('支付'),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  Future<Map<String, dynamic>> _createAlipayOrder(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('payments.alipay');
    final plan = _readProductId(params);
    final useWeb = params['web'] == true || !_isNativeAndroid;
    final result = await _runMembershipRequestWithAuthRetry(
      (token) => useWeb
          ? _membershipService.createAlipayWebOrder(token, plan)
          : _membershipService.createAlipayOrder(token, plan),
    );
    _throwIfAuthFailure(result);
    if (result['success'] != true) {
      throw MiniAppHostException(
        'alipay_order_failed',
        result['message']?.toString() ?? '创建支付宝订单失败',
      );
    }
    return {
      'orderId': result['orderId'],
      'amount': result['amount'],
      'plan': result['plan'] ?? plan,
      'productId': plan,
      'productType': result['productType'],
      'paymentUrl': result['paymentUrl'],
      'qrCode': result['qrCode'],
      'orderString': result['orderString'],
      'web': useWeb,
    };
  }

  Future<Map<String, dynamic>> _checkPurchaseEntitlement(
    Map<String, dynamic> params,
  ) async {
    _requireAnyPermission(const [
      'payments.entitlement',
      'payments.alipay',
      'payments.fudeGold',
    ]);
    final productId = _readProductId(params);
    final token = _requireAuthToken();
    final result = await _membershipService.checkPurchaseEntitlement(
      token,
      productId,
    );
    _throwIfAuthFailure(result);
    if (result['success'] != true) {
      throw MiniAppHostException(
        'entitlement_check_failed',
        result['message']?.toString() ?? '查询付费项目状态失败',
      );
    }
    return {
      'productId': result['product'] ?? productId,
      'unlocked': result['unlocked'] == true,
    };
  }

  Future<Map<String, dynamic>> _payWithAlipay(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('payments.alipay');
    final paymentUrl = params['paymentUrl']?.toString().trim() ?? '';
    final orderString = params['orderString']?.toString().trim() ?? '';
    Map<String, dynamic> result;
    if (paymentUrl.isNotEmpty) {
      result = await _alipayService.payWithAlipayWeb(paymentUrl);
    } else if (orderString.isNotEmpty) {
      final init = await _alipayService.initAlipay();
      if (init['success'] != true) {
        throw MiniAppHostException(
          'alipay_unavailable',
          init['message']?.toString() ?? '支付宝不可用',
        );
      }
      result = await _alipayService.payWithAlipay(orderString);
    } else {
      throw const MiniAppHostException('invalid_request', '缺少支付宝支付参数');
    }
    if (result['success'] != true) {
      final status = result['resultStatus']?.toString();
      if (status != '8000' && status != '6004') {
        throw MiniAppHostException(
          'alipay_pay_failed',
          result['message']?.toString() ?? '支付宝支付未完成',
        );
      }
    }
    return _alipayPaymentPayload(params, result);
  }

  Map<String, dynamic> _alipayPaymentPayload(
    Map<String, dynamic> params,
    Map<String, dynamic> result,
  ) {
    final resultStatus = result['resultStatus']?.toString() ?? '';
    final paid = resultStatus == '9000' || result['paid'] == true;
    final pending =
        resultStatus == '8000' ||
        resultStatus == '6004' ||
        result['success'] == true && resultStatus.isEmpty;
    return {
      'provider': 'alipay',
      'orderId': params['orderId'],
      'productId': params['productId'] ?? params['plan'],
      'paid': paid,
      'pending': pending,
      'resultStatus': resultStatus,
      'message': result['message'] ?? result['memo'],
      'rawResult': result,
    };
  }

  Future<Map<String, dynamic>> _queryAlipayOrder(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('payments.alipay');
    final orderId = params['orderId']?.toString().trim() ?? '';
    if (orderId.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'orderId 不能为空');
    }
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final token = auth?.authToken;
    Map<String, dynamic> result;
    if (auth?.isLoggedIn == true && token != null && token.isNotEmpty) {
      result = await _membershipService.queryAlipayOrderStatus(token, orderId);
      if (_isAuthFailureResponse(result)) {
        result = await _membershipService.queryAlipayOrderPublic(orderId);
      }
    } else {
      result = await _membershipService.queryAlipayOrderPublic(orderId);
    }
    return _alipayOrderStatusPayload(orderId, result);
  }

  Map<String, dynamic> _alipayOrderStatusPayload(
    String orderId,
    Map<String, dynamic> result,
  ) {
    final nestedOrder = result['order'] is Map
        ? Map<String, dynamic>.from(result['order'] as Map)
        : const <String, dynamic>{};
    final status =
        (result['status'] ??
                result['tradeStatus'] ??
                result['resultStatus'] ??
                nestedOrder['status'] ??
                nestedOrder['tradeStatus'] ??
                '')
            .toString()
            .toUpperCase();
    final paidStatuses = {'PAID', 'SUCCESS', 'TRADE_SUCCESS', '9000'};
    final pendingStatuses = {'PENDING', 'WAIT_BUYER_PAY', '8000', '6004'};
    return {
      'provider': 'alipay',
      'orderId': orderId,
      'status': status,
      'paid': result['paid'] == true || paidStatuses.contains(status),
      'pending': pendingStatuses.contains(status),
      'rawResult': result,
    };
  }

  Future<Map<String, dynamic>> _invokeRustRuntimeOnly(
    String method,
    Map<String, dynamic> params,
  ) async {
    final result = await _invokeRustRuntimeCapability(method, params);
    if (result != null) return result;
    throw const MiniAppHostException(
      'rust_runtime_unavailable',
      'Rust mini app runtime is not available on this platform.',
    );
  }

  Future<Map<String, dynamic>?> _invokeRustRuntimeCapability(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (kIsWeb || !_rustRuntime.isAvailable) return null;

    final extra =
        'miniapp_${DateTime.now().microsecondsSinceEpoch}_${_rustRuntimeRequestSequence++}';
    final request = <String, dynamic>{
      ...params,
      '@type': method,
      '@extra': extra,
    };

    final int clientId;
    try {
      clientId = _rustRuntimeClientId ??= _rustRuntime.createClient();
      if (method != 'runtime.storage.configure') {
        await _ensureRustRuntimeStorageConfigured();
      }
      await _rustRuntime.send(clientId, request);
    } on RustMiniAppRuntimeException catch (error) {
      if (_isRustRuntimeUnavailable(error)) return null;
      rethrow;
    } on ArgumentError {
      return null;
    }

    final deadline = DateTime.now().add(
      Duration(milliseconds: _runtimeReceiveTimeoutMs(method, params)),
    );
    while (DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      final event = await _rustRuntime.receive(
        clientId,
        timeout: remaining > const Duration(milliseconds: 100)
            ? const Duration(milliseconds: 100)
            : remaining,
      );
      if (event == null) continue;

      _emitRustRuntimeUpdate(event);
      if (event['@extra']?.toString() != extra) continue;

      final eventType = event['@type']?.toString() ?? '';
      if (eventType == 'updateRuntimeRequestAccepted') continue;
      if (eventType == 'error') {
        throw MiniAppHostException(
          event['code']?.toString() ?? 'rust_runtime_error',
          event['message']?.toString() ?? 'Rust runtime request failed.',
          data: event,
        );
      }
      return event;
    }

    throw MiniAppHostException(
      'rust_runtime_timeout',
      'Rust runtime did not return a response for $method in time.',
    );
  }

  int _runtimeReceiveTimeoutMs(String method, Map<String, dynamic> params) {
    final fallback = method == 'network.http.fetch' ? 15000 : 5000;
    final timeoutMs = _readPositiveInt(params['timeoutMs'], fallback: fallback);
    return timeoutMs.clamp(1000, 120000).toInt() + 500;
  }

  bool _isRustRuntimeUnavailable(RustMiniAppRuntimeException error) {
    return error.code == 'rust_runtime_unavailable' ||
        error.code == 'rust_runtime_null_response';
  }

  Future<void> _ensureRustRuntimeStorageConfigured() async {
    if (kIsWeb || _rustRuntimeStorageConfigured) return;
    final pending = _rustRuntimeStorageConfigureFuture;
    if (pending != null) return pending;
    _rustRuntimeStorageConfigureFuture = _configureDefaultRustRuntimeStorage();
    await _rustRuntimeStorageConfigureFuture;
  }

  Future<void> _configureDefaultRustRuntimeStorage() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final snapshotFile = p.join(
        directory.path,
        'fabushi-runtime',
        'local-store.json',
      );
      await _rustRuntime.execute({
        'method': 'runtime.storage.configure',
        'path': snapshotFile,
        'loadExisting': true,
      });
      _rustRuntimeStorageConfigured = true;
    } finally {
      _rustRuntimeStorageConfigureFuture = null;
    }
  }

  void _emitRustRuntimeUpdate(Map<String, dynamic> event) {
    widget.onMiniAppEvent?.call({
      'type': 'runtime.update',
      'miniAppId': widget.bot.stableMiniAppId,
      'botId': widget.bot.stableBotId,
      'runtimeType': event['@type'],
      'event': event,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> _openUdpSocket(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('network.udp');
    if (kIsWeb) {
      throw const MiniAppHostException('unsupported_platform', 'Web 宿主不支持 UDP');
    }
    final runtimeResult = await _invokeRustRuntimeCapability(
      'network.udp.open',
      params,
    );
    if (runtimeResult != null) return runtimeResult;

    final port = _readUdpPort(params['port'], allowZero: true);
    final bindAddress = params['bindAddress']?.toString().trim() ?? '';
    final socket = await RawDatagramSocket.bind(
      bindAddress.isEmpty
          ? InternetAddress.anyIPv4
          : InternetAddress(bindAddress),
      port,
      reuseAddress: params['reuseAddress'] != false,
      reusePort: params['reusePort'] == true,
    );
    socket.broadcastEnabled = params['broadcast'] == true;
    final socketId =
        'udp_${DateTime.now().microsecondsSinceEpoch}_${_udpSocketSequence++}';
    _udpSockets[socketId] = socket;
    return {
      'socketId': socketId,
      'address': socket.address.address,
      'port': socket.port,
      'broadcast': socket.broadcastEnabled,
    };
  }

  Future<Map<String, dynamic>> _sendUdpPacket(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('network.udp');
    final runtimeResult = await _invokeRustRuntimeCapability(
      'network.udp.send',
      params,
    );
    if (runtimeResult != null) return runtimeResult;

    final socketId = _requiredString(params['socketId'], 'socketId');
    final socket = _udpSocketById(socketId);
    final host = _requiredString(params['host'], 'host');
    final port = _readUdpPort(params['port']);
    final payload = _decodeUdpPayload(params['data']);
    final address = await _resolveUdpAddress(host);
    final sentBytes = await _sendUdpPayloadWithRetry(
      socket,
      payload,
      address,
      port,
    );
    return {
      'socketId': socketId,
      'host': address.address,
      'port': port,
      'sentBytes': sentBytes,
      'payloadBytes': payload.length,
    };
  }

  Future<Map<String, dynamic>> _broadcastUdpPacket(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('network.udp');
    final runtimeResult = await _invokeRustRuntimeCapability(
      'network.udp.broadcast',
      params,
    );
    if (runtimeResult != null) return runtimeResult;

    final host = (params['host']?.toString().trim() ?? '').isEmpty
        ? '255.255.255.255'
        : params['host'].toString().trim();
    final port = _readUdpPort(params['port']);
    final payload = _decodeUdpPayload(params['data']);
    final socketId = params['socketId']?.toString().trim() ?? '';
    RawDatagramSocket? temporarySocket;
    final RawDatagramSocket socket;
    if (socketId.isNotEmpty) {
      socket = _udpSocketById(socketId);
    } else {
      temporarySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket = temporarySocket;
    }
    socket.broadcastEnabled = true;
    final address = await _resolveUdpAddress(host);
    try {
      final sentBytes = await _sendUdpPayloadWithRetry(
        socket,
        payload,
        address,
        port,
      );
      return {
        if (socketId.isNotEmpty) 'socketId': socketId,
        'host': address.address,
        'port': port,
        'sentBytes': sentBytes,
        'payloadBytes': payload.length,
        'temporarySocket': socketId.isEmpty,
      };
    } finally {
      temporarySocket?.close();
    }
  }

  Future<Map<String, dynamic>> _closeUdpSocket(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('network.udp');
    final runtimeResult = await _invokeRustRuntimeCapability(
      'network.udp.close',
      params,
    );
    if (runtimeResult != null) return runtimeResult;

    final socketId = _requiredString(params['socketId'], 'socketId');
    final socket = _udpSockets.remove(socketId);
    if (socket == null) {
      throw MiniAppHostException(
        'socket_not_found',
        'UDP socket 不存在：$socketId',
      );
    }
    socket.close();
    return {'closed': true, 'socketId': socketId};
  }

  Future<Map<String, dynamic>> _listNetworkInterfaces(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('network.interfaces');
    if (kIsWeb) {
      throw const MiniAppHostException('unsupported_platform', 'Web 宿主不能列出网卡');
    }
    final includeLoopback = params['includeLoopback'] == true;
    final interfaces = await NetworkInterface.list(
      includeLoopback: includeLoopback,
      type: InternetAddressType.any,
    );
    return {
      'interfaces': [
        for (final item in interfaces)
          {
            'name': item.name,
            'index': item.index,
            'addresses': [
              for (final address in item.addresses)
                {
                  'address': address.address,
                  'type': _addressTypeLabel(address.type),
                  'isLoopback': address.isLoopback,
                  if (_suggestedIpv4Broadcast(address.address) != null)
                    'suggestedBroadcast': _suggestedIpv4Broadcast(
                      address.address,
                    ),
                },
            ],
          },
      ],
      'defaultBroadcast': '255.255.255.255',
    };
  }

  Map<String, dynamic> _setKeepAwake(Map<String, dynamic> params) {
    _requirePermission('system.keepAwake');
    _keepAwakeEnabled = params['enabled'] == true;
    return {
      'enabled': _keepAwakeEnabled,
      'supported': false,
      'platform': _platformLabel,
      'message': _keepAwakeEnabled ? '已记录保持唤醒请求，当前宿主未接入原生唤醒锁' : '已释放保持唤醒请求',
    };
  }

  Future<Map<String, dynamic>> _openHotspotSettings(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('hotspot.settings');
    final result = await _hotspotManager.openHotspotSettings();
    return {
      'opened': result.success,
      'supported': !kIsWeb,
      'needsManualAction': result.needsManualAction,
      'message': result.message,
      'platform': _platformLabel,
    };
  }

  RawDatagramSocket _udpSocketById(String socketId) {
    final socket = _udpSockets[socketId];
    if (socket == null) {
      throw MiniAppHostException(
        'socket_not_found',
        'UDP socket 不存在：$socketId',
      );
    }
    return socket;
  }

  Future<InternetAddress> _resolveUdpAddress(String host) async {
    try {
      final parsed = InternetAddress.tryParse(host);
      if (parsed != null) return parsed;
      final addresses = await InternetAddress.lookup(host);
      return addresses.firstWhere(
        (address) => address.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );
    } catch (error) {
      throw MiniAppHostException('invalid_host', '无法解析 UDP 目标地址：$host');
    }
  }

  Future<int> _sendUdpPayloadWithRetry(
    RawDatagramSocket socket,
    Uint8List payload,
    InternetAddress address,
    int port,
  ) async {
    var sentBytes = 0;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      sentBytes = socket.send(payload, address, port);
      if (sentBytes > 0) return sentBytes;
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 4 * (attempt + 1)));
      }
    }
    return sentBytes;
  }

  Uint8List _decodeUdpPayload(Object? value) {
    final encoded = value?.toString().trim() ?? '';
    if (encoded.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'data 不能为空');
    }
    try {
      return base64Decode(encoded);
    } catch (_) {
      throw const MiniAppHostException(
        'invalid_request',
        'data 必须是 base64 字符串',
      );
    }
  }

  int _readUdpPort(Object? value, {bool allowZero = false}) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    final min = allowZero ? 0 : 1;
    if (parsed == null || parsed < min || parsed > 65535) {
      throw const MiniAppHostException(
        'invalid_request',
        'UDP port 必须是 1-65535',
      );
    }
    return parsed;
  }

  String _requiredString(Object? value, String field) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw MiniAppHostException('invalid_request', '$field 不能为空');
    }
    return text;
  }

  String _addressTypeLabel(InternetAddressType type) {
    if (type == InternetAddressType.IPv4) return 'IPv4';
    if (type == InternetAddressType.IPv6) return 'IPv6';
    return 'any';
  }

  String? _suggestedIpv4Broadcast(String address) {
    final parts = address.split('.');
    if (parts.length != 4 || parts.first == '127') return null;
    final parsed = parts.map(int.tryParse).toList();
    if (parsed.any((part) => part == null || part < 0 || part > 255)) {
      return null;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  List<Map<String, dynamic>> _getExposedBotCommands() {
    final commands = _exposedBotCommands.values
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    commands.sort((a, b) {
      final ai = a['order'] is num ? (a['order'] as num).toInt() : 9999;
      final bi = b['order'] is num ? (b['order'] as num).toInt() : 9999;
      if (ai != bi) return ai.compareTo(bi);
      return (a['command']?.toString() ?? '').compareTo(
        b['command']?.toString() ?? '',
      );
    });
    return commands;
  }

  Map<String, dynamic> _botSetCommands(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    final commands = params['commands'];
    if (commands is! List) {
      throw const MiniAppHostException('invalid_request', 'commands 必须是数组');
    }

    final registered = <Map<String, dynamic>>[];
    for (final item in commands) {
      if (item is! Map) continue;
      final spec = Map<String, dynamic>.from(item);
      final rawCommand = spec['command']?.toString().trim() ?? '';
      if (rawCommand.isEmpty) continue;
      final command = rawCommand.startsWith('/') ? rawCommand : '/$rawCommand';
      final normalizedSpec = <String, dynamic>{
        ...spec,
        'command': command,
        'source': 'mini_app',
        'registeredAt': DateTime.now().toIso8601String(),
      };
      _exposedBotCommands[command] = normalizedSpec;
      registered.add(normalizedSpec);
    }

    widget.onMiniAppEvent?.call({
      'type': 'bot.commandsChanged',
      'miniAppId': widget.bot.stableMiniAppId,
      'botId': widget.bot.stableBotId,
      'commands': _getExposedBotCommands(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    return {
      'accepted': true,
      'commands': registered,
      'exposedCommands': _exposedBotCommands.keys.toList()..sort(),
    };
  }

  Map<String, dynamic> _botGetCommands(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    return {'commands': _getExposedBotCommands()};
  }

  Map<String, dynamic> _botSetInputPlaceholder(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    final placeholder = (params['placeholder'] ?? params['text'] ?? '')
        .toString()
        .trim();
    widget.onMiniAppEvent?.call({
      'type': 'bot.composer.placeholder',
      'miniAppId': widget.bot.stableMiniAppId,
      'botId': widget.bot.stableBotId,
      'placeholder': placeholder,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return {'accepted': true, 'placeholder': placeholder};
  }

  Map<String, dynamic> _botSetComposerText(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    final text = (params['text'] ?? params['value'] ?? '').toString();
    final append = params['append'] == true;
    widget.onMiniAppEvent?.call({
      'type': 'bot.composer.text',
      'miniAppId': widget.bot.stableMiniAppId,
      'botId': widget.bot.stableBotId,
      'text': text,
      'append': append,
      'level': params['status'] == 'failed' ? 'error' : 'info',
      if (params['updateKey'] != null) 'updateKey': params['updateKey'],
      if (params['replaceLast'] != null) 'replaceLast': params['replaceLast'],
      'createdAt': DateTime.now().toIso8601String(),
    });
    return {'accepted': true, 'text': text, 'append': append};
  }

  Map<String, dynamic> _botGetComposerState(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    final state = Map<String, dynamic>.from(
      widget.onComposerStateRequest?.call() ?? const {},
    );
    return {
      'text': state['text']?.toString() ?? '',
      'placeholder': state['placeholder']?.toString() ?? widget.bot.inputHint,
      'botId': widget.bot.stableBotId,
      'miniAppId': widget.bot.stableMiniAppId,
      'commands': _getExposedBotCommands(),
    };
  }

  Future<Map<String, dynamic>> _botSendMessage(
    Map<String, dynamic> params,
  ) async {
    final message = params['message']?.toString().trim() ?? '';
    if (message.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'message 不能为空');
    }
    return _aiChat({'message': message});
  }

  Map<String, dynamic> _botPostMessage(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    final message = params['message']?.toString().trim().isNotEmpty == true
        ? params['message'].toString().trim()
        : params['text']?.toString().trim() ?? '';
    if (message.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'message 不能为空');
    }
    final level = params['level']?.toString().trim().toLowerCase() ?? 'info';
    final event = {
      'type': 'bot.message',
      'miniAppId': widget.bot.stableMiniAppId,
      'botId': widget.bot.stableBotId,
      'text': message,
      'level': level,
      'isError': level == 'error',
      if (params['commandId'] != null) 'commandId': params['commandId'],
      if (params['data'] != null) 'data': params['data'],
      if (params['updateKey'] != null) 'updateKey': params['updateKey'],
      if (params['replaceLast'] != null) 'replaceLast': params['replaceLast'],
      'createdAt': DateTime.now().toIso8601String(),
    };
    widget.onMiniAppEvent?.call(event);
    return {'accepted': true};
  }

  Map<String, dynamic> _botReportCommandResult(Map<String, dynamic> params) {
    _requirePermission('bot.chat');
    final status =
        params['status']?.toString().trim().toLowerCase() ?? 'completed';
    final message = params['message']?.toString().trim().isNotEmpty == true
        ? params['message'].toString().trim()
        : params['text']?.toString().trim() ?? '';
    final event = {
      'type': 'bot.commandResult',
      'miniAppId': widget.bot.stableMiniAppId,
      'botId': widget.bot.stableBotId,
      'status': status,
      'text': message,
      'level': status == 'failed' ? 'error' : 'info',
      'isError': status == 'failed',
      if (params['commandId'] != null) 'commandId': params['commandId'],
      if (params['data'] != null) 'data': params['data'],
      if (params['updateKey'] != null) 'updateKey': params['updateKey'],
      if (params['replaceLast'] != null) 'replaceLast': params['replaceLast'],
      'createdAt': DateTime.now().toIso8601String(),
    };
    widget.onMiniAppEvent?.call(event);
    return {'accepted': true};
  }

  Future<Map<String, dynamic>> _aiChat(Map<String, dynamic> params) async {
    final message = params['message']?.toString().trim() ?? '';
    if (message.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'message 不能为空');
    }
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final result = await _aiService.sendChat(
      message: message,
      token: auth?.authToken,
      username: auth?.currentUser?.username,
      isMember: auth?.hasPermission('premium') ?? false,
      client: {
        'surface': 'mini_app',
        'botId': widget.bot.stableBotId,
        'miniAppId': widget.bot.stableMiniAppId,
      },
    );
    return {
      'conversationId': result.conversationId,
      'message': result.message,
      'provider': result.provider,
      'model': result.model,
    };
  }

  Future<PreparedContent> _prepareContentFromParams(
    Map<String, dynamic> params, {
    required String defaultTitle,
    required String sourceApp,
  }) {
    final title = params['title']?.toString().trim() ?? defaultTitle;
    final text = params['text']?.toString().trim() ?? '';
    final url = params['url']?.toString().trim();
    if (text.isEmpty && (url == null || url.isEmpty)) {
      throw const MiniAppHostException('invalid_request', '请输入链接或正文');
    }
    return _contentPipeline.prepare(
      ContentInput(
        text: text,
        url: url == null || url.isEmpty ? null : url,
        title: title.isEmpty ? defaultTitle : title,
        sourceApp: sourceApp,
        sourceType: url == null || url.isEmpty ? 'miniapp_text' : 'miniapp_url',
      ),
    );
  }

  Map<String, dynamic> _preparedContentPayload(PreparedContent content) {
    return {
      'title': content.title,
      'summary': content.summary,
      'previewText': content.previewText,
      'sourceUrl': content.sourceUrl,
      'charCount': content.charCount,
      'isLong': content.isLong,
      'hasDocument': content.hasDocument,
      'documentId': content.document?.id,
      'errorMessage': content.errorMessage,
    };
  }

  Future<Map<String, dynamic>> _createFlashcardDeck(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('flashcards.create');
    final content = await _prepareContentFromParams(
      params,
      defaultTitle: '背诵内容',
      sourceApp: '背诵闪卡小程序',
    );
    if (content.isFailed) {
      throw MiniAppHostException(
        'content_extract_failed',
        content.errorMessage ?? '内容提取失败',
      );
    }

    final mode = params['mode']?.toString().trim() ?? 'random';
    final maxCards = _readPositiveInt(params['maxCards'], fallback: 36);
    final requirement = params['requirement']?.toString().trim() ?? '';
    final input = FlashcardInput(
      title: content.title,
      text: content.text,
      documentId: content.document?.id,
      sourceUrl: content.sourceUrl,
      requirement: requirement,
      maxCards: maxCards,
    );
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final stream = mode == 'ai'
        ? _flashcardService.generateAiCardsStream(
            input,
            token: auth?.authToken,
            username: auth?.currentUser?.username,
            isMember: auth?.hasPermission('premium') ?? false,
          )
        : _flashcardService.generateRandomClozeStream(input);

    FlashcardDeck? deck;
    var message = '正在制作闪卡...';
    await for (final event in stream) {
      message = event.message;
      if (event.isError) {
        throw MiniAppHostException('flashcards_failed', event.message);
      }
      if (event.isDone) {
        deck = event.deck;
        break;
      }
    }
    final readyDeck = deck;
    if (readyDeck == null) {
      throw const MiniAppHostException('flashcards_failed', '制卡没有返回卡组');
    }
    return {
      'message': message,
      'content': _preparedContentPayload(content),
      'deck': _flashcardDeckPayload(readyDeck),
    };
  }

  Future<Map<String, dynamic>> _openFlashcardDeck(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('flashcards.create');
    final deckId = params['deckId']?.toString().trim() ?? '';
    if (deckId.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'deckId 不能为空');
    }
    final decks = await _flashcardService.listDecks();
    FlashcardDeck? deck;
    for (final item in decks) {
      if (item.id == deckId) {
        deck = item;
        break;
      }
    }
    if (deck == null) {
      throw const MiniAppHostException('deck_not_found', '没有找到这个卡组');
    }
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            FlashcardStudyScreen(deck: deck!, repository: _flashcardRepository),
      ),
    );
    return {'opened': true, 'deckId': deckId};
  }

  Map<String, dynamic> _flashcardDeckPayload(FlashcardDeck deck) {
    return {
      'id': deck.id,
      'title': deck.title,
      'mode': deck.mode.storageValue,
      'modeLabel': deck.mode.label,
      'cardCount': deck.cardCount,
      'cards': [
        for (final card in deck.cards.take(12))
          {
            'id': card.id,
            'front': card.front,
            'back': card.back,
            'answer': card.answer,
            'clozeText': card.clozeText,
            'sourceQuote': card.sourceQuote,
            'tags': card.tags,
          },
      ],
    };
  }

  int _readPositiveInt(Object? value, {required int fallback}) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }

  Future<Map<String, dynamic>> _createPlatformDraft(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('platform.publish');
    final text = params['text']?.toString().trim() ?? '';
    final model = Provider.of<FileTransferModel>(context, listen: false);
    if (text.isNotEmpty) {
      await model.addTextContentForSending(
        title: params['title']?.toString().trim() ?? '小程序发布',
        text: text,
        sourceKind: '小程序',
        replaceExisting: true,
      );
    }
    var draft = _publishService.buildDraftFromModel(model, fallbackText: text);
    if (draft.title.trim().isEmpty) {
      draft = draft.copyWith(title: _publishService.suggestTitle(draft));
    }
    if (draft.body.trim().length < 12) {
      draft = draft.copyWith(body: _publishService.polishBody(draft));
    }
    return {'title': draft.title, 'body': draft.body};
  }

  Future<Map<String, dynamic>> _publishPlatformDraft(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('platform.publish');
    final draftJson = Map<String, dynamic>.from(
      params['draft'] as Map? ?? const {},
    );
    final draft = DharmaPublishDraft(
      title: draftJson['title']?.toString() ?? '',
      body: draftJson['body']?.toString() ?? '',
      sourceUrl: draftJson['sourceUrl']?.toString() ?? '',
      tags: (draftJson['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      createdAt: DateTime.now(),
    );
    final platforms = DharmaPublishService.allPlatforms.take(1).toSet();
    final results = await _publishService.publishDraft(
      draft: draft,
      platforms: platforms,
    );
    return {
      'results': [
        for (final result in results)
          {
            'platform': result.platform.info.shortLabel,
            'message': result.message,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _pickFiles(Map<String, dynamic> params) async {
    _requirePermission('files.pick');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    final selected = await model.selectFiles(
      replaceExisting: params['replaceExisting'] != false,
    );
    return {'selected': selected, 'hasFiles': model.hasFiles};
  }

  Future<Map<String, dynamic>> _listProjects() async {
    _requirePermission('projects.read');
    final projects = await ProjectService.instance.listProjects();
    return {
      'projects': [
        for (final project in projects)
          {
            'name': project.name,
            'path': project.path,
            'isExternal': project.isExternal,
            'updatedAt': project.updatedAt.toIso8601String(),
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _openClawStatus() async {
    _requirePermission('openclaw.status');
    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException(
        'unsupported_platform',
        '当前平台不支持本机 OpenClaw',
      );
    }
    final status = await OpenClawRuntime.instance.getStatus(probe: true);
    return {
      'state': status.state.name,
      'label': status.label,
      'message': status.message,
      'port': status.port,
      'runtimePath': status.runtimePath,
    };
  }

  Future<Map<String, dynamic>> _restartOpenClaw() async {
    _requirePermission('openclaw.restart');
    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException(
        'unsupported_platform',
        '当前平台不支持本机 OpenClaw',
      );
    }
    final status = await OpenClawRuntime.instance.restart();
    return {
      'state': status.state.name,
      'label': status.label,
      'message': status.message,
      'port': status.port,
    };
  }

  Future<Map<String, dynamic>> _executeDesktopControl(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('desktop.control');
    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException('unsupported_platform', '当前平台不支持桌面控制');
    }
    final tool = params['tool']?.toString().trim() ?? '';
    final arguments = Map<String, dynamic>.from(
      params['arguments'] as Map? ?? const {},
    );
    final result = await DesktopControlBridge.instance.executeTool(
      tool,
      arguments,
      confirmationId: params['confirmationId']?.toString(),
      trustedMiniApp: _trustedOfficial,
    );
    return result.toJson();
  }

  Future<Map<String, dynamic>> _localLoopbackFetch(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('local.loopback');
    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException('unsupported_platform', '当前平台不支持本地回环代理');
    }
    final rawUrl = params['url']?.toString().trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !_isLoopbackHost(uri.host)) {
      throw const MiniAppHostException(
        'forbidden_url',
        'localLoopback.fetch 仅允许 localhost / 127.0.0.1 / ::1',
      );
    }
    return _hostHttpFetch(params, uri);
  }

  Future<Map<String, dynamic>> _networkHttpFetch(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('network.http');
    if (kIsWeb) {
      throw const MiniAppHostException(
        'unsupported_platform',
        '当前平台不支持宿主 HTTP 客户端',
      );
    }
    final rawUrl = params['url']?.toString().trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const MiniAppHostException(
        'invalid_url',
        'network.http.fetch 仅支持 http:// 或 https:// URL',
      );
    }
    final runtimeResult = await _invokeRustRuntimeCapability(
      'network.http.fetch',
      params,
    );
    if (runtimeResult != null) return runtimeResult;

    return _hostHttpFetch(params, uri);
  }

  Future<Map<String, dynamic>> _hostHttpFetch(
    Map<String, dynamic> params,
    Uri uri,
  ) async {
    final method = (params['method']?.toString().toUpperCase() ?? 'GET');
    const allowedMethods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'};
    if (!allowedMethods.contains(method)) {
      throw MiniAppHostException(
        'invalid_request',
        '不支持的 HTTP method: $method',
      );
    }

    final timeoutMs = _readPositiveInt(
      params['timeoutMs'],
      fallback: 15000,
    ).clamp(1000, 120000).toInt();
    final maxBodyBytes = _readPositiveInt(
      params['maxBodyBytes'] ?? params['maxBytes'],
      fallback: 2 * 1024 * 1024,
    ).clamp(1, 16 * 1024 * 1024).toInt();
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'text/html,text/plain,application/xhtml+xml,*/*',
        'User-Agent': 'FabushiMiniAppHost/$miniAppHostSdkVersion',
        ...Map<String, String>.from(params['headers'] as Map? ?? const {}),
      });
    final body = params['body'];
    if (body != null) request.body = body.toString();

    final response = await _httpClient
        .send(request)
        .timeout(Duration(milliseconds: timeoutMs));
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      Duration(milliseconds: timeoutMs),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > maxBodyBytes) {
        throw MiniAppHostException(
          'response_too_large',
          'HTTP 响应超过 ${maxBodyBytes}B 限制',
        );
      }
    }
    final bodyTextEncoding = _detectHttpBodyEncoding(bytes, response.headers);
    return {
      'statusCode': response.statusCode,
      'headers': response.headers,
      'body': _decodeHttpBodyBestEffort(bytes, bodyTextEncoding),
      'bodyBase64': base64Encode(bytes),
      'bodyBytes': bytes.length,
      'bodyTextEncoding': bodyTextEncoding,
      'url': uri.toString(),
    };
  }

  String _detectHttpBodyEncoding(List<int> bytes, Map<String, String> headers) {
    final contentType =
        headers['content-type'] ?? headers['Content-Type'] ?? '';
    final headerMatch = RegExp(
      "charset\\s*=\\s*[\"']?([^\\s;\"']+)",
      caseSensitive: false,
    ).firstMatch(contentType);
    final headerEncoding = headerMatch?.group(1)?.trim();
    if (headerEncoding != null && headerEncoding.isNotEmpty) {
      return _normalizeHttpEncodingLabel(headerEncoding);
    }

    final preview = latin1.decode(
      bytes.take(4096).toList(growable: false),
      allowInvalid: true,
    );
    final metaMatch = RegExp(
      "charset\\s*=\\s*[\"']?([^\\s;\"'>]+)",
      caseSensitive: false,
    ).firstMatch(preview);
    final metaEncoding = metaMatch?.group(1)?.trim();
    if (metaEncoding != null && metaEncoding.isNotEmpty) {
      return _normalizeHttpEncodingLabel(metaEncoding);
    }
    return 'utf-8';
  }

  String _normalizeHttpEncodingLabel(String label) {
    final normalized = label.trim().toLowerCase().replaceAll('_', '-');
    switch (normalized) {
      case 'utf8':
      case 'unicode-1-1-utf-8':
        return 'utf-8';
      case 'gb2312':
      case 'gbk':
      case 'gb18030':
      case 'cp936':
        return 'gb18030';
      case 'big-5':
      case 'big5-hkscs':
      case 'x-x-big5':
        return 'big5';
      default:
        return normalized.isEmpty ? 'utf-8' : normalized;
    }
  }

  String _decodeHttpBodyBestEffort(List<int> bytes, String encoding) {
    final normalized = _normalizeHttpEncodingLabel(encoding);
    if (normalized == 'latin1' || normalized == 'iso-8859-1') {
      return latin1.decode(bytes, allowInvalid: true);
    }
    // Flutter/Dart does not ship every legacy web codec such as Big5.
    // Keep bodyBase64 so the WebView can decode with TextDecoder('big5') in JS.
    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _isLoopbackHost(String host) {
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  Future<Map<String, dynamic>> _fsWriteFile(Map<String, dynamic> params) async {
    _requirePermission('fs.readWrite');
    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException('unsupported_platform', '当前平台不支持本地文件操作');
    }
    final path = params['path']?.toString().trim() ?? '';
    final content = params['content']?.toString() ?? '';
    if (path.isEmpty) {
      throw const MiniAppHostException('invalid_request', '路径不能为空');
    }

    // Convert to absolute path if relative, storing in Documents
    final resolvedPath = await _resolvePath(path);
    final file = File(resolvedPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return {'ok': true, 'path': resolvedPath};
  }

  Future<Map<String, dynamic>> _fsReadFile(Map<String, dynamic> params) async {
    _requirePermission('fs.readWrite');
    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException('unsupported_platform', '当前平台不支持本地文件操作');
    }
    final path = params['path']?.toString().trim() ?? '';
    if (path.isEmpty) {
      throw const MiniAppHostException('invalid_request', '路径不能为空');
    }

    final resolvedPath = await _resolvePath(path);
    final file = File(resolvedPath);
    if (!await file.exists()) {
      throw const MiniAppHostException('file_not_found', '文件不存在');
    }
    final content = await file.readAsString();
    return {'ok': true, 'content': content, 'path': resolvedPath};
  }

  Future<Map<String, dynamic>> _runtimeProcessExecute(
    Map<String, dynamic> params, {
    bool legacyShellPermission = false,
  }) async {
    _requirePermission(
      legacyShellPermission ? 'shell.execute' : 'runtime.process',
    );
    final command = params['command']?.toString().trim() ?? '';
    final arguments = (params['arguments'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final workingDirectory = params['workingDirectory']?.toString();
    final title = params['title']?.toString() ?? '执行终端命令';
    final silentCli = params['silentCli'] == true;

    if (command.isEmpty) {
      throw const MiniAppHostException('invalid_request', '命令不能为空');
    }

    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException('unsupported_platform', '当前平台不支持执行终端命令');
    }

    try {
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      if (!silentCli) {
        widget.onCliStart?.call(title, taskId);
      }
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final resolvedCommand = await _resolveRuntimeCommand(command);

      final process = await Process.start(
        resolvedCommand,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: legacyShellPermission || params['runInShell'] == true,
      );

      final stdoutDone = process.stdout.transform(utf8.decoder).forEach((data) {
        stdoutBuffer.write(data);
        if (!silentCli) {
          widget.onCliLog?.call(taskId, data);
        }
      });
      final stderrDone = process.stderr.transform(utf8.decoder).forEach((data) {
        stderrBuffer.write(data);
        if (!silentCli) {
          widget.onCliLog?.call(taskId, data);
        }
      });

      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (!silentCli) {
        widget.onCliLog?.call(taskId, '\\n[进程已结束，退出码: $exitCode]');
      }

      return {
        'ok': exitCode == 0,
        'exitCode': exitCode,
        'stdout': stdoutBuffer.toString(),
        'stderr': stderrBuffer.toString(),
      };
    } catch (e) {
      throw MiniAppHostException('execution_failed', '执行失败: $e');
    }
  }

  Future<String> _resolveRuntimeCommand(String command) async {
    if (command.contains('/') || command.contains('\\')) return command;
    if (command != 'cargo') return command;

    final executable = Platform.isWindows ? 'cargo.exe' : 'cargo';
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final configured = Platform.environment['CARGO'] ?? '';
    final candidates = <String>[
      if (configured.isNotEmpty) configured,
      if (home.isNotEmpty) p.join(home, '.cargo', 'bin', executable),
      if (Platform.isMacOS) '/opt/homebrew/bin/cargo',
      if (Platform.isMacOS) '/usr/local/bin/cargo',
      if (!Platform.isWindows) '/usr/bin/cargo',
      if (Platform.isWindows)
        p.join(
          Platform.environment['USERPROFILE'] ?? '',
          '.cargo',
          'bin',
          executable,
        ),
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if (await File(candidate).exists()) return candidate;
    }
    return command;
  }

  Future<Map<String, dynamic>> _browserOpen(Map<String, dynamic> params) async {
    _requirePermission('browser.external');
    final url = params['url']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'URL不能为空');
    }
    // Simple way to open URL on desktop platforms:
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
      return {'ok': true};
    } catch (e) {
      throw MiniAppHostException('browser_open_failed', '打开浏览器失败: $e');
    }
  }

  Future<String> _resolvePath(String inputPath) async {
    if (p.isAbsolute(inputPath)) return inputPath;
    final docs = await getApplicationDocumentsDirectory();
    final miniAppDir = Directory(
      p.join(docs.path, 'fabushi_miniapps', widget.bot.stableMiniAppId),
    );
    return p.normalize(p.join(miniAppDir.path, inputPath));
  }

  void _requirePermission(String permission) {
    if (_declaredPermissions().contains(permission)) return;
    throw MiniAppHostException('permission_denied', '小程序未声明或未获准使用 $permission');
  }

  void _requireAnyPermission(List<String> permissions) {
    final declared = _declaredPermissions();
    for (final permission in permissions) {
      if (declared.contains(permission)) return;
    }
    throw MiniAppHostException(
      'permission_denied',
      '小程序未声明或未获准使用 ${permissions.join('/')}',
    );
  }

  String _requireAuthToken() {
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final token = auth?.authToken;
    if (auth?.isLoggedIn != true || token == null || token.isEmpty) {
      throw const MiniAppHostException('login_required', '请先登录');
    }
    return token;
  }

  Future<Map<String, dynamic>> _runMembershipRequestWithAuthRetry(
    Future<Map<String, dynamic>> Function(String token) request,
  ) async {
    var token = _requireAuthToken();
    var result = await request(token);
    if (_isAuthFailureResponse(result)) {
      await _requireLogin(force: true);
      token = _requireAuthToken();
      result = await request(token);
    }
    return result;
  }

  bool _isAuthFailureResponse(Map<String, dynamic> result) {
    return result['statusCode'] == 401 || result['errorKey'] == 'INVALID_TOKEN';
  }

  void _throwIfAuthFailure(Map<String, dynamic> result) {
    if (_isAuthFailureResponse(result)) {
      throw const MiniAppHostException('login_required', '登录已过期，请重新登录');
    }
  }

  String _readProductId(Map<String, dynamic> params) {
    final rawProductId = params['productId']?.toString().trim() ?? '';
    final rawPlan = params['plan']?.toString().trim() ?? '';
    final productId = rawProductId.isNotEmpty ? rawProductId : rawPlan;
    if (productId.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'productId 不能为空');
    }
    return productId;
  }

  int _readPaymentAmount(Map<String, dynamic> params) {
    final raw = params['amount'];
    final parsed = switch (raw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    if (parsed == null || parsed <= 0) {
      throw const MiniAppHostException('invalid_request', '福德金金额不能为空');
    }
    return parsed;
  }

  bool get _isNativeAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _errorCodeFor(Object error) {
    if (error is MiniAppHostException) return error.code;
    return 'host_error';
  }

  String _friendlyError(Object error) {
    if (error is MiniAppHostException) return error.message;
    final text = error.toString();
    return text.replaceFirst(RegExp(r'^(Exception|Bad state):\s*'), '');
  }

  Object? _errorDataFor(Object error) {
    if (error is MiniAppHostException) return error.data;
    return null;
  }
}

class MiniAppHostException implements Exception {
  final String code;
  final String message;
  final Object? data;

  const MiniAppHostException(this.code, this.message, {this.data});

  @override
  String toString() => message;
}
