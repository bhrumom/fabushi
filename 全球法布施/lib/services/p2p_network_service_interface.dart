import 'dart:async';
import 'package:file_picker/file_picker.dart';

/// P2P网络服务接口
/// 
/// 定义了P2P网络服务的通用接口，支持不同平台的实现
abstract class P2PNetworkServiceInterface {
  /// 是否已初始化
  bool get isInitialized;
  
  /// 连接的节点数量
  int get connectedPeersCount;
  
  /// 连接的节点ID列表
  List<String> get connectedPeerIds;
  
  /// 是否支持WebRTC
  bool get isWebRTCSupported;
  
  /// 初始化状态流
  Stream<bool> get onInitialized;
  
  /// 连接状态变化流
  Stream<int> get onConnectionChanged;
  
  /// 传输进度流
  Stream<Map<String, dynamic>> get onTransferProgress;
  
  /// 初始化P2P网络服务
  Future<bool> initialize();
  
  /// 广播文件到所有连接的节点
  Future<Map<String, dynamic>> broadcastFile(PlatformFile file);
  
  /// 本地WiFi发送
  Future<Map<String, dynamic>> sendToLocalWiFi(PlatformFile file);
  
  /// 关闭所有连接
  Future<bool> closeAllConnections();
  
  /// 释放资源
  void dispose();
}

/// P2P网络服务工厂
class P2PNetworkServiceFactory {
  static P2PNetworkServiceInterface? _instance;
  
  /// 获取平台特定的P2P网络服务实例
  static P2PNetworkServiceInterface getInstance() {
    if (_instance != null) {
      return _instance!;
    }
    
    // 根据平台创建相应的实现
    _instance = _createPlatformService();
    return _instance!;
  }
  
  /// 创建平台特定的服务
  static P2PNetworkServiceInterface _createPlatformService() {
    // 这里会在编译时根据平台选择正确的实现
    return P2PNetworkServiceStub();
  }
  
  /// 重置实例（用于测试）
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
}

/// 存根实现（用于不支持的平台）
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
  Future<bool> initialize() async => false;
  
  @override
  Future<Map<String, dynamic>> broadcastFile(PlatformFile file) async {
    return {'success': false, 'message': '当前平台不支持P2P网络服务'};
  }
  
  @override
  Future<Map<String, dynamic>> sendToLocalWiFi(PlatformFile file) async {
    return {'success': false, 'message': '当前平台不支持WiFi发送'};
  }
  
  @override
  Future<bool> closeAllConnections() async => true;
  
  @override
  void dispose() {}
}