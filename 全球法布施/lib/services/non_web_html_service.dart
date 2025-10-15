// 非Web平台HTML服务实现（空实现）
import 'package:flutter/foundation.dart';

class NonWebHtmlService {
  static NonWebHtmlService? _instance;
  
  factory NonWebHtmlService() {
    _instance ??= NonWebHtmlService._internal();
    return _instance!;
  }
  
  NonWebHtmlService._internal();
  void addMessageListener(Function(dynamic) listener) {
    debugPrint('非Web平台：消息监听器未实现');
  }
  
  void removeMessageListener(Function(dynamic) listener) {
    debugPrint('非Web平台：移除消息监听器未实现');
  }
  
  void openWindow(String url, String target) {
    debugPrint('非Web平台：打开窗口未实现');
  }
  
  String? getLocalStorageItem(String key) {
    debugPrint('非Web平台：获取本地存储未实现');
    return null;
  }
  
  void setLocalStorageItem(String key, String value) {
    debugPrint('非Web平台：设置本地存储未实现');
  }
  
  void removeLocalStorageItem(String key) {
    debugPrint('非Web平台：移除本地存储未实现');
  }
}

NonWebHtmlService createHtmlService() => NonWebHtmlService();