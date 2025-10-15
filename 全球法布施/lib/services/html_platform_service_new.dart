// HTML平台服务主文件 - 使用条件导入
import 'package:flutter/foundation.dart';

// 条件导入
import 'html_platform_service_stub.dart'
    if (dart.library.html) 'web_html_service.dart'
    if (dart.library.io) 'non_web_html_service.dart';

class HtmlPlatformService {
  final dynamic _impl;
  
  HtmlPlatformService() : _impl = createHtmlService();
  
  void addMessageListener(Function(dynamic) listener) {
    if (kIsWeb) {
      try {
        _impl.addMessageListener(listener);
      } catch (e) {
        debugPrint('添加消息监听器失败: $e');
      }
    }
  }
  
  void removeMessageListener(Function(dynamic) listener) {
    if (kIsWeb) {
      try {
        _impl.removeMessageListener(listener);
      } catch (e) {
        debugPrint('移除消息监听器失败: $e');
      }
    }
  }
  
  void openWindow(String url, String target) {
    if (kIsWeb) {
      try {
        _impl.openWindow(url, target);
      } catch (e) {
        debugPrint('打开窗口失败: $e');
      }
    }
  }
  
  String? getLocalStorageItem(String key) {
    if (kIsWeb) {
      try {
        return _impl.getLocalStorageItem(key);
      } catch (e) {
        debugPrint('获取本地存储失败: $e');
        return null;
      }
    }
    return null;
  }
  
  void setLocalStorageItem(String key, String value) {
    if (kIsWeb) {
      try {
        _impl.setLocalStorageItem(key, value);
      } catch (e) {
        debugPrint('设置本地存储失败: $e');
      }
    }
  }
  
  void removeLocalStorageItem(String key) {
    if (kIsWeb) {
      try {
        _impl.removeLocalStorageItem(key);
      } catch (e) {
        debugPrint('移除本地存储失败: $e');
      }
    }
  }
  
  void dispose() {
    // 清理资源
  }
}