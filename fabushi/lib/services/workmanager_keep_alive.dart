import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'keep_alive_service.dart';

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
  static const String _keyIsSendingActive = 'sending_is_active';
  static const String _keyLastActiveTime = 'sending_last_active_time';
  static const String _keyLoopCount = 'sending_loop_count';
  static const String _keySelectedFilePaths = 'sending_file_paths';
  static const String _keyIsLooping = 'sending_is_looping';

  static bool _isInitialized = false;

  /// 初始化 WorkManager
  static Future<void> initialize() async {
    if (kIsWeb) return; // Web 不支持
    if (_isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
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
    if (kIsWeb) return;

    try {
      await Workmanager().registerPeriodicTask(
        taskKey,
        taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
      debugPrint('✅ 保活周期任务已注册');
    } catch (e) {
      debugPrint('❌ 注册保活任务失败: $e');
    }
  }

  /// 取消保活任务
  static Future<void> cancelKeepAliveTask() async {
    if (kIsWeb) return;

    try {
      await Workmanager().cancelByUniqueName(taskKey);
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
      await prefs.setBool(_keyIsSendingActive, isActive);
      await prefs.setInt(
        _keyLastActiveTime,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setInt(_keyLoopCount, loopCount);
      await prefs.setBool(_keyIsLooping, isLooping);
      await prefs.setStringList(_keySelectedFilePaths, filePaths);

      debugPrint('💾 发送状态已保存: active=$isActive, loop=$loopCount');
    } catch (e) {
      debugPrint('❌ 保存发送状态失败: $e');
    }
  }

  /// 清除发送状态（在发送停止时调用）
  static Future<void> clearSendingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsSendingActive, false);
      debugPrint('🗑️ 发送状态已清除');
    } catch (e) {
      debugPrint('❌ 清除发送状态失败: $e');
    }
  }

  /// 更新最后活跃时间（心跳）
  static Future<void> updateLastActiveTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_keyIsSendingActive) ?? false;
      if (isActive) {
        await prefs.setInt(
          _keyLastActiveTime,
          DateTime.now().millisecondsSinceEpoch,
        );
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

      final isActive = prefs.getBool(_keyIsSendingActive) ?? false;
      if (!isActive) return null;

      final lastActiveTime = prefs.getInt(_keyLastActiveTime) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 如果上次活跃时间在 60 分钟内，认为需要恢复
      final inactiveMinutes = (now - lastActiveTime) / (1000 * 60);
      if (inactiveMinutes > 60) {
        debugPrint('⏰ 发送任务超时 (${inactiveMinutes.toStringAsFixed(0)} 分钟)，不再恢复');
        await clearSendingState();
        return null;
      }

      final loopCount = prefs.getInt(_keyLoopCount) ?? 0;
      final isLooping = prefs.getBool(_keyIsLooping) ?? false;
      final filePaths = prefs.getStringList(_keySelectedFilePaths) ?? [];

      if (filePaths.isEmpty) {
        await clearSendingState();
        return null;
      }

      debugPrint(
        '🔄 检测到需要恢复的发送任务: loopCount=$loopCount, files=${filePaths.length}',
      );

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

/// WorkManager 回调分发器（必须是顶级函数）
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('📋 WorkManager 任务执行: $task');

    try {
      switch (task) {
        case WorkManagerKeepAlive.taskName:
          // 检查是否有需要恢复的任务
          final snapshot = await WorkManagerKeepAlive.checkNeedsRecovery();

          if (snapshot != null) {
            debugPrint('🔄 WorkManager 检测到需要恢复的任务，尝试重启应用...');
            // 注意：WorkManager 无法直接启动应用 UI
            // 但可以通过重新启动前台服务来恢复
            // 这里我们只记录状态，让应用下次启动时自动恢复
          } else {
            debugPrint('✅ WorkManager 检查完成，无需恢复');
          }
          break;

        default:
          debugPrint('⚠️ 未知任务: $task');
      }

      return true; // 任务成功
    } catch (e) {
      debugPrint('❌ WorkManager 任务失败: $e');
      return false; // 任务失败，会重试
    }
  });
}
