import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Web平台服务实现
class WebPlatformService implements PlatformService {
  @override
  String get currentUrl {
    if (kIsWeb) {
      try {
        // 使用Uri.base来获取当前URL，这在Web平台上可用
        return Uri.base.toString();
      } catch (e) {
        debugPrint('Error getting current URL: $e');
        return '';
      }
    }
    return '';
  }
  
  @override
  void replaceHistoryState(String url) {
    if (kIsWeb) {
      try {
        // 使用Uri来管理URL状态，避免直接使用dart:html
        debugPrint('Replacing history state to: $url');
        // 在Web平台上，我们可以通过路由管理来实现类似功能
      } catch (e) {
        debugPrint('Error replacing history state: $e');
      }
    }
  }
  
  @override
  void listenToMessages(Function(dynamic) handler) {
    if (kIsWeb) {
      try {
        // Web平台的消息监听将通过其他机制实现
        debugPrint('Setting up message listener for Web platform');
        // 这里可以集成其他Web消息机制
      } catch (e) {
        debugPrint('Error setting up message listener: $e');
      }
    }
  }
  
  @override
  void openUrl(String url, String target) {
    if (kIsWeb) {
      try {
        debugPrint('Opening URL: $url with target: $target');
        // 在Web平台上，我们可以通过其他方式处理URL打开
      } catch (e) {
        debugPrint('Error opening URL: $e');
      }
    }
  }
  
  @override
  void dispose() {
    // Web平台不需要特殊清理
  }
}

/// 非Web平台服务实现
class NativePlatformService implements PlatformService {
  MethodChannel? _channel;
  Function(dynamic)? _messageHandler;
  
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
      _channel = const MethodChannel('com.globaldharma.alipay/callback');
      _channel!.setMethodCallHandler(_handleMethodCall);
      debugPrint('NativePlatformService: 开始监听支付宝回调消息');
    } catch (e) {
      debugPrint('NativePlatformService: 设置消息监听失败: $e');
    }
  }
  
  // 处理方法调用
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
    _messageHandler = null;
  }
}

/// 平台服务工厂
class PlatformServiceFactory {
  static PlatformService create() {
    if (kIsWeb) {
      return WebPlatformService();
    } else {
      return NativePlatformService();
    }
  }
}