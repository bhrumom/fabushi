import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

/// Web 平台服务实现。
///
/// 保持为纯 Flutter/Dart Web 能力，避免在首屏静态导入 app_links、MethodChannel
/// 等原生插件。
class WebPlatformService implements PlatformService {
  @override
  String get currentUrl {
    try {
      return Uri.base.toString();
    } catch (e) {
      debugPrint('Error getting current URL: $e');
      return '';
    }
  }

  @override
  void replaceHistoryState(String url) {
    try {
      debugPrint('Replacing history state to: $url');
    } catch (e) {
      debugPrint('Error replacing history state: $e');
    }
  }

  @override
  void listenToMessages(Function(dynamic) handler) {
    try {
      debugPrint('Setting up lightweight Web message listener');
    } catch (e) {
      debugPrint('Error setting up message listener: $e');
    }
  }

  @override
  void openUrl(String url, String target) {
    try {
      debugPrint('Opening URL: $url with target: $target');
    } catch (e) {
      debugPrint('Error opening URL: $e');
    }
  }

  @override
  void dispose() {
    // Web 平台不需要特殊清理。
  }
}

/// 平台服务工厂
class PlatformServiceFactory {
  static PlatformService create() {
    if (kIsWeb) {
      return WebPlatformService();
    }
    return WebPlatformService();
  }
}
