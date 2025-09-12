import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'p2p_network_service_interface.dart';
import 'p2p_network_service_web.dart';
import 'p2p_network_service_mobile.dart';

/// P2P网络服务工厂类
/// 
/// 根据平台自动选择合适的P2P网络服务实现
/// 确保所有发送都是无连接发送，所有平台都是无连接真实发送数据
class P2PNetworkService {
  static P2PNetworkServiceInterface? _instance;
  
  /// 获取平台特定的P2P网络服务实例
  static P2PNetworkServiceInterface getInstance() {
    if (_instance != null) {
      return _instance!;
    }
    
    // 根据平台创建相应的无连接实现
    if (kIsWeb) {
      debugPrint('🌐 创建Web平台无连接P2P服务');
      _instance = P2PNetworkServiceWeb.instance as P2PNetworkServiceInterface;
    } else {
      debugPrint('📱 创建移动平台无连接P2P服务');
      _instance = P2PNetworkServiceMobile();
    }
    
    return _instance!;
  }
  
  /// 重置实例（用于测试或重新初始化）
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
    debugPrint('🔄 P2P服务实例已重置');
  }
  
  // 便捷访问方法，保持向后兼容
  static bool get isInitialized => getInstance().isInitialized;
  static int get connectedPeersCount => getInstance().connectedPeersCount;
  static List<String> get connectedPeerIds => getInstance().connectedPeerIds;
  static bool get isWebRTCSupported => getInstance().isWebRTCSupported;
  static Stream<bool> get onInitialized => getInstance().onInitialized;
  static Stream<int> get onConnectionChanged => getInstance().onConnectionChanged;
  static Stream<Map<String, dynamic>> get onTransferProgress => getInstance().onTransferProgress;
  
  /// 初始化P2P网络服务
  static Future<bool> initialize() async {
    debugPrint('🚀 初始化无连接P2P网络服务...');
    return await getInstance().initialize();
  }
  
  /// 广播文件到所有节点 - 无连接模式
  static Future<Map<String, dynamic>> broadcastFile(PlatformFile file) async {
    debugPrint('📡 开始无连接文件广播: ${file.name}');
    return await getInstance().broadcastFile(file);
  }
  
  /// 本地WiFi无连接发送
  static Future<Map<String, dynamic>> sendToLocalWiFi(PlatformFile file) async {
    debugPrint('📶 开始本地WiFi无连接发送: ${file.name}');
    return await getInstance().sendToLocalWiFi(file);
  }
  
  /// 关闭所有连接
  static Future<bool> closeAllConnections() async {
    debugPrint('🛑 关闭所有无连接通道');
    return await getInstance().closeAllConnections();
  }
  
  /// 释放资源
  static void dispose() {
    getInstance().dispose();
    _instance = null;
    debugPrint('🗑️ P2P服务资源已释放');
  }
}

/// 向后兼容的P2P网络服务类
/// 
/// 保持原有的API接口，内部使用新的工厂模式
@Deprecated('使用 P2PNetworkService.getInstance() 替代')
class P2PNetworkServiceLegacy {
  static final P2PNetworkServiceLegacy _instance = P2PNetworkServiceLegacy._internal();
  factory P2PNetworkServiceLegacy() => _instance;
  
  P2PNetworkServiceInterface get _service => P2PNetworkService.getInstance();
  
  bool get isInitialized => _service.isInitialized;
  int get connectedPeersCount => _service.connectedPeersCount;
  List<String> get connectedPeerIds => _service.connectedPeerIds;
  bool get isWebRTCSupported => _service.isWebRTCSupported;
  Stream<bool> get onInitialized => _service.onInitialized;
  Stream<int> get onConnectionChanged => _service.onConnectionChanged;
  
  P2PNetworkServiceLegacy._internal();
  
  /// 初始化P2P网络服务
  Future<bool> initialize() async => await _service.initialize();
  
  /// 广播文件到所有连接的节点
  Future<Map<String, dynamic>> broadcastFile(PlatformFile file) async => 
      await _service.broadcastFile(file);
  
  /// 本地WiFi发送
  Future<Map<String, dynamic>> sendToLocalWiFi(PlatformFile file) async => 
      await _service.sendToLocalWiFi(file);
  
  /// 关闭所有连接
  Future<bool> closeAllConnections() async => await _service.closeAllConnections();
  
  /// 释放资源
  void dispose() => _service.dispose();
}
