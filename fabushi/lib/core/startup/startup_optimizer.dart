import 'dart:async';
import 'package:flutter/foundation.dart';

/// 启动优化器 - 避免进程发送冲突造成堵塞
class StartupOptimizer {
  static final StartupOptimizer _instance = StartupOptimizer._internal();
  factory StartupOptimizer() => _instance;
  StartupOptimizer._internal();

  final List<Future<void> Function()> _initQueue = [];
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// 添加初始化任务到队列
  void addInitTask(Future<void> Function() task) {
    _initQueue.add(task);
  }

  /// 开始分批初始化，避免阻塞
  Future<void> startInitialization() async {
    if (_isInitializing) return _initCompleter.future;

    _isInitializing = true;
    debugPrint('🚀 启动优化器开始分批初始化');

    try {
      // 分批处理，每批最多3个任务
      const batchSize = 3;
      for (int i = 0; i < _initQueue.length; i += batchSize) {
        final batch = _initQueue.skip(i).take(batchSize).toList();

        // 并发执行当前批次
        await Future.wait(batch.map((task) => task()));

        // 每批之间让出主线程控制权
        await Future.delayed(const Duration(milliseconds: 16));

        debugPrint('✅ 完成第${(i ~/ batchSize) + 1}批初始化');
      }

      debugPrint('🎉 所有初始化任务完成');
      _initCompleter.complete();
    } catch (e) {
      debugPrint('❌ 初始化失败: $e');
      _initCompleter.completeError(e);
    }
  }

  /// 等待初始化完成
  Future<void> waitForInitialization() => _initCompleter.future;
}
