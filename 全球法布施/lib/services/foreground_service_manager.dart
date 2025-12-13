import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 前台服务管理器
/// 负责管理前台服务的启动、停止和通知更新
class ForegroundServiceManager {
  static final ForegroundServiceManager _instance = ForegroundServiceManager._internal();
  factory ForegroundServiceManager() => _instance;
  ForegroundServiceManager._internal();

  bool _isServiceRunning = false;
  bool _isInitialized = false;
  bool get isServiceRunning => _isServiceRunning;

  /// 请求通知权限 (Android 13+ 需要)
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // 检查当前权限状态
      final status = await Permission.notification.status;
      debugPrint('📬 当前通知权限状态: $status');
      
      if (status.isGranted) {
        debugPrint('✅ 通知权限已授予');
        return true;
      }
      
      if (status.isDenied) {
        // 请求权限
        debugPrint('📬 正在请求通知权限...');
        final result = await Permission.notification.request();
        debugPrint('📬 通知权限请求结果: $result');
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        debugPrint('⚠️ 通知权限被永久拒绝，请在设置中开启');
        // 可以引导用户去设置页面
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ 请求通知权限失败: $e');
      return false;
    }
  }

  /// 初始化前台服务
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    if (_isInitialized) return;

    // 首先请求通知权限
    final hasPermission = await requestNotificationPermission();
    if (!hasPermission) {
      debugPrint('⚠️ 通知权限未授予，前台服务可能无法正常显示通知');
    }

    // 请求忽略电池优化（可选，帮助后台运行）
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        debugPrint('📋 正在请求忽略电池优化...');
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint('⚠️ 请求忽略电池优化失败: $e');
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'global_dharma_sending',
        channelName: '全球法布施发送',
        channelDescription: '显示全球法布施发送进度',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000), // 缩短到1秒，提高活跃度
        autoRunOnBoot: true, // 开机后自动启动
        autoRunOnMyPackageReplaced: true, // 应用更新后自动启动
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
    debugPrint('✅ Android 前台服务已初始化');
  }


  /// 启动前台服务
  Future<bool> start({
    required String fileName,
    int totalCountries = 0,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('⚠️ 当前平台不支持 Android 前台服务');
      return false;
    }

    if (_isServiceRunning) {
      debugPrint('⚠️ 前台服务已在运行中');
      return true;
    }

    try {
      final ServiceRequestResult result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '正在发送经文',
        notificationText: '准备向全球发送: $fileName',
        notificationButtons: [
          const NotificationButton(
            id: 'stop_sending',
            text: '停止发送',
          ),
        ],
        callback: startCallback,
      );

      _isServiceRunning = true;
      debugPrint('✅ Android 前台服务已启动: $result');
      return true;
    } catch (e) {
      debugPrint('❌ 启动前台服务时发生错误: $e');
      return false;
    }
  }

  /// 更新通知进度
  Future<void> updateProgress({
    required int sentCount,
    required int totalCount,
    required String currentCountry,
    int? loopCount,
  }) async {
    if (!Platform.isAndroid || !_isServiceRunning) return;

    try {
      String title = '正在发送经文';
      if (loopCount != null && loopCount > 0) {
        title = '循环发送中 (第 $loopCount 轮)';
      }

      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: '发送到: $currentCountry ($sentCount/$totalCount)',
      );
    } catch (e) {
      debugPrint('❌ 更新通知进度失败: $e');
    }
  }

  /// 停止前台服务
  Future<bool> stop() async {
    if (!Platform.isAndroid) return false;

    if (!_isServiceRunning) {
      debugPrint('⚠️ 前台服务未在运行');
      return true;
    }

    try {
      final ServiceRequestResult result = await FlutterForegroundTask.stopService();
      _isServiceRunning = false;
      debugPrint('✅ Android 前台服务已停止: $result');
      return true;
    } catch (e) {
      debugPrint('❌ 停止前台服务时发生错误: $e');
      return false;
    }
  }

  /// 显示完成通知
  Future<void> showCompletionNotification({
    required int totalSent,
    required int loopCount,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      String message = loopCount > 1
          ? '已完成 $loopCount 轮循环发送，共发送到 $totalSent 个国家'
          : '已成功发送到全球 $totalSent 个国家';

      await FlutterForegroundTask.updateService(
        notificationTitle: '✨ 发送完成',
        notificationText: message,
      );

      // 2秒后自动停止服务
      await Future.delayed(const Duration(seconds: 2));
      await stop();
    } catch (e) {
      debugPrint('❌ 显示完成通知失败: $e');
    }
  }
}

/// 前台任务回调处理器
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

/// 前台任务处理器
class ForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🚀 前台任务已启动: $timestamp');
  }

  int _heartbeatCount = 0;
  DateTime? _lastHeartbeat;

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 心跳机制：保持服务活跃，防止被系统杀掉
    _heartbeatCount++;
    _lastHeartbeat = timestamp;
    
    // 每60秒输出一次心跳日志（避免日志过多）
    if (_heartbeatCount % 60 == 0) {
      debugPrint('💓 服务心跳 #$_heartbeatCount - ${timestamp.toIso8601String()}');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool sendData) async {
    debugPrint('🛑 前台任务已销毁: $timestamp');
  }

  void onButtonPressed(String id) {
    debugPrint('🔘 通知按钮被点击: $id');
    
    if (id == 'stop_sending') {
      // 用户点击了停止发送按钮
      // 这里可以通过事件总线或其他机制通知应用停止发送
      debugPrint('用户请求停止发送');
    }
  }

  @override
  void onNotificationPressed() {
    debugPrint('📱 通知被点击，返回应用');
    // 通知被点击时，应用会自动回到前台
    FlutterForegroundTask.launchApp('/');
  }
}
