import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../features/auth/application/auth_model.dart';
import '../models/file_transfer_model.dart'
    if (dart.library.html) '../models/file_transfer_model_web.dart';
import '../models/mini_app_model.dart';
import '../services/ai_backend_policy.dart';
import '../services/dacheng_ai_service.dart';
import '../services/desktop_control/desktop_control_bridge.dart';
import '../services/dharma_publish_service.dart';
import '../services/openclaw/openclaw_runtime.dart';
import '../services/project_service.dart';
import '../widgets/social/social_feature_bot.dart';

class MiniAppHostScreen extends StatefulWidget {
  const MiniAppHostScreen({super.key, required this.bot, this.inline = false});

  final SocialFeatureBot bot;
  final bool inline;

  @override
  State<MiniAppHostScreen> createState() => _MiniAppHostScreenState();
}

class _MiniAppHostScreenState extends State<MiniAppHostScreen> {
  final DachengAiService _aiService = DachengAiService();
  final DharmaPublishService _publishService = DharmaPublishService();
  final http.Client _httpClient = http.Client();
  bool _loading = true;
  String? _error;

  bool get _trustedOfficial => widget.bot.source == MiniAppSource.official;

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_entryUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: false,
            mediaPlaybackRequiresUserGesture: false,
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
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
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onLoadStop: (controller, _) async {
            await controller.evaluateJavascript(source: _hostSdkScript);
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

    if (widget.inline) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(color: const Color(0xFF0F1722), child: content),
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
    final explicitEntryUrl = widget.bot.stableMiniAppEntryUrl;
    if (explicitEntryUrl.isNotEmpty) return explicitEntryUrl;
    final id = Uri.encodeComponent(widget.bot.stableMiniAppId);
    return 'https://fabushi.ombhrum.com/miniapps/$id';
  }

  String get _hostSdkScript {
    return '''
(function () {
  if (window.FabushiMiniApp) return;
  window.FabushiMiniApp = {
    invoke: function(method, params) {
      return window.flutter_inappwebview.callHandler('FabushiMiniAppInvoke', {
        method: method,
        params: params || {}
      });
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
      final data = await _dispatch(method, params);
      return {'ok': true, 'requestId': requestId, 'data': data};
    } catch (error) {
      return {
        'ok': false,
        'requestId': requestId,
        'errorCode': _errorCodeFor(error),
        'message': _friendlyError(error),
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
      case 'app.getTheme':
        return {'theme': _theme()};
      case 'bot.sendMessage':
        return _botSendMessage(params);
      case 'bot.openPanel':
      case 'bot.setPanelState':
        return {'accepted': true};
      case 'ai.chat':
        return _aiChat(params);
      case 'openclaw.chat':
        _requirePermission('openclaw.chat');
        return _aiChat(params);
      case 'dharma.prepareContent':
        return _prepareDharmaContent(params);
      case 'dharma.startGlobalSend':
        return _startGlobalDharma(params);
      case 'dharma.stopGlobalSend':
        return _stopGlobalDharma();
      case 'dharma.getSendStatus':
        return _globalDharmaStatus();
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
      case 'flashcards.createDeck':
      case 'flashcards.openDeck':
        return {
          'accepted': false,
          'message': '闪卡宿主 API 已注册，完整制卡仍由当前机器人聊天流程处理。',
        };
      default:
        throw MiniAppHostException('unknown_method', '未知小程序能力：$method');
    }
  }

  Map<String, dynamic> _appContext() {
    return {
      'hostApiVersion': '1.0',
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

  List<String> _capabilities() {
    final base = <String>{'app.context', 'bot.chat', ...widget.bot.permissions};
    if (!AiBackendPolicy.isDesktopNative) {
      base.removeAll(['openclaw.chat', 'local.loopback', 'desktop.control']);
    }
    return base.toList()..sort();
  }

  Map<String, dynamic> _theme() {
    return {
      'background': '#0F1722',
      'surface': '#17212B',
      'accent': '#3390EC',
      'text': '#FFFFFF',
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

  Future<Map<String, dynamic>> _prepareDharmaContent(
    Map<String, dynamic> params,
  ) async {
    final title = params['title']?.toString().trim() ?? '小程序内容';
    final text = params['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const MiniAppHostException('invalid_request', 'text 不能为空');
    }
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await model.addTextContentForSending(
      title: title,
      text: text,
      sourceKind: '小程序',
      replaceExisting: params['replaceExisting'] != false,
    );
    return {'prepared': true, 'title': title};
  }

  Future<Map<String, dynamic>> _startGlobalDharma(
    Map<String, dynamic> params,
  ) async {
    final text = params['text']?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      await _prepareDharmaContent({
        'title': params['title']?.toString() ?? '小程序法布施',
        'text': text,
        'replaceExisting': params['replaceExisting'] != false,
      });
    }
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    final model = Provider.of<FileTransferModel>(context, listen: false);
    if (!model.hasFiles) {
      throw const MiniAppHostException('invalid_state', '没有可发送的素材');
    }
    model.setGlobalSendEnabled(true);
    model.setCountryList(['ALL']);
    await model.startGlobalTransfer();
    return _globalDharmaStatus();
  }

  Future<Map<String, dynamic>> _stopGlobalDharma() async {
    final model = Provider.of<FileTransferModel>(context, listen: false);
    model.stopTransfer();
    return _globalDharmaStatus();
  }

  Map<String, dynamic> _globalDharmaStatus() {
    final model = Provider.of<FileTransferModel>(context, listen: false);
    return {
      'isPreparingSend': model.isPreparingSend,
      'isTransferring': model.isTransferring,
      'message': model.preparingSendMessage,
      'sentCount': model.globalSentCount,
      'sentMB': model.globalDataSentMB,
      'hasFiles': model.hasFiles,
    };
  }

  Future<Map<String, dynamic>> _createPlatformDraft(
    Map<String, dynamic> params,
  ) async {
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
    final model = Provider.of<FileTransferModel>(context, listen: false);
    final selected = await model.selectFiles(
      replaceExisting: params['replaceExisting'] != false,
    );
    return {'selected': selected, 'hasFiles': model.hasFiles};
  }

  Future<Map<String, dynamic>> _listProjects() async {
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
    final method = (params['method']?.toString().toUpperCase() ?? 'GET');
    final body = params['body']?.toString();
    final request = http.Request(method, uri)
      ..headers.addAll(
        Map<String, String>.from(params['headers'] as Map? ?? const {}),
      );
    if (body != null && body.isNotEmpty) request.body = body;
    final response = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 15));
    final text = await response.stream.bytesToString();
    return {
      'statusCode': response.statusCode,
      'headers': response.headers,
      'body': text,
    };
  }

  bool _isLoopbackHost(String host) {
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  void _requirePermission(String permission) {
    if (widget.bot.permissions.contains(permission)) return;
    throw MiniAppHostException('permission_denied', '小程序未声明或未获准使用 $permission');
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
}

class MiniAppHostException implements Exception {
  final String code;
  final String message;

  const MiniAppHostException(this.code, this.message);

  @override
  String toString() => message;
}
