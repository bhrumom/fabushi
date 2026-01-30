import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WorkManager 保活服务
/// 
/// 在移动端使用 WorkManager 实现后台任务调度。
/// 在桌面端提供空实现（桌面端不需要后台保活）。
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
  /// 注意：实际的 WorkManager 初始化需要在移动端原生代码中完成
  static Future<void> initialize() async {
    if (!_isSupported) {
      debugPrint('⚠️ WorkManager 在当前平台不支持');
      return;
    }
    if (_isInitialized) return;
    
    // 桌面端跳过初始化
    _isInitialized = true;
    debugPrint('✅ WorkManager 服务已就绪');
  }
  
  /// 注册周期性保活任务
  static Future<void> registerKeepAliveTask() async {
    if (!_isSupported) return;
    debugPrint('📋 注册保活任务（仅移动端生效）');
  }
  
  /// 取消保活任务
  static Future<void> cancelKeepAliveTask() async {
    if (!_isSupported) return;
    debugPrint('🗑️ 取消保活任务');
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
  
  /// 清除发送状态
  static Future<void> clearSendingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyIsSendingActive, false);
      debugPrint('🗑️ 发送状态已清除');
    } catch (e) {
      debugPrint('❌ 清除发送状态失败: $e');
    }
  }
  
  /// 更新最后活跃时间
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
