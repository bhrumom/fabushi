import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

/// WebAssembly代理服务
/// 
/// 这个服务负责在Web平台上初始化和管理WASM代理，
/// 使Web应用能够通过Service Worker和WebAssembly模拟原生功能。
class WasmProxyService {
  static final WasmProxyService _instance = WasmProxyService._internal();
  factory WasmProxyService() => _instance;
  
  bool _initialized = false;
  bool get isInitialized => _initialized;
  
  // 中继服务器URL
  String _relayServerUrl = 'wss://relay.example.com';
  
  // 创建一个流控制器来监听初始化状态
  final _initializationController = StreamController<bool>.broadcast();
  Stream<bool> get onInitialized => _initializationController.stream;
  
  WasmProxyService._internal();
  
  /// 初始化WASM代理服务
  /// 
  /// 这将检查Service Worker是否已注册，并尝试建立与中继服务器的连接。
  Future<bool> initialize() async {
    if (!kIsWeb) {
      debugPrint('WASM代理服务仅在Web平台上可用');
      return false;
    }
    
    if (_initialized) {
      debugPrint('WASM代理服务已初始化');
      return true;
    }
    
    debugPrint('正在初始化WASM代理服务...');
    
    try {
      // 检查Service Worker是否已注册
      final serviceWorkerSupported = html.window.navigator.serviceWorker != null;
      if (!serviceWorkerSupported) {
        debugPrint('此浏览器不支持Service Worker');
        _initializationController.add(false);
        return false;
      }
      
      // 检查Service Worker是否已激活
      final registration = await html.window.navigator.serviceWorker?.getRegistration();
      if (registration == null) {
        debugPrint('Service Worker未注册');
        _initializationController.add(false);
        return false;
      }
      
      debugPrint('Service Worker已注册: ${registration.scope}');
      
      // 向Service Worker发送初始化消息
      final messageChannel = html.MessageChannel();
      final completer = Completer<bool>();
      
      messageChannel.port1.onMessage.listen((event) {
        final data = event.data;
        if (data is Map && data['type'] == 'init_response') {
          final success = data['success'] as bool;
          debugPrint('WASM代理初始化响应: $success');
          completer.complete(success);
        }
      });
      
      registration.active?.postMessage({
        'type': 'init_wasm_proxy',
        'relayServerUrl': _relayServerUrl,
      }, [messageChannel.port2]);
      
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('WASM代理初始化超时');
          return false;
        },
      );
      
      _initialized = result;
      _initializationController.add(result);
      return result;
    } catch (e) {
      debugPrint('初始化WASM代理时出错: $e');
      _initializationController.add(false);
      return false;
    }
  }
  
  /// 设置中继服务器URL
  void setRelayServerUrl(String url) {
    _relayServerUrl = url;
    if (_initialized) {
      // 如果已初始化，则需要重新初始化以使用新的URL
      _initialized = false;
      initialize();
    }
  }
  
  /// 释放资源
  void dispose() {
    _initializationController.close();
  }
}