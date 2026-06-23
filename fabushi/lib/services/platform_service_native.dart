import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 平台服务抽象类
abstract class PlatformService {
  /// 获取当前URL
  String get currentUrl;

  /// 替换当前历史记录状态
  void replaceHistoryState(String url);

  /// 监听消息事件
  void listenToMessages(Function(dynamic) handler);

  /// 打开URL
  void openUrl(String url, String target);

  /// 清理资源
  void dispose();
}

/// 非Web平台服务实现
class NativePlatformService implements PlatformService {
  static final Set<String> _handledInitialLinks = <String>{};
  static final Set<String> _dispatchedLinks = <String>{};

  MethodChannel? _channel;
  Function(dynamic)? _messageHandler;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  NativePlatformService() {
    _appLinks = AppLinks();
  }

  @override
  String get currentUrl => '';

  @override
  void replaceHistoryState(String url) {
    // 非Web平台不需要实现
  }

  @override
  void listenToMessages(Function(dynamic) handler) {
    try {
      _messageHandler = handler;

      // 使用 app_links 监听深度链接
      debugPrint('NativePlatformService: 开始监听深度链接回调');

      // 监听应用运行时的链接
      _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        debugPrint('NativePlatformService: 收到深度链接: $uri');
        _handleDeepLink(uri.toString());
      });

      // 检查应用启动时的初始链接
      _checkInitialLink();

      // 同时保留MethodChannel监听（兼容macOS）
      _channel = const MethodChannel('com.globaldharma.alipay/callback');
      _channel!.setMethodCallHandler(_handleMethodCall);
    } catch (e) {
      debugPrint('NativePlatformService: 设置消息监听失败: $e');
    }
  }

  // 检查应用启动时的初始链接
  Future<void> _checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        debugPrint('NativePlatformService: 检测到初始深度链接: $uri');
        _handleDeepLink(uri.toString(), isInitialLink: true);
      }
    } catch (e) {
      debugPrint('NativePlatformService: 检查初始链接失败: $e');
    }
  }

  // 处理深度链接
  void _handleDeepLink(String url, {bool isInitialLink = false}) {
    debugPrint('NativePlatformService: 处理深度链接URL: $url');

    // Tobias SDK 在 Android 上回调到 pubspec 里声明的 url_scheme。
    if (url.startsWith('com.ombhrum.fabushi://') ||
        url.startsWith('globaldharma://') ||
        url.startsWith('fabushi://')) {
      if (isInitialLink && !_handledInitialLinks.add(url)) {
        debugPrint('NativePlatformService: 忽略已处理过的初始深度链接');
        return;
      }

      if (!_dispatchedLinks.add(url)) {
        debugPrint('NativePlatformService: 忽略重复深度链接');
        return;
      }

      if (_dispatchedLinks.length > 20) {
        _dispatchedLinks.remove(_dispatchedLinks.first);
      }

      if (_messageHandler != null) {
        _messageHandler!(url);
      }
    }
  }

  // 处理方法调用（兼容macOS）
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('NativePlatformService: 收到方法调用: ${call.method}');

    switch (call.method) {
      case 'handleAlipayCallback':
        final url = call.arguments as String?;
        debugPrint('NativePlatformService: 收到支付宝回调URL: $url');
        if (url != null && _messageHandler != null) {
          _messageHandler!(url);
        }
        return null;
      default:
        return null;
    }
  }

  @override
  void openUrl(String url, String target) {
    // 非Web平台不需要实现，使用url_launcher处理
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _linkSubscription?.cancel();
    _messageHandler = null;
  }
}

/// 平台服务工厂
class PlatformServiceFactory {
  static PlatformService create() {
    return NativePlatformService();
  }
}
