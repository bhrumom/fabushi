import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

// 简化的P2P网络服务，兼容所有平台
class P2PNetworkServiceWeb {
  static P2PNetworkServiceWeb? _instance;
  
  P2PNetworkServiceWeb._();
  
  static P2PNetworkServiceWeb get instance {
    _instance ??= P2PNetworkServiceWeb._();
    return _instance!;
  }

  // 连接状态
  bool _isInitialized = false;
  bool _isConnected = false;
  final List<String> _connectedPeers = [];
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  List<String> get connectedPeers => List.unmodifiable(_connectedPeers);

  // 初始化P2P网络
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('P2P网络已经初始化');
      return true;
    }

    try {
      debugPrint('初始化P2P网络服务...');
      
      // 模拟初始化过程
      await Future.delayed(Duration(milliseconds: 800));
      
      _isInitialized = true;
      debugPrint('P2P网络服务初始化成功');
      
      // 模拟自动连接到一些节点
      _simulateAutoConnect();
      
      return true;
    } catch (e) {
      debugPrint('P2P网络初始化失败: $e');
      return false;
    }
  }

  // 模拟自动连接
  void _simulateAutoConnect() {
    Timer(Duration(seconds: 2), () async {
      await connectToPeer('peer_001');
      await connectToPeer('peer_002');
    });
  }

  // 连接到节点
  Future<bool> connectToPeer(String peerId) async {
    if (!_isInitialized) {
      debugPrint('P2P网络未初始化，无法连接节点');
      return false;
    }

    if (_connectedPeers.contains(peerId)) {
      debugPrint('已经连接到节点: $peerId');
      return true;
    }

    try {
      debugPrint('连接到节点: $peerId');
      
      // 模拟连接过程
      await Future.delayed(Duration(milliseconds: 500));
      
      _connectedPeers.add(peerId);
      _isConnected = _connectedPeers.isNotEmpty;
      
      // 发送连接成功事件
      _messageController.add({
        'type': 'peer_connected',
        'peerId': peerId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      debugPrint('成功连接到节点: $peerId');
      return true;
    } catch (e) {
      debugPrint('连接节点失败: $e');
      return false;
    }
  }

  // 断开节点连接
  Future<void> disconnectFromPeer(String peerId) async {
    if (_connectedPeers.contains(peerId)) {
      _connectedPeers.remove(peerId);
      _isConnected = _connectedPeers.isNotEmpty;
      
      _messageController.add({
        'type': 'peer_disconnected',
        'peerId': peerId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      debugPrint('断开节点连接: $peerId');
    }
  }

  // 发送消息到所有节点
  Future<bool> broadcastMessage(Map<String, dynamic> message) async {
    if (!_isConnected) {
      debugPrint('没有连接的节点，无法广播消息');
      return false;
    }

    try {
      debugPrint('广播消息到 ${_connectedPeers.length} 个节点');
      
      // 模拟消息发送
      await Future.delayed(Duration(milliseconds: 100));
      
      // 模拟收到回复
      _simulateMessageResponse(message);
      
      return true;
    } catch (e) {
      debugPrint('广播消息失败: $e');
      return false;
    }
  }

  // 发送消息到特定节点
  Future<bool> sendMessageToPeer(String peerId, Map<String, dynamic> message) async {
    if (!_connectedPeers.contains(peerId)) {
      debugPrint('未连接到节点: $peerId');
      return false;
    }

    try {
      debugPrint('发送消息到节点: $peerId');
      
      // 模拟消息发送
      await Future.delayed(Duration(milliseconds: 50));
      
      return true;
    } catch (e) {
      debugPrint('发送消息失败: $e');
      return false;
    }
  }

  // 模拟消息响应
  void _simulateMessageResponse(Map<String, dynamic> originalMessage) {
    final random = Random();
    
    // 随机延迟后收到响应
    Timer(Duration(milliseconds: 200 + random.nextInt(300)), () {
      final response = {
        'type': 'message_response',
        'originalMessage': originalMessage,
        'fromPeer': _connectedPeers[random.nextInt(_connectedPeers.length)],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': '模拟响应数据'
      };
      
      _messageController.add(response);
    });
  }

  // 获取网络统计信息
  Map<String, dynamic> getNetworkStats() {
    return {
      'isInitialized': _isInitialized,
      'isConnected': _isConnected,
      'connectedPeers': _connectedPeers.length,
      'peerList': _connectedPeers,
      'networkType': 'simulated_p2p',
    };
  }

  // 搜索附近的节点
  Future<List<String>> discoverPeers() async {
    debugPrint('搜索附近的节点...');
    
    // 模拟节点发现
    await Future.delayed(Duration(milliseconds: 1000));
    
    final discoveredPeers = [
      'peer_${Random().nextInt(1000)}',
      'peer_${Random().nextInt(1000)}',
      'peer_${Random().nextInt(1000)}',
    ];
    
    debugPrint('发现 ${discoveredPeers.length} 个节点');
    return discoveredPeers;
  }

  // 清理资源
  void dispose() {
    _connectedPeers.clear();
    _isConnected = false;
    _isInitialized = false;
    _messageController.close();
    debugPrint('P2P网络服务已清理');
  }
}