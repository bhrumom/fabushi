// Web平台HTML服务实现
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class WebHtmlService {
  static WebHtmlService? _instance;
  
  factory WebHtmlService() {
    _instance ??= WebHtmlService._internal();
    return _instance!;
  }
  
  WebHtmlService._internal();
  void addMessageListener(Function(dynamic) listener) {
    try {
      final listenerWrapper = (html.Event event) {
        if (event is html.MessageEvent) {
          listener(event.data);
        }
      };
      html.window.addEventListener('message', listenerWrapper);
    } catch (e) {
      debugPrint('添加Web消息监听器失败: $e');
    }
  }
  
  void removeMessageListener(Function(dynamic) listener) {
    try {
      html.window.removeEventListener('message', listener);
    } catch (e) {
      debugPrint('移除Web消息监听器失败: $e');
    }
  }
  
  void openWindow(String url, String target) {
    try {
      html.window.open(url, target);
    } catch (e) {
      debugPrint('打开Web窗口失败: $e');
    }
  }
  
  String? getLocalStorageItem(String key) {
    try {
      return html.window.localStorage[key];
    } catch (e) {
      debugPrint('获取Web本地存储失败: $e');
      return null;
    }
  }
  
  void setLocalStorageItem(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (e) {
      debugPrint('设置Web本地存储失败: $e');
    }
  }
  
  void removeLocalStorageItem(String key) {
    try {
      html.window.localStorage.remove(key);
    } catch (e) {
      debugPrint('移除Web本地存储失败: $e');
    }
  }
}

WebHtmlService createHtmlService() => WebHtmlService();