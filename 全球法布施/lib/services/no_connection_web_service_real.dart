import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

// 简化的无连接Web服务，兼容所有平台
class NoConnectionWebServiceReal {
  static NoConnectionWebServiceReal? _instance;
  
  NoConnectionWebServiceReal._();
  
  static NoConnectionWebServiceReal get instance {
    _instance ??= NoConnectionWebServiceReal._();
    return _instance!;
  }

  // 模拟WebSocket连接状态
  bool _isConnected = false;
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  Timer? _heartbeatTimer;

  Stream<String> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  // 初始化连接
  Future<bool> initialize() async {
    try {
      debugPrint('初始化无连接Web服务...');
      
      // 模拟连接过程
      await Future.delayed(Duration(milliseconds: 500));
      
      _isConnected = true;
      _startHeartbeat();
      
      debugPrint('无连接Web服务初始化成功');
      return true;
    } catch (e) {
      debugPrint('无连接Web服务初始化失败: $e');
      return false;
    }
  }

  // 发送消息
  Future<bool> sendMessage(String message) async {
    if (!_isConnected) {
      debugPrint('连接未建立，无法发送消息');
      return false;
    }

    try {
      debugPrint('发送消息: $message');
      
      // 模拟消息发送
      await Future.delayed(Duration(milliseconds: 100));
      
      // 模拟回复
      _simulateResponse(message);
      
      return true;
    } catch (e) {
      debugPrint('发送消息失败: $e');
      return false;
    }
  }

  // 模拟响应
  void _simulateResponse(String originalMessage) {
    Timer(Duration(milliseconds: 200), () {
      final response = {
        'type': 'response',
        'originalMessage': originalMessage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': '模拟响应数据'
      };
      
      _messageController.add(jsonEncode(response));
    });
  }

  // 开始心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected) {
        final heartbeat = {
          'type': 'heartbeat',
          'timestamp': DateTime.now().millisecondsSinceEpoch
        };
        _messageController.add(jsonEncode(heartbeat));
      }
    });
  }

  // 断开连接
  void disconnect() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('无连接Web服务已断开');
  }

  // 测试网络连接
  Future<bool> testConnection() async {
    try {
      debugPrint('测试网络连接...');
      
      // 模拟网络测试
      await Future.delayed(Duration(milliseconds: 300));
      
      final random = Random();
      final success = random.nextBool(); // 随机成功/失败
      
      debugPrint('网络连接测试结果: ${success ? "成功" : "失败"}');
      return success;
    } catch (e) {
      debugPrint('网络连接测试异常: $e');
      return false;
    }
  }

  // 获取连接统计信息
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'connectionType': 'simulated',
      'uptime': _isConnected ? '模拟运行时间' : '未连接',
      'messagesSent': 0,
      'messagesReceived': 0,
    };
  }

  // 清理资源
  void dispose() {
    disconnect();
    _messageController.close();
  }
}