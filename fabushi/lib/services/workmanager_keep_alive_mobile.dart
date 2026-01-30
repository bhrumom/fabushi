import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'workmanager_keep_alive.dart';

/// 初始化 WorkManager（Android/iOS）
Future<void> initializeWorkManager() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );
}

/// 注册周期性任务
Future<void> registerPeriodicTask() async {
  await Workmanager().registerPeriodicTask(
    WorkManagerKeepAlive.taskKey,
    WorkManagerKeepAlive.taskName,
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
}

/// 取消任务
Future<void> cancelTask() async {
  await Workmanager().cancelByUniqueName(WorkManagerKeepAlive.taskKey);
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
