// HTML平台服务 - 使用条件导入实现跨平台兼容
import 'package:flutter/foundation.dart';
import 'dart:convert';

// 条件导入
import 'html_platform_service_stub.dart'
    if (dart.library.html) 'web_html_service.dart'
    if (dart.library.io) 'non_web_html_service.dart';

// 抽象接口
abstract class HtmlPlatformServiceInterface {
  void addMessageListener(Function(dynamic) listener);
  void removeMessageListener(Function(dynamic) listener);
  void openWindow(String url, String target);
  String? getLocalStorageItem(String key);
  void setLocalStorageItem(String key, String value);
  void removeLocalStorageItem(String key);
  void dispose();
}

// 主服务类
class HtmlPlatformService implements HtmlPlatformServiceInterface {
  late final dynamic _service;
  
  HtmlPlatformService() {
    _service = createHtmlService();
  }
  
  @override
  void addMessageListener(Function(dynamic) listener) {
    if (kIsWeb) {
      try {
        // 包装监听器以处理Web消息格式
        final wrappedListener = (dynamic data) {
          try {
            listener(data);
          } catch (e) {
            debugPrint('处理Web消息失败: $e');
          }
        };
        _service.addMessageListener(wrappedListener);
      } catch (e) {
        debugPrint('添加Web消息监听器失败: $e');
      }
    }
  }
  
  @override
  void removeMessageListener(Function(dynamic) listener) {
    if (kIsWeb) {
      try {
        _service.removeMessageListener(listener);
      } catch (e) {
        debugPrint('移除Web消息监听器失败: $e');
      }
    }
  }
  
  @override
  void openWindow(String url, String target) {
    if (kIsWeb) {
      try {
        _service.openWindow(url, target);
      } catch (e) {
        debugPrint('打开Web窗口失败: $e');
      }
    }
  }
  
  @override
  String? getLocalStorageItem(String key) {
    if (kIsWeb) {
      try {
        return _service.getLocalStorageItem(key);
      } catch (e) {
        debugPrint('获取Web本地存储失败: $e');
        return null;
      }
    }
    return null;
  }
  
  @override
  void setLocalStorageItem(String key, String value) {
    if (kIsWeb) {
      try {
        _service.setLocalStorageItem(key, value);
      } catch (e) {
        debugPrint('设置Web本地存储失败: $e');
      }
    }
  }
  
  @override
  void removeLocalStorageItem(String key) {
    if (kIsWeb) {
      try {
        _service.removeLocalStorageItem(key);
      } catch (e) {
        debugPrint('移除Web本地存储失败: $e');
      }
    }
  }
  
  @override
  void dispose() {
    // 清理资源
  }
}