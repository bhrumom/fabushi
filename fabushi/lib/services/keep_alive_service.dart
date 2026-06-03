import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'memory_manager.dart';
import 'workmanager_keep_alive.dart';

/// 无音频后台辅助服务。
///
/// 只负责发送进度通知、周期性心跳和 WorkManager 活跃时间维护。
/// 不再注册系统媒体会话，也不再启动播放器来进行后台保活。
class KeepAliveService {
  static KeepAliveService? _instance;
  static const int _notificationId = 8888;
  static const String _channelId = 'com.ombhrum.fabushi.keep_alive';
  static const String _channelName = '大乘';
  static const String _channelDescription = '全球发送进度通知';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isInitializing = false;
  Completer<void>? _initCompleter;

  Timer? _heartbeatTimer;
  int _heartbeatCount = 0;
  int _sentCount = 0;
  int _totalCount = 0;
  String _currentCountry = '';
  String _currentTitle = '';
  int _loopCount = 0;
  bool _isLoopbackActive = false;
  int _loopbackCount = 0;

  KeepAliveService._();

  static KeepAliveService get instance {
    _instance ??= KeepAliveService._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;

  /// 兼容旧调用方命名：表示后台辅助服务是否处于发送期。
  bool get isPlaying => _isRunning;

  /// 已移除音频保活，因此永远没有保活音频在播放。
  bool get isActuallyPlaying => false;

  /// 已移除静音保活音频，保留 getter 避免调用方崩溃。
  bool get isMuted => true;

  String get statusInfo {
    if (!_isRunning) return '未运行';
    return _currentTitle.isEmpty ? '发送进度通知运行中' : '$_currentTitle 发送中';
  }

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      const androidSettings = AndroidInitializationSettings(
        'mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);

      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('✅ 无音频后台通知服务已初始化');
    } catch (e) {
      debugPrint('❌ 无音频后台通知服务初始化失败: $e');
    } finally {
      _isInitializing = false;
      _initCompleter?.complete();
    }
  }

  Future<void> start({
    String? audioUrl,
    String? audioName,
    int totalCountries = 0,
  }) async {
    if (kIsWeb) return;
    await initialize();

    _isRunning = true;
    _currentTitle = audioName ?? '';
    _totalCount = totalCountries;
    _sentCount = 0;
    _currentCountry = '';
    _loopCount = 0;
    _isLoopbackActive = false;
    _loopbackCount = 0;

    await WorkManagerKeepAlive.registerKeepAliveTask();
    await _showProgressNotification();
    _startHeartbeat();

    debugPrint('✅ 后台辅助服务已启动（无音频）');
  }

  Future<void> stop() async {
    if (!_isRunning && !_isInitialized) return;

    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await WorkManagerKeepAlive.cancelKeepAliveTask();
    await _cancelNotification();

    _sentCount = 0;
    _totalCount = 0;
    _currentCountry = '';
    _currentTitle = '';
    _loopCount = 0;
    _isLoopbackActive = false;
    _loopbackCount = 0;

    debugPrint('✅ 后台辅助服务已停止（无音频）');
  }

  void updateProgress({
    required int sentCount,
    required int totalCount,
    required String currentCountry,
    String? audioName,
    int? loopCount,
    bool isLoopbackActive = false,
    int loopbackCount = 0,
  }) {
    _sentCount = sentCount;
    _totalCount = totalCount;
    _currentCountry = currentCountry;
    if (audioName != null && audioName.isNotEmpty) {
      _currentTitle = audioName;
    }
    if (loopCount != null) {
      _loopCount = loopCount;
    }
    _isLoopbackActive = isLoopbackActive;
    _loopbackCount = loopbackCount;

    if (_isRunning) {
      _showProgressNotification();
    }
  }

  Future<void> setMuted(bool muted) async {
    debugPrint('ℹ️ 保活音频已移除，静音设置不再生效');
  }

  Future<void> toggleMute() async {
    debugPrint('ℹ️ 保活音频已移除，静音切换不再生效');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatCount = 0;

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isRunning) return;

      _heartbeatCount++;
      _showProgressNotification();

      if (_heartbeatCount % 12 == 0) {
        WorkManagerKeepAlive.updateLastActiveTime();
        MemoryManager.instance.trimCacheIfNeeded();
        debugPrint('💓 无音频后台心跳 #$_heartbeatCount');
      }
    });
  }

  Future<void> _showProgressNotification() async {
    if (!_isInitialized || kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        playSound: false,
        enableVibration: false,
        channelShowBadge: true,
        category: AndroidNotificationCategory.progress,
        onlyAlertOnce: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _notificationId,
        _notificationTitle(),
        _notificationBody(),
        details,
      );
    } catch (e) {
      debugPrint('⚠️ 更新后台进度通知失败: $e');
    }
  }

  Future<void> _cancelNotification() async {
    if (!_isInitialized || kIsWeb) return;

    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint('⚠️ 取消后台进度通知失败: $e');
    }
  }

  String _notificationTitle() {
    if (_currentTitle.isEmpty) return '大乘';
    return '正在发送《$_currentTitle》';
  }

  String _notificationBody() {
    String body;
    if (_currentCountry.isNotEmpty && _totalCount > 0) {
      body = '$_currentCountry ($_sentCount/$_totalCount)';
    } else if (_totalCount > 0) {
      body = '准备发送到 $_totalCount 个国家';
    } else {
      body = '发送进度通知运行中';
    }

    if (_loopCount > 0) {
      body = '第 $_loopCount 轮 · $body';
    }
    if (_isLoopbackActive) {
      body = '$body | 不可思议扬升能量场: $_loopbackCount 次';
    }
    return body;
  }
}
