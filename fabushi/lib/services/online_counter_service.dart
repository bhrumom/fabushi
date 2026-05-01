import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 在线人数服务 - WebSocket 版本
/// 管理用户在线状态并提供实时人数统计
class OnlineCounterService {
  static const String baseUrl = 'https://flutter.ombhrum.com';
  static const String wsUrl = 'wss://flutter.ombhrum.com';
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 5);

  final _uuid = const Uuid();
  String? _sessionId;
  String? _currentActivity;
  Timer? _heartbeatTimer;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _shouldReconnect = false;

  // 在线人数流控制器
  final _onlineCountController = StreamController<int>.broadcast();
  Stream<int> get onlineCountStream => _onlineCountController.stream;

  int _currentCount = 0;
  int get currentCount => _currentCount;

  /// 加入活动
  Future<bool> joinActivity(String activityType) async {
    if (_currentActivity == activityType &&
        _sessionId != null &&
        _isConnected) {
      return true;
    }

    if (_currentActivity != null) {
      await leaveActivity();
    }

    _sessionId = _uuid.v4();
    _currentActivity = activityType;
    _shouldReconnect = true;

    // 尝试 WebSocket 连接
    final wsSuccess = await _connectWebSocket(activityType);

    if (wsSuccess) {
      return true;
    } else {
      print('📡 WebSocket 不可用，使用 HTTP 轮询');
      return await _joinViaHttp(activityType);
    }
  }

  /// 建立 WebSocket 连接
  Future<bool> _connectWebSocket(String activityType) async {
    try {
      // 直接使用字符串拼接构建 URI，避免 Uri.replace() 导致端口变成 0 的问题
      final uri = Uri.parse(
        '$wsUrl/api/online/ws?activityType=${Uri.encodeComponent(activityType)}',
      );

      print('🔌 准备连接 WebSocket: $uri');

      try {
        _channel = WebSocketChannel.connect(uri);
        print('🔌 WebSocketChannel.connect 调用完成');
      } catch (e) {
        print('❌ WebSocketChannel.connect 异常: $e');
        return false;
      }

      // 监听消息
      _channel!.stream.listen(
        (message) {
          if (!_isConnected) {
            _isConnected = true;
            print('✅ WebSocket 已收到首条消息，连接确认成功');
          }
          print('📩 收到 WebSocket 消息: $message');
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket stream 错误: $error');
          _handleWebSocketError();
        },
        onDone: () {
          print('🔌 WebSocket stream 关闭');
          _handleWebSocketClose();
        },
        cancelOnError: false,
      );

      // 等待连接建立
      print('⏳ 等待连接建立...');
      await Future.delayed(const Duration(milliseconds: 500));

      // 发送 join
      print('mb 发送 join 消息...');
      _sendWebSocketMessage({
        'action': 'join',
        'sessionId': _sessionId,
        'activityType': activityType,
      });

      // 等待响应
      print('⏳ 等待服务器响应...');
      int retryCount = 0;
      while (!_isConnected && retryCount < 6) {
        await Future.delayed(const Duration(milliseconds: 500));
        retryCount++;
        if (_isConnected) break;
        print('⏳ 等待响应... ${retryCount}/6');
      }

      if (_isConnected) {
        print('✅ WebSocket 连接流程完成');
        _startHeartbeat();
        return true;
      }

      print('📡 WebSocket 连接超时或失败，降级到 HTTP');
      return false;
    } catch (e) {
      print('❌ WebSocket 建立连接过程异常: $e');
      return false;
    }
  }

  /// 处理 WebSocket 消息
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'count_update':
          _updateCount(data['count'] ?? 0);
          break;
        case 'error':
          print('服务器错误: ${data['message']}');
          if (data['shouldRejoin'] == true) {
            _reconnect();
          }
          break;
      }
    } catch (e) {
      print('处理 WebSocket 消息错误: $e');
    }
  }

  /// 处理 WebSocket 错误
  void _handleWebSocketError() {
    _isConnected = false;
    if (_shouldReconnect && _currentActivity != null) {
      _reconnect();
    }
  }

  /// 处理 WebSocket 关闭
  void _handleWebSocketClose() {
    _isConnected = false;
    if (_shouldReconnect && _currentActivity != null) {
      _reconnect();
    }
  }

  /// 重新连接
  Future<void> _reconnect() async {
    if (!_shouldReconnect || _currentActivity == null) {
      return;
    }

    print('尝试重新连接...');
    await Future.delayed(reconnectDelay);

    if (_shouldReconnect && _currentActivity != null) {
      final success = await _connectWebSocket(_currentActivity!);
      if (!success) {
        // 重连失败，降级到 HTTP
        await _joinViaHttp(_currentActivity!);
      }
    }
  }

  /// 发送 WebSocket 消息
  void _sendWebSocketMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        print('发送 WebSocket 消息失败: $e');
      }
    }
  }

  /// 离开活动
  Future<void> leaveActivity() async {
    if (_sessionId == null || _currentActivity == null) {
      return;
    }

    _shouldReconnect = false;
    _stopHeartbeat();

    if (_isConnected && _channel != null) {
      try {
        // 通过 WebSocket 离开
        _sendWebSocketMessage({
          'action': 'leave',
          'sessionId': _sessionId,
          'activityType': _currentActivity,
        });

        await Future.delayed(const Duration(milliseconds: 100));
        await _channel!.sink.close();
      } catch (e) {
        print('关闭 WebSocket 时出错: $e');
      } finally {
        _channel = null;
        _isConnected = false;
      }
    } else {
      // 通过 HTTP 离开
      await _leaveViaHttp();
    }

    _sessionId = null;
    _currentActivity = null;
    _updateCount(0);
  }

  /// 发送心跳
  Future<void> _sendHeartbeat() async {
    if (_sessionId == null || _currentActivity == null) {
      return;
    }

    if (_isConnected && _channel != null) {
      // WebSocket 心跳
      _sendWebSocketMessage({
        'action': 'heartbeat',
        'sessionId': _sessionId,
        'activityType': _currentActivity,
      });
    } else {
      // HTTP 心跳（降级方案）
      await _heartbeatViaHttp();
    }
  }

  /// 获取指定活动类型的在线人数（不加入活动）
  Future<void> fetchCountForActivity(String activityType) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/online/count?activityType=$activityType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateCount(data['count'] ?? 0);
      }
    } catch (e) {
      print('获取在线人数错误: $e');
    }
  }

  /// 启动心跳定时器
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      _sendHeartbeat();
    });
  }

  /// 停止心跳定时器
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 更新在线人数并通知监听者
  void _updateCount(int count) {
    if (_currentCount != count) {
      _currentCount = count;
      if (!_onlineCountController.isClosed) {
        _onlineCountController.add(count);
      }
    }
  }

  // ==================== HTTP 降级方案 ====================

  /// HTTP 降级：加入活动
  Future<bool> _joinViaHttp(String activityType) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/online/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'activityType': activityType,
          'sessionId': _sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateCount(data['count'] ?? 0);
        _startHeartbeat();
        return true;
      } else {
        print('HTTP 加入失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('HTTP 加入错误: $e');
      return false;
    }
  }

  /// HTTP 降级：心跳
  Future<void> _heartbeatViaHttp() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/online/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'activityType': _currentActivity,
          'sessionId': _sessionId,
        }),
      );

      if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        if (data['shouldRejoin'] == true && _currentActivity != null) {
          print('会话超时，重新加入');
          final activityType = _currentActivity!;
          _sessionId = _uuid.v4();
          await _joinViaHttp(activityType);
        }
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateCount(data['count'] ?? _currentCount);
      }
    } catch (e) {
      print('HTTP 心跳错误: $e');
    }
  }

  /// HTTP 降级：离开活动
  Future<void> _leaveViaHttp() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/online/leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'activityType': _currentActivity,
          'sessionId': _sessionId,
        }),
      );
    } catch (e) {
      print('HTTP 离开错误: $e');
    }
  }

  /// 清理资源
  void dispose() {
    _shouldReconnect = false;
    _stopHeartbeat();
    _channel?.sink.close();
    _channel = null;
    _onlineCountController.close();
  }
}
