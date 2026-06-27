import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../features/auth/application/auth_model.dart';
import '../features/flashcards/application/content_pipeline.dart';
import '../features/flashcards/application/flashcard_service.dart';
import '../features/flashcards/data/flashcard_repository.dart';
import '../features/flashcards/domain/flashcard_models.dart';
import '../features/flashcards/presentation/flashcard_study_screen.dart';
import '../models/file_transfer_model.dart'
    if (dart.library.html) '../models/file_transfer_model_web.dart';
import '../models/mini_app_model.dart';
import '../services/ai_backend_policy.dart';
import '../services/alipay_service.dart'
    if (dart.library.html) '../services/alipay_service_web.dart';
import '../services/dacheng_ai_service.dart';
import '../services/desktop_control/desktop_control_bridge.dart';
import '../services/dharma_publish_service.dart';
import '../services/membership_service.dart';
import '../services/openclaw/openclaw_runtime.dart';
import '../services/project_service.dart';
import '../widgets/social/social_feature_bot.dart';

class MiniAppHostScreen extends StatefulWidget {
  const MiniAppHostScreen({
    super.key,
    required this.bot,
    this.inline = false,
    this.messageStream,
    this.onCliStart,
    this.onCliLog,
  });

  final SocialFeatureBot bot;
  final bool inline;
  final Stream<String>? messageStream;
  final void Function(String title, String taskId)? onCliStart;
  final void Function(String taskId, String log)? onCliLog;

  @override
  State<MiniAppHostScreen> createState() => _MiniAppHostScreenState();
}

class _MiniAppHostScreenState extends State<MiniAppHostScreen> {
  final DachengAiService _aiService = DachengAiService();
  final DharmaPublishService _publishService = DharmaPublishService();
  final MembershipService _membershipService = MembershipService();
  final AlipayService _alipayService = AlipayService();
  final http.Client _httpClient = http.Client();
  late final FlashcardRepository _flashcardRepository;
  late final ContentPipeline _contentPipeline;
  late final FlashcardService _flashcardService;
  bool _loading = true;
  String? _error;
  
  StreamSubscription<String>? _messageSub;
  InAppWebViewController? _webViewController;
  bool _hostReady = false;
  final List<String> _pendingMessages = [];

  bool get _trustedOfficial => widget.bot.source == MiniAppSource.official;

  @override
  void initState() {
    super.initState();
    _flashcardRepository = FlashcardRepository();
    _contentPipeline = ContentPipeline(
      repository: _flashcardRepository,
      httpClient: _httpClient,
    );
    _flashcardService = FlashcardService(
      repository: _flashcardRepository,
      aiService: _aiService,
    );
    _messageSub = widget.messageStream?.listen(_sendMessageToWeb);
  }

  @override
  void didUpdateWidget(covariant MiniAppHostScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEntryUrl = _entryUrlFor(oldWidget.bot);
    final nextEntryUrl = _entryUrlFor(widget.bot);
    if (oldEntryUrl != nextEntryUrl ||
        oldWidget.bot.stableMiniAppId != widget.bot.stableMiniAppId) {
      _hostReady = false;
      _pendingMessages.clear();
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
      _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(nextEntryUrl)),
      );
    }
    if (widget.messageStream != oldWidget.messageStream) {
      _messageSub?.cancel();
      _messageSub = widget.messageStream?.listen(_sendMessageToWeb);
    }
  }

  void _sendMessageToWeb(String msg) {
    if (_hostReady && _webViewController != null) {
      final script = "window.dispatchEvent(new CustomEvent('fabushi-bot-message', { detail: { text: ${jsonEncode(msg)} } }));";
      _webViewController!.evaluateJavascript(source: script);
    } else {
      _pendingMessages.add(msg);
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
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
            _hostReady = false;
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
            _hostReady = true;
            if (mounted) setState(() => _loading = false);
            
            for (final msg in _pendingMessages) {
              final script = "window.dispatchEvent(new CustomEvent('fabushi-bot-message', { detail: { text: ${jsonEncode(msg)} } }));";
              controller.evaluateJavascript(source: script);
            }
            _pendingMessages.clear();
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
    return _entryUrlFor(widget.bot);
  }

  String _entryUrlFor(SocialFeatureBot bot) {
    final explicitEntryUrl = bot.stableMiniAppEntryUrl;
    if (explicitEntryUrl.isNotEmpty) return explicitEntryUrl;
    final id = Uri.encodeComponent(bot.stableMiniAppId);
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
      case 'app.getHostApiSpec':
        return _hostApiSpec();
      case 'app.getTheme':
        return {'theme': _theme()};
      case 'auth.getSession':
        return _authSession();
      case 'auth.requireLogin':
        return _requireLogin();
      case 'auth.getAccessToken':
        return _authAccessToken();
      case 'payments.alipay.createOrder':
        return _createAlipayOrder(params);
      case 'payments.alipay.pay':
        return _payWithAlipay(params);
      case 'payments.alipay.queryOrder':
        return _queryAlipayOrder(params);
      case 'wifiHotspot.getStatus':
        return _wifiHotspotStatus();
      case 'wifiHotspot.enable':
        return _enableWifiHotspot();
      case 'wifiHotspot.disable':
        return _disableWifiHotspot();
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
      case 'dharma.setSendOptions':
        return _setDharmaSendOptions(params);
      case 'dharma.selectHighEnergyMaterial':
        return _selectHighEnergyMaterial();
      case 'dharma.clearContent':
        return _clearDharmaContent();
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
      case 'fs.writeFile':
        return _fsWriteFile(params);
      case 'fs.readFile':
        return _fsReadFile(params);
      case 'shell.execute':
        return _shellExecute(params);
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
      'hostApiVersion': '1.2',
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

  Map<String, dynamic> _hostApiSpec() {
    return {
      'hostApiVersion': '1.2',
      'invokePattern': 'window.FabushiMiniApp.invoke(method, params)',
      'permissionGroups': {
        'identity': ['auth.session', 'auth.token'],
        'payments': ['payments.alipay'],
        'dharma': ['dharma.share', 'wifi.hotspot', 'local.loopback'],
        'creation': ['flashcards.create', 'platform.publish'],
        'localAutomation': [
          'fs.readWrite',
          'shell.execute',
          'browser.external',
          'desktop.control',
        ],
      },
      'methods': [
        {
          'method': 'app.getContext',
          'permission': 'app.context',
          'description': '读取宿主、小程序、机器人和平台上下文。',
        },
        {
          'method': 'app.getCapabilities',
          'permission': 'app.context',
          'description': '读取当前小程序已获准的权限列表。',
        },
        {
          'method': 'auth.getSession',
          'permission': 'auth.session',
          'description': '读取宿主登录态、脱敏用户资料和会员状态，不返回 token。',
        },
        {
          'method': 'auth.requireLogin',
          'permission': 'auth.session',
          'description': '要求用户登录；未登录时由宿主打开登录页。',
        },
        {
          'method': 'auth.getAccessToken',
          'permission': 'auth.token',
          'description': '读取宿主访问 token，仅给受信小程序或明确授权场景使用。',
        },
        {
          'method': 'payments.alipay.createOrder',
          'permission': 'payments.alipay',
          'description': '可选：用宿主官方支付后台创建支付宝订单；小程序自己的商品和购买记录仍由小程序保存。',
        },
        {
          'method': 'payments.alipay.pay',
          'permission': 'payments.alipay',
          'description': '拉起支付宝 App 支付或网页支付，返回支付结果；宿主不保存小程序购买信息。',
        },
        {
          'method': 'payments.alipay.queryOrder',
          'permission': 'payments.alipay',
          'description': '查询支付宝订单状态，并把支付状态传回小程序自行保存。',
        },
        {
          'method': 'dharma.prepareContent',
          'permission': 'dharma.share',
          'description': '从正文或链接提取可法布施内容。',
        },
        {
          'method': 'dharma.startGlobalSend',
          'permission': 'dharma.share',
          'description': '启动全球法布施发送。',
        },
        {
          'method': 'dharma.selectHighEnergyMaterial',
          'permission': 'dharma.share',
          'description': '选择高能素材；是否已购买由全球法布施小程序自行判断和保存。',
        },
        {
          'method': 'wifiHotspot.enable',
          'permission': 'wifi.hotspot',
          'description': '请求宿主开启或引导开启 Wi-Fi 热点，供本地场能使用。',
        },
        {
          'method': 'flashcards.createDeck',
          'permission': 'flashcards.create',
          'description': '复用宿主背诵闪卡流水线，从正文或链接生成卡组。',
        },
        {
          'method': 'platformPublish.createDraft',
          'permission': 'platform.publish',
          'description': '复用宿主发布草稿生成能力。',
        },
        {
          'method': 'files.pick',
          'permission': 'files.pick',
          'description': '调用宿主文件选择器并把文件加入当前素材。',
        },
        {
          'method': 'fs.writeFile',
          'permission': 'fs.readWrite',
          'description': '写入小程序私有目录或经授权的本地路径。',
        },
        {
          'method': 'fs.readFile',
          'permission': 'fs.readWrite',
          'description': '读取小程序私有目录或经授权的本地路径。',
        },
        {
          'method': 'shell.execute',
          'permission': 'shell.execute',
          'description': '启动本地命令并将日志流回宿主聊天。',
        },
        {
          'method': 'browser.open',
          'permission': 'browser.external',
          'description': '使用系统浏览器打开 URL。',
        },
      ],
    };
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

  Future<Map<String, dynamic>> _requireLogin() async {
    _requirePermission('auth.session');
    final auth = Provider.of<AuthModel?>(context, listen: false);
    if (auth?.isLoggedIn == true) return _authSession();
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    await Navigator.of(context, rootNavigator: true).pushNamed('/login');
    return _authSession();
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

  Future<Map<String, dynamic>> _createAlipayOrder(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('payments.alipay');
    final token = _requireAuthToken();
    final plan = _readProductId(params);
    final useWeb = params['web'] == true || !_isNativeAndroid;
    final result = useWeb
        ? await _membershipService.createAlipayWebOrder(token, plan)
        : await _membershipService.createAlipayOrder(token, plan);
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
    final status = (result['status'] ??
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

  Map<String, dynamic> _wifiHotspotStatus() {
    _requirePermission('wifi.hotspot');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    return {
      'supported': !kIsWeb,
      'enabled': model.isFieldEnergyMode,
      'needsManualAction': model.needsHotspotGuide,
      'message': _hotspotMessageFor(model),
      'platform': _platformLabel,
    };
  }

  Future<Map<String, dynamic>> _enableWifiHotspot() async {
    _requirePermission('wifi.hotspot');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await model.setFieldEnergyMode(true);
    return _wifiHotspotStatus();
  }

  Future<Map<String, dynamic>> _disableWifiHotspot() async {
    _requirePermission('wifi.hotspot');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await model.setFieldEnergyMode(false);
    return _wifiHotspotStatus();
  }

  String _hotspotMessageFor(FileTransferModel model) {
    final message = model.hotspotMessage.trim();
    if (message.isNotEmpty) return message;
    if (model.needsHotspotGuide) return '请按系统提示开启 Wi-Fi 热点';
    if (model.isFieldEnergyMode) return '本地场能已开启';
    return '本地场能未开启';
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
    _requirePermission('dharma.share');
    final content = await _prepareContentFromParams(
      params,
      defaultTitle: '小程序内容',
      sourceApp: '全球法布施小程序',
    );
    if (content.isFailed) {
      throw MiniAppHostException(
        'content_extract_failed',
        content.errorMessage ?? '内容提取失败',
      );
    }
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await model.addTextContentForSending(
      title: content.title,
      text: content.text,
      sourceKind: content.sourceUrl == null ? '小程序' : '链接',
      sourceUrl: content.sourceUrl,
      previewText: content.previewText,
      replaceExisting: params['replaceExisting'] != false,
    );
    return {
      'prepared': true,
      'content': _preparedContentPayload(content),
      'status': _globalDharmaStatus(),
    };
  }

  Future<Map<String, dynamic>> _setDharmaSendOptions(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('dharma.share');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    final regionMode = params['regionMode']?.toString().trim() ?? '';
    final countryCodes = (params['countryCodes'] as List? ?? const [])
        .map((item) => item.toString().trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList();
    final wantsGlobal =
        params['global'] == true ||
        regionMode == 'global' ||
        regionMode == 'countries' ||
        countryCodes.isNotEmpty;
    final touchesGlobal =
        params.containsKey('global') ||
        params.containsKey('countryCodes') ||
        regionMode == 'global' ||
        regionMode == 'countries';

    if (touchesGlobal) {
      model.setGlobalSendEnabled(wantsGlobal);
      model.setCountryList(wantsGlobal ? (countryCodes.isEmpty ? ['ALL'] : countryCodes) : []);
    }

    if (params.containsKey('loop')) {
      model.setLooping(params['loop'] == true);
    }

    if (params.containsKey('fieldEnergy') || regionMode == 'field') {
      final enableFieldEnergy =
          params['fieldEnergy'] == true || regionMode == 'field';
      if (enableFieldEnergy) {
        await _enableWifiHotspot();
      } else {
        await _disableWifiHotspot();
      }
    }

    if (params.containsKey('localLoopback') || regionMode == 'loopback') {
      final enableLoopback =
          params['localLoopback'] == true || regionMode == 'loopback';
      if (enableLoopback) {
        final auth = Provider.of<AuthModel?>(context, listen: false);
        final hasPremiumAccess = auth?.hasPermission('premium') ?? false;
        if (!hasPremiumAccess) {
          throw const MiniAppHostException(
            'membership_required',
            '本地转经轮需要会员权限',
          );
        }
      }
      model.setLocalLoopbackEnabled(enableLoopback);
    }

    return _globalDharmaStatus();
  }

  Future<Map<String, dynamic>> _selectHighEnergyMaterial() async {
    _requirePermission('dharma.share');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await model.addZenBuddhaAssetForSending();
    return _globalDharmaStatus();
  }

  Future<Map<String, dynamic>> _clearDharmaContent() async {
    _requirePermission('dharma.share');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    model.clearFiles();
    return _globalDharmaStatus();
  }

  Future<Map<String, dynamic>> _startGlobalDharma(
    Map<String, dynamic> params,
  ) async {
    _requirePermission('dharma.share');
    final text = params['text']?.toString().trim() ?? '';
    final url = params['url']?.toString().trim() ?? '';
    if (text.isNotEmpty || url.isNotEmpty) {
      await _prepareDharmaContent(params);
    }
    if (!mounted) {
      throw const MiniAppHostException('host_disposed', '小程序宿主已关闭');
    }
    final model = Provider.of<FileTransferModel>(context, listen: false);
    if (!model.hasFiles) {
      throw const MiniAppHostException('invalid_state', '没有可发送的素材');
    }
    await _setDharmaSendOptions(params);
    if (!model.isGlobalSendEnabled &&
        !model.isFieldEnergyMode &&
        !model.isLocalLoopbackEnabled) {
      await _setDharmaSendOptions({
        'global': true,
        'countryCodes': const ['ALL'],
      });
    }
    await model.startGlobalTransfer();
    return _globalDharmaStatus();
  }

  Future<Map<String, dynamic>> _stopGlobalDharma() async {
    _requirePermission('dharma.share');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    model.stopTransfer();
    return _globalDharmaStatus();
  }

  Map<String, dynamic> _globalDharmaStatus() {
    _requirePermission('dharma.share');
    final model = Provider.of<FileTransferModel>(context, listen: false);
    return {
      'isPreparingSend': model.isPreparingSend,
      'isTransferring': model.isTransferring,
      'message': model.preparingSendMessage,
      'sentCount': model.globalSentCount,
      'sentMB': model.globalDataSentMB,
      'hasFiles': model.hasFiles,
      'options': {
        'global': model.isGlobalSendEnabled,
        'countryCodes': model.countryList,
        'loop': model.isLooping,
        'fieldEnergy': model.isFieldEnergyMode,
        'localLoopback': model.isLocalLoopbackEnabled,
      },
      'wifiHotspot': {
        'supported': !kIsWeb,
        'enabled': model.isFieldEnergyMode,
        'needsManualAction': model.needsHotspotGuide,
        'message': _hotspotMessageFor(model),
        'platform': _platformLabel,
      },
      'selectedContent': model.hasFiles
          ? {
              'kind': model.selectedContentKind,
              'title': model.selectedContentTitle,
              'subtitle': model.selectedContentSubtitle,
              'previewText': model.selectedContentPreviewText,
              'sourceUrl': model.selectedContentSourceUrl,
            }
          : null,
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
        sourceType: url == null || url.isEmpty
            ? 'miniapp_text'
            : 'miniapp_url',
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
        builder: (_) => FlashcardStudyScreen(
          deck: deck!,
          repository: _flashcardRepository,
        ),
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

  Future<Map<String, dynamic>> _shellExecute(Map<String, dynamic> params) async {
    _requirePermission('shell.execute');
    if (!AiBackendPolicy.isDesktopNative) {
      throw const MiniAppHostException('unsupported_platform', '当前平台不支持执行终端命令');
    }
    final command = params['command']?.toString().trim() ?? '';
    final arguments = (params['arguments'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final workingDirectory = params['workingDirectory']?.toString();
    final title = params['title']?.toString() ?? '执行终端命令';
    
    if (command.isEmpty) {
      throw const MiniAppHostException('invalid_request', '命令不能为空');
    }

    try {
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      widget.onCliStart?.call(title, taskId);
      
      final process = await Process.start(
        command,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      
      process.stdout.transform(utf8.decoder).listen((data) {
        widget.onCliLog?.call(taskId, data);
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        widget.onCliLog?.call(taskId, data);
      });
      
      final exitCode = await process.exitCode;
      widget.onCliLog?.call(taskId, '\\n[进程已结束，退出码: $exitCode]');
      
      return {
        'ok': exitCode == 0,
        'exitCode': exitCode,
      };
    } catch (e) {
      throw MiniAppHostException('execution_failed', '执行失败: $e');
    }
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
    final miniAppDir = Directory(p.join(docs.path, 'fabushi_miniapps', widget.bot.stableMiniAppId));
    return p.normalize(p.join(miniAppDir.path, inputPath));
  }

  void _requirePermission(String permission) {
    if (widget.bot.permissions.contains(permission)) return;
    throw MiniAppHostException('permission_denied', '小程序未声明或未获准使用 $permission');
  }

  String _requireAuthToken() {
    final auth = Provider.of<AuthModel?>(context, listen: false);
    final token = auth?.authToken;
    if (auth?.isLoggedIn != true || token == null || token.isEmpty) {
      throw const MiniAppHostException('login_required', '请先登录');
    }
    return token;
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
