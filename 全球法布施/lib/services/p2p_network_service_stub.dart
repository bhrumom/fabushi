import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'p2p_network_service_interface.dart';

/// P2P网络服务存根实现
/// 
/// 用于不支持P2P功能的平台或作为后备实现
class P2PNetworkServiceStub implements P2PNetworkServiceInterface {
  @override
  bool get isInitialized => false;
  
  @override
  int get connectedPeersCount => 0;
  
  @override
  List<String> get connectedPeerIds => [];
  
  @override
  bool get isWebRTCSupported => false;
  
  @override
  Stream<bool> get onInitialized => Stream.value(false);
  
  @override
  Stream<int> get onConnectionChanged => Stream.value(0);
  
  @override
  Stream<Map<String, dynamic>> get onTransferProgress => const Stream.empty();
  
  @override
  Future<bool> initialize() async {
    debugPrint('⚠️ P2P网络服务存根：当前平台不支持P2P功能');
    return false;
  }
  
  @override
  Future<Map<String, dynamic>> broadcastFile(PlatformFile file) async {
    debugPrint('⚠️ P2P网络服务存根：无法广播文件 ${file.name}');
    return {
      'success': false, 
      'message': '当前平台不支持P2P网络服务',
      'platform': 'stub'
    };
  }
  
  @override
  Future<Map<String, dynamic>> sendToLocalWiFi(PlatformFile file) async {
    debugPrint('⚠️ P2P网络服务存根：无法发送到本地WiFi ${file.name}');
    return {
      'success': false, 
      'message': '当前平台不支持WiFi发送',
      'platform': 'stub'
    };
  }
  
  @override
  Future<bool> closeAllConnections() async {
    debugPrint('⚠️ P2P网络服务存根：没有连接需要关闭');
    return true;
  }
  
  @override
  void dispose() {
    debugPrint('⚠️ P2P网络服务存根：资源已释放');
  }
}