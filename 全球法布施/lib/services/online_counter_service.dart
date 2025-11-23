import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// 在线人数服务
/// 管理用户在线状态并提供实时人数统计
class OnlineCounterService {
  static const String baseUrl = 'https://flutter.ombhrum.com';
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration countPollInterval = Duration(seconds: 10);

  final _uuid = const Uuid();
  String? _sessionId;
  String? _currentActivity;
  Timer? _heartbeatTimer;
  Timer? _countPollTimer;
  
  // 在线人数流控制器
  final _onlineCountController = StreamController<int>.broadcast();
  Stream<int> get onlineCountStream => _onlineCountController.stream;

  int _currentCount = 0;
  int get currentCount => _currentCount;

  /// 加入活动
  Future<bool> joinActivity(String activityType) async {
    if (_currentActivity == activityType && _sessionId != null) {
      // 已经加入该活动
      return true;
    }

    // 如果正在参与其他活动，先离开
    if (_currentActivity != null) {
      await leaveActivity();
    }

    _sessionId = _uuid.v4();
    _currentActivity = activityType;

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
        
        // 启动心跳定时器
        _startHeartbeat();
        
        // 启动计数轮询
        _startCountPolling();
        
        return true;
      } else {
        print('加入活动失败: ${response.statusCode}');
        _sessionId = null;
        _currentActivity = null;
        return false;
      }
    } catch (e) {
      print('加入活动错误: $e');
      _sessionId = null;
      _currentActivity = null;
      return false;
    }
  }

  /// 离开活动
  Future<void> leaveActivity() async {
    if (_sessionId == null || _currentActivity == null) {
      return;
    }

    // 停止定时器
    _stopHeartbeat();
    _stopCountPolling();

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
      print('离开活动错误: $e');
    } finally {
      _sessionId = null;
      _currentActivity = null;
      _updateCount(0);
    }
  }

  /// 发送心跳
  Future<void> _sendHeartbeat() async {
    if (_sessionId == null || _currentActivity == null) {
      return;
    }

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
        // 会话已超时，需要重新加入
        final data = jsonDecode(response.body);
        if (data['shouldRejoin'] == true && _currentActivity != null) {
          print('会话超时，重新加入活动');
          final activityType = _currentActivity!;
          _sessionId = null;
          _currentActivity = null;
          await joinActivity(activityType);
        }
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateCount(data['count'] ?? _currentCount);
      }
    } catch (e) {
      print('心跳发送错误: $e');
    }
  }

  /// 获取在线人数
  Future<void> fetchCount() async {
    if (_currentActivity == null) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/online/count?activityType=$_currentActivity'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateCount(data['count'] ?? 0);
      }
    } catch (e) {
      print('获取在线人数错误: $e');
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

  /// 启动计数轮询
  void _startCountPolling() {
    _stopCountPolling();
    _countPollTimer = Timer.periodic(countPollInterval, (timer) {
      fetchCount();
    });
  }

  /// 停止计数轮询
  void _stopCountPolling() {
    _countPollTimer?.cancel();
    _countPollTimer = null;
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

  /// 清理资源
  void dispose() {
    _stopHeartbeat();
    _stopCountPolling();
    _onlineCountController.close();
  }
}
