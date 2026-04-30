import 'dart:async';

import 'package:flutter/foundation.dart';

/// 启动优化器 - 首帧后分批、隔离地执行非关键初始化。
class StartupOptimizer {
  static final StartupOptimizer _instance = StartupOptimizer._internal();
  factory StartupOptimizer() => _instance;
  StartupOptimizer._internal();

  final List<Future<void> Function()> _initQueue = [];
  bool _isInitializing = false;
  Completer<void>? _initCompleter;

  /// 添加初始化任务到队列。
  void addInitTask(Future<void> Function() task) {
    _initQueue.add(task);
  }

  /// 开始分批初始化，避免任何单个任务拖慢后续任务或首屏交互。
  Future<void> startInitialization() async {
    if (_isInitializing) return _initCompleter?.future ?? Future.value();

    _isInitializing = true;
    _initCompleter = Completer<void>();
    debugPrint('🚀 启动优化器开始分批初始化');

    final tasks = List<Future<void> Function()>.from(_initQueue);
    _initQueue.clear();

    try {
      const batchSize = 2;
      for (int i = 0; i < tasks.length; i += batchSize) {
        final batch = tasks.skip(i).take(batchSize).toList();

        await Future.wait(
          batch.map(
            (task) async {
              try {
                await task().timeout(const Duration(seconds: 6));
              } on TimeoutException {
                debugPrint('⚠️ 初始化任务超时，已跳过');
              } catch (e) {
                debugPrint('⚠️ 初始化任务失败，继续执行后续任务: $e');
              }
            },
          ),
          eagerError: false,
        );

        // 让出至少一帧，保证启动后的滑动/点击不会被连续初始化任务抢占。
        await Future<void>.delayed(const Duration(milliseconds: 32));
        debugPrint('✅ 完成第${(i ~/ batchSize) + 1}批初始化');
      }

      debugPrint('🎉 所有初始化任务完成');
      _initCompleter?.complete();
    } catch (e) {
      debugPrint('❌ 初始化调度失败: $e');
      _initCompleter?.completeError(e);
    } finally {
      _isInitializing = false;
    }
  }

  /// 等待初始化完成。
  Future<void> waitForInitialization() => _initCompleter?.future ?? Future.value();
}
