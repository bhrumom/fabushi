import 'dart:async';

import 'package:uuid/uuid.dart';

import 'mahayana_sdk.dart';

/// Online presence backed exclusively by the embedded Mahayana Rust runtime.
///
/// Flutter owns only timers and presentation state. Network requests, account
/// context and response redaction stay inside Rust. The old direct WebSocket
/// client was removed because it bypassed the host runtime boundary.
class OnlineCounterService {
  static const Duration heartbeatInterval = Duration(seconds: 30);

  final _uuid = const Uuid();
  final _onlineCountController = StreamController<int>.broadcast();

  String? _sessionId;
  String? _currentActivity;
  String? _pollingActivity;
  Timer? _heartbeatTimer;
  Timer? _countPollingTimer;
  bool _isCountFetchInFlight = false;
  int _currentCount = 0;

  Stream<int> get onlineCountStream => _onlineCountController.stream;
  int get currentCount => _currentCount;

  Future<bool> joinActivity(String activityType) async {
    if (_currentActivity == activityType && _sessionId != null) return true;
    if (_currentActivity != null) await leaveActivity();

    _sessionId = _uuid.v4();
    _currentActivity = activityType;
    final Map<String, dynamic> response;
    try {
      response = await _request(
        method: 'POST',
        path: '/api/online/join',
        body: {'activityType': activityType, 'sessionId': _sessionId},
      );
    } catch (_) {
      _sessionId = null;
      _currentActivity = null;
      return false;
    }
    if (_statusCode(response) != 200) {
      _sessionId = null;
      _currentActivity = null;
      return false;
    }
    _updateFromResponse(response);
    _startHeartbeat();
    return true;
  }

  Future<void> leaveActivity() async {
    final activity = _currentActivity;
    final session = _sessionId;
    _stopHeartbeat();
    if (activity != null && session != null) {
      try {
        await _request(
          method: 'POST',
          path: '/api/online/leave',
          body: {'activityType': activity, 'sessionId': session},
        );
      } catch (_) {
        // Presence expires server-side; local teardown must still complete.
      }
    }
    _sessionId = null;
    _currentActivity = null;
    _updateCount(0);
  }

  Future<void> fetchCountForActivity(String activityType) async {
    if (_isCountFetchInFlight) return;
    _isCountFetchInFlight = true;
    try {
      final response = await _request(
        method: 'GET',
        path: '/api/online/count',
        query: {'activityType': activityType},
      );
      if (_statusCode(response) == 200) _updateFromResponse(response);
    } catch (_) {
      // Polling is best effort; the next tick retries through Rust.
    } finally {
      _isCountFetchInFlight = false;
    }
  }

  void startCountPolling(
    String activityType, {
    Duration interval = const Duration(seconds: 5),
  }) {
    _pollingActivity = activityType;
    _countPollingTimer?.cancel();
    unawaited(fetchCountForActivity(activityType));
    _countPollingTimer = Timer.periodic(interval, (_) {
      final activity = _pollingActivity;
      if (activity != null) unawaited(fetchCountForActivity(activity));
    });
  }

  void stopCountPolling() {
    _countPollingTimer?.cancel();
    _countPollingTimer = null;
    _pollingActivity = null;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => unawaited(_sendHeartbeat()),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    final activity = _currentActivity;
    final session = _sessionId;
    if (activity == null || session == null) return;
    final Map<String, dynamic> response;
    try {
      response = await _request(
        method: 'POST',
        path: '/api/online/heartbeat',
        body: {'activityType': activity, 'sessionId': session},
      );
    } catch (_) {
      return;
    }
    if (_statusCode(response) == 404 &&
        _data(response)['shouldRejoin'] == true) {
      _sessionId = null;
      _currentActivity = null;
      await joinActivity(activity);
      return;
    }
    if (_statusCode(response) == 200) _updateFromResponse(response);
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) {
    return MahayanaSdk.instance.platformRequest(
      method: method,
      path: path,
      query: query,
      body: body,
      authenticated: false,
    );
  }

  int _statusCode(Map<String, dynamic> response) =>
      (response['statusCode'] as num?)?.toInt() ?? 0;

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  void _updateFromResponse(Map<String, dynamic> response) {
    _updateCount((_data(response)['count'] as num?)?.toInt() ?? _currentCount);
  }

  void _updateCount(int count) {
    if (_currentCount == count) return;
    _currentCount = count;
    if (!_onlineCountController.isClosed) _onlineCountController.add(count);
  }

  void dispose() {
    stopCountPolling();
    _stopHeartbeat();
    _onlineCountController.close();
  }
}
