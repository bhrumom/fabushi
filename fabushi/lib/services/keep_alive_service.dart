import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 后台保活服务
/// 
/// 在移动端使用音频服务保持应用活跃，
/// 在桌面端仅使用本地通知作为备用方案。
class KeepAliveService {
  static KeepAliveService? _instance;
  static KeepAliveService get instance => _instance ??= KeepAliveService._();
  
  KeepAliveService._();
  
  // 状态
  bool _isActive = false;
  bool _isMuted = false;
  Timer? _heartbeatTimer;
  
  // 本地通知
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  
  // 回调
  VoidCallback? onKeepAliveStart;
  VoidCallback? onKeepAliveStop;
  
  /// 是否支持后台保活（仅 Android/iOS）
  bool get _supportsKeepAlive => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  /// 是否激活
  bool get isActive => _isActive;
  
  /// 是否静音
  bool get isMuted => _isMuted;
  
  /// 初始化
  Future<void> initialize() async {
    // 初始化本地通知
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    await _notificationsPlugin!.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      ),
    );
    
    debugPrint('✅ KeepAliveService 初始化完成');
  }
  
  /// 启动后台保活服务
  /// 
  /// [audioName] 当前处理的音频名称
  /// [totalCountries] 总国家数量
  Future<void> start({
    String? audioName,
    int? totalCountries,
  }) async {
    if (_isActive) return;
    
    _isActive = true;
    onKeepAliveStart?.call();
    
    // 启动心跳
    _startHeartbeat();
    
    // 显示通知
    await _showNotification(
      title: '全球法布施',
      body: audioName != null ? '正在发送: $audioName' : '正在发送中...',
    );
    
    debugPrint('🟢 KeepAliveService 已启动 (audioName: $audioName, totalCountries: $totalCountries)');
  }
  
  /// 停止后台保活服务
  Future<void> stop() async {
    if (!_isActive) return;
    
    _isActive = false;
    
    // 停止心跳
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    // 取消通知
    await _notificationsPlugin?.cancel(0);
    
    onKeepAliveStop?.call();
    
    debugPrint('🔴 KeepAliveService 已停止');
  }
  
  /// 更新进度
  /// 
  /// [sentCount] 已发送国家数量
  /// [totalCount] 总国家数量
  /// [currentCountry] 当前发送的国家名称
  /// [loopCount] 循环次数
  /// [isLoopbackActive] 是否启用回环
  /// [loopbackCount] 回环计数
  void updateProgress({
    int? sentCount,
    int? totalCount,
    String? currentCountry,
    int? loopCount,
    bool? isLoopbackActive,
    int? loopbackCount,
  }) {
    if (!_isActive) return;
    
    // 构建进度消息
    String message = '';
    
    if (currentCountry != null) {
      message = '正在发送到 $currentCountry';
    }
    
    if (sentCount != null && totalCount != null) {
      message += ' ($sentCount/$totalCount)';
    }
    
    if (loopCount != null && loopCount > 1) {
      message += ' - 第$loopCount轮';
    }
    
    if (isLoopbackActive == true && loopbackCount != null) {
      message += ' 📡$loopbackCount';
    }
    
    // 更新通知
    _showNotification(
      title: '全球法布施',
      body: message.isNotEmpty ? message : '正在发送中...',
    );
    
    debugPrint('📊 进度更新: $message');
  }
  
  /// 切换静音状态
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    debugPrint('🔇 静音状态: $_isMuted');
  }
  
  /// 开始保活（兼容旧接口）
  Future<void> startKeepAlive({String? title, String? content}) async {
    await start(audioName: content);
    if (title != null) {
      await _showNotification(title: title, body: content ?? '正在发送中...');
    }
  }
  
  /// 停止保活（兼容旧接口）
  Future<void> stopKeepAlive() async {
    await stop();
  }
  
  /// 更新通知内容
  Future<void> updateNotification({String? title, String? content}) async {
    if (!_isActive) return;
    
    await _showNotification(
      title: title ?? '全球法布施',
      body: content ?? '正在发送中...',
    );
  }
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isActive) {
        debugPrint('💓 KeepAlive heartbeat');
      }
    });
  }
  
  Future<void> _showNotification({required String title, required String body}) async {
    if (_notificationsPlugin == null) return;
    
    const androidDetails = AndroidNotificationDetails(
      'keep_alive_channel',
      '后台保活',
      channelDescription: '保持应用在后台运行',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );
    
    await _notificationsPlugin!.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
    );
  }
  
  /// 释放资源
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _notificationsPlugin?.cancel(0);
  }
}

/// 简化后的音频处理器（仅用于类型兼容）
class KeepAliveAudioHandler {
  // 空实现，仅用于类型兼容
}
