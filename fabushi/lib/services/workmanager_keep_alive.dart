import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 条件导入：仅在 Android/iOS 使用 workmanager
import 'workmanager_keep_alive_mobile.dart'
    if (dart.library.html) 'workmanager_keep_alive_stub.dart'
    as platform;

/// WorkManager 保活服务
/// 
/// 使用 Android WorkManager 实现应用被杀后的自动恢复。
/// 当应用在后台被系统杀死时，WorkManager 会定期检查并尝试恢复发送任务。
/// 
/// 核心原理：
/// - WorkManager 任务由系统调度，独立于应用进程
/// - 即使应用被杀，WorkManager 任务仍会执行
/// - 在任务中检查是否有未完成的发送任务，如有则重新启动应用
class WorkManagerKeepAlive {
  static const String taskName = 'com.ombhrum.fabushi.keepalive';
  static const String taskKey = 'keepalive_check';
  
  // SharedPreferences 键名
  static const String keyIsSendingActive = 'sending_is_active';
  static const String keyLastActiveTime = 'sending_last_active_time';
  static const String keyLoopCount = 'sending_loop_count';
  static const String keySelectedFilePaths = 'sending_file_paths';
  static const String keyIsLooping = 'sending_is_looping';
  
  static bool _isInitialized = false;
  
  /// 是否支持 WorkManager（仅 Android/iOS）
  static bool get _isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  /// 初始化 WorkManager
  static Future<void> initialize() async {
    if (!_isSupported) return;
    if (_isInitialized) return;
    
    try {
      await platform.initializeWorkManager();
      _isInitialized = true;
      debugPrint('✅ WorkManager 已初始化');
    } catch (e) {
      debugPrint('❌ WorkManager 初始化失败: $e');
    }
  }
  
  /// 注册周期性保活任务
  /// 
  /// 每 15 分钟检查一次（WorkManager 最小间隔）
  static Future<void> registerKeepAliveTask() async {
    if (!_isSupported) return;
    
    try {
      await platform.registerPeriodicTask();
      debugPrint('✅ 保活周期任务已注册');
    } catch (e) {
      debugPrint('❌ 注册保活任务失败: $e');
    }
  }
  
  /// 取消保活任务
  static Future<void> cancelKeepAliveTask() async {
    if (!_isSupported) return;
    
    try {
      await platform.cancelTask();
      debugPrint('✅ 保活任务已取消');
    } catch (e) {
      debugPrint('❌ 取消保活任务失败: $e');
    }
  }
  
  /// 保存发送状态（在发送开始时调用）
  static Future<void> saveSendingState({
    required bool isActive,
    required int loopCount,
    required bool isLooping,
    required List<String> filePaths,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyIsSendingActive, isActive);
      await prefs.setInt(keyLastActiveTime, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(keyLoopCount, loopCount);
      await prefs.setBool(keyIsLooping, isLooping);
      await prefs.setStringList(keySelectedFilePaths, filePaths);
      
      debugPrint('💾 发送状态已保存: active=$isActive, loop=$loopCount');
    } catch (e) {
      debugPrint('❌ 保存发送状态失败: $e');
    }
  }
  
  /// 清除发送状态（在发送停止时调用）
  static Future<void> clearSendingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyIsSendingActive, false);
      debugPrint('🗑️ 发送状态已清除');
    } catch (e) {
      debugPrint('❌ 清除发送状态失败: $e');
    }
  }
  
  /// 更新最后活跃时间（心跳）
  static Future<void> updateLastActiveTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(keyIsSendingActive) ?? false;
      if (isActive) {
        await prefs.setInt(keyLastActiveTime, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      // 静默失败
    }
  }
  
  /// 检查是否需要恢复发送
  /// 
  /// 返回需要恢复的状态，如果不需要恢复则返回 null
  static Future<SendingStateSnapshot?> checkNeedsRecovery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final isActive = prefs.getBool(keyIsSendingActive) ?? false;
      if (!isActive) return null;
      
      final lastActiveTime = prefs.getInt(keyLastActiveTime) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 如果上次活跃时间在 60 分钟内，认为需要恢复
      final inactiveMinutes = (now - lastActiveTime) / (1000 * 60);
      if (inactiveMinutes > 60) {
        debugPrint('⏰ 发送任务超时 (${inactiveMinutes.toStringAsFixed(0)} 分钟)，不再恢复');
        await clearSendingState();
        return null;
      }
      
      final loopCount = prefs.getInt(keyLoopCount) ?? 0;
      final isLooping = prefs.getBool(keyIsLooping) ?? false;
      final filePaths = prefs.getStringList(keySelectedFilePaths) ?? [];
      
      if (filePaths.isEmpty) {
        await clearSendingState();
        return null;
      }
      
      debugPrint('🔄 检测到需要恢复的发送任务: loopCount=$loopCount, files=${filePaths.length}');
      
      return SendingStateSnapshot(
        loopCount: loopCount,
        isLooping: isLooping,
        filePaths: filePaths,
        lastActiveTime: DateTime.fromMillisecondsSinceEpoch(lastActiveTime),
      );
    } catch (e) {
      debugPrint('❌ 检查恢复状态失败: $e');
      return null;
    }
  }
}

/// 发送状态快照
class SendingStateSnapshot {
  final int loopCount;
  final bool isLooping;
  final List<String> filePaths;
  final DateTime lastActiveTime;
  
  SendingStateSnapshot({
    required this.loopCount,
    required this.isLooping,
    required this.filePaths,
    required this.lastActiveTime,
  });
}
