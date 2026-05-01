import 'dart:async';
import 'package:flutter/foundation.dart';

/// 延迟加载器 - 避免启动时的资源竞争
class DeferredLoader {
  static final DeferredLoader _instance = DeferredLoader._internal();
  factory DeferredLoader() => _instance;
  DeferredLoader._internal();

  final Map<String, Timer> _timers = {};
  final Map<String, bool> _loadingStates = {};

  /// 延迟执行任务，避免启动时的资源竞争
  void scheduleTask(
    String taskId,
    Duration delay,
    Future<void> Function() task,
  ) {
    // 取消之前的任务
    _timers[taskId]?.cancel();

    _timers[taskId] = Timer(delay, () async {
      if (_loadingStates[taskId] == true) return; // 防止重复执行

      _loadingStates[taskId] = true;
      try {
        await task();
        debugPrint('✅ 延迟任务完成: $taskId');
      } catch (e) {
        debugPrint('❌ 延迟任务失败: $taskId - $e');
      } finally {
        _loadingStates[taskId] = false;
        _timers.remove(taskId);
      }
    });
  }

  /// 取消指定任务
  void cancelTask(String taskId) {
    _timers[taskId]?.cancel();
    _timers.remove(taskId);
    _loadingStates.remove(taskId);
  }

  /// 清理所有任务
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _loadingStates.clear();
  }
}
