import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// 性能监控工具
/// 用于监控和统计应用性能指标
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // 统计数据
  int _notifyCount = 0;
  int _widgetRebuildCount = 0;
  int _persistCount = 0;
  final List<int> _updateDurations = [];
  final List<int> _persistDurations = [];

  DateTime? _sessionStart;
  Timer? _reportTimer;

  /// 开始监控会话
  void startSession() {
    _sessionStart = DateTime.now();
    _notifyCount = 0;
    _widgetRebuildCount = 0;
    _persistCount = 0;
    _updateDurations.clear();
    _persistDurations.clear();

    // 每10秒输出一次报告
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      printReport();
    });

    debugPrint('📊 性能监控已启动');
  }

  /// 结束监控会话
  void endSession() {
    _reportTimer?.cancel();
    printFinalReport();
    debugPrint('📊 性能监控已结束');
  }

  /// 记录notifyListeners调用
  void recordNotify() {
    _notifyCount++;
  }

  /// 记录Widget重建
  void recordWidgetRebuild() {
    _widgetRebuildCount++;
  }

  /// 记录持久化操作
  void recordPersist() {
    _persistCount++;
  }

  /// 记录更新耗时
  void recordUpdateDuration(int milliseconds) {
    _updateDurations.add(milliseconds);
  }

  /// 记录持久化耗时
  void recordPersistDuration(int milliseconds) {
    _persistDurations.add(milliseconds);
  }

  /// 测量操作耗时
  Future<T> measure<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    final startTime = DateTime.now();
    try {
      return await action();
    } finally {
      final duration = DateTime.now().difference(startTime);
      debugPrint('⏱️ $operation 耗时: ${duration.inMilliseconds}ms');
    }
  }

  /// 打印实时报告
  void printReport() {
    if (_sessionStart == null) return;

    final elapsed = DateTime.now().difference(_sessionStart!).inSeconds;
    if (elapsed == 0) return;

    final notifyRate = (_notifyCount / elapsed).toStringAsFixed(1);
    final rebuildRate = (_widgetRebuildCount / elapsed).toStringAsFixed(1);
    final persistRate = (_persistCount / elapsed).toStringAsFixed(1);

    debugPrint('');
    debugPrint('📊 ========== 性能报告 (${elapsed}s) ==========');
    debugPrint('📢 notifyListeners: $_notifyCount 次 ($notifyRate/s)');
    debugPrint('🔄 Widget重建: $_widgetRebuildCount 次 ($rebuildRate/s)');
    debugPrint('💾 持久化操作: $_persistCount 次 ($persistRate/s)');

    if (_updateDurations.isNotEmpty) {
      final avgUpdate = _updateDurations.reduce((a, b) => a + b) / _updateDurations.length;
      final maxUpdate = _updateDurations.reduce((a, b) => a > b ? a : b);
      debugPrint('⚡ 更新耗时: 平均 ${avgUpdate.toStringAsFixed(1)}ms, 最大 ${maxUpdate}ms');
    }

    if (_persistDurations.isNotEmpty) {
      final avgPersist = _persistDurations.reduce((a, b) => a + b) / _persistDurations.length;
      final maxPersist = _persistDurations.reduce((a, b) => a > b ? a : b);
      debugPrint('💾 持久化耗时: 平均 ${avgPersist.toStringAsFixed(1)}ms, 最大 ${maxPersist}ms');
    }

    debugPrint('========================================');
    debugPrint('');
  }

  /// 打印最终报告
  void printFinalReport() {
    if (_sessionStart == null) return;

    final elapsed = DateTime.now().difference(_sessionStart!).inSeconds;
    if (elapsed == 0) return;

    debugPrint('');
    debugPrint('📊 ========== 最终性能报告 ==========');
    debugPrint('⏱️ 总时长: ${elapsed}s');
    debugPrint('📢 notifyListeners: $_notifyCount 次 (${(_notifyCount / elapsed).toStringAsFixed(1)}/s)');
    debugPrint('🔄 Widget重建: $_widgetRebuildCount 次 (${(_widgetRebuildCount / elapsed).toStringAsFixed(1)}/s)');
    debugPrint('💾 持久化操作: $_persistCount 次 (${(_persistCount / elapsed).toStringAsFixed(1)}/s)');

    if (_updateDurations.isNotEmpty) {
      final avgUpdate = _updateDurations.reduce((a, b) => a + b) / _updateDurations.length;
      final maxUpdate = _updateDurations.reduce((a, b) => a > b ? a : b);
      final minUpdate = _updateDurations.reduce((a, b) => a < b ? a : b);
      debugPrint('⚡ 更新耗时统计:');
      debugPrint('   平均: ${avgUpdate.toStringAsFixed(1)}ms');
      debugPrint('   最大: ${maxUpdate}ms');
      debugPrint('   最小: ${minUpdate}ms');
    }

    if (_persistDurations.isNotEmpty) {
      final avgPersist = _persistDurations.reduce((a, b) => a + b) / _persistDurations.length;
      final maxPersist = _persistDurations.reduce((a, b) => a > b ? a : b);
      final minPersist = _persistDurations.reduce((a, b) => a < b ? a : b);
      debugPrint('💾 持久化耗时统计:');
      debugPrint('   平均: ${avgPersist.toStringAsFixed(1)}ms');
      debugPrint('   最大: ${maxPersist}ms');
      debugPrint('   最小: ${minPersist}ms');
    }

    // 性能评级
    final notifyRate = _notifyCount / elapsed;
    final rebuildRate = _widgetRebuildCount / elapsed;

    debugPrint('');
    debugPrint('🎯 性能评级:');
    if (notifyRate < 10 && rebuildRate < 50) {
      debugPrint('   ⭐⭐⭐⭐⭐ 优秀 - 性能极佳！');
    } else if (notifyRate < 20 && rebuildRate < 100) {
      debugPrint('   ⭐⭐⭐⭐ 良好 - 性能不错');
    } else if (notifyRate < 30 && rebuildRate < 150) {
      debugPrint('   ⭐⭐⭐ 一般 - 有优化空间');
    } else if (notifyRate < 50 && rebuildRate < 200) {
      debugPrint('   ⭐⭐ 较差 - 需要优化');
    } else {
      debugPrint('   ⭐ 差 - 严重性能问题');
    }

    debugPrint('========================================');
    debugPrint('');
  }

  /// 获取统计数据
  Map<String, dynamic> getStats() {
    final elapsed = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!).inSeconds
        : 0;

    return {
      'elapsed': elapsed,
      'notifyCount': _notifyCount,
      'widgetRebuildCount': _widgetRebuildCount,
      'persistCount': _persistCount,
      'notifyRate': elapsed > 0 ? _notifyCount / elapsed : 0,
      'rebuildRate': elapsed > 0 ? _widgetRebuildCount / elapsed : 0,
      'persistRate': elapsed > 0 ? _persistCount / elapsed : 0,
      'avgUpdateDuration': _updateDurations.isNotEmpty
          ? _updateDurations.reduce((a, b) => a + b) / _updateDurations.length
          : 0,
      'avgPersistDuration': _persistDurations.isNotEmpty
          ? _persistDurations.reduce((a, b) => a + b) / _persistDurations.length
          : 0,
    };
  }

  /// 重置统计
  void reset() {
    _notifyCount = 0;
    _widgetRebuildCount = 0;
    _persistCount = 0;
    _updateDurations.clear();
    _persistDurations.clear();
    _sessionStart = null;
    _reportTimer?.cancel();
  }
}

/// 性能监控Widget包装器
class PerformanceMonitorWidget extends StatefulWidget {
  final Widget child;
  final String name;

  const PerformanceMonitorWidget({
    Key? key,
    required this.child,
    required this.name,
  }) : super(key: key);

  @override
  State<PerformanceMonitorWidget> createState() => _PerformanceMonitorWidgetState();
}

class _PerformanceMonitorWidgetState extends State<PerformanceMonitorWidget> {
  @override
  void initState() {
    super.initState();
    PerformanceMonitor().recordWidgetRebuild();
  }

  @override
  void didUpdateWidget(PerformanceMonitorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    PerformanceMonitor().recordWidgetRebuild();
    debugPrint('🔄 ${widget.name} 重建');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
