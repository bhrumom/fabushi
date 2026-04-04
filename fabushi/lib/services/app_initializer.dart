// 应用初始化服务
// 统一管理应用启动时的初始化工作

import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/startup/startup_optimizer.dart';
import 'unified_api_service.dart';
import 'app_settings.dart';
import '../models/file_transfer_model.dart';
import 'like_service.dart';
import 'keep_alive_service.dart';
import 'workmanager_keep_alive.dart';
import 'memory_manager.dart';

class AppInitializer {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  // 初始化应用 - 优化版本，避免阻塞
  // Web平台：跳过非必要的原生服务初始化
  static Future<void> initialize() async {
    if (_isInitialized || _isInitializing) {
      return;
    }
    
    _isInitializing = true;

    try {
      final optimizer = StartupOptimizer();
      
      // ✅ 核心服务初始化（所有平台）
      optimizer.addInitTask(() async {
        UnifiedApiService().initialize();
        debugPrint('✅ API服务初始化完成');
      });
      
      optimizer.addInitTask(() async {
        await _ensureDefaultSettings();
        debugPrint('✅ 默认设置加载完成');
      });
      
      optimizer.addInitTask(() async {
        await LikeService().initialize();
        debugPrint('✅ 点赞服务初始化完成');
      });
      
      // ⚠️ 以下服务仅在非Web平台初始化
      if (!kIsWeb) {
        optimizer.addInitTask(() async {
          await _retryPendingUploads();
          debugPrint('✅ 待上传数据重试完成');
        });
        
        // 初始化内存管理器
        optimizer.addInitTask(() async {
          await MemoryManager.instance.initialize();
          debugPrint('✅ 内存管理器初始化完成');
        });
        
        // 初始化统一保活服务（基于 audio_service + MediaSession）
        optimizer.addInitTask(() async {
          await KeepAliveService.instance.initialize();
          debugPrint('✅ 统一保活服务初始化完成');
        });
        
        // 初始化 WorkManager 恢复机制（仅 Android）
        optimizer.addInitTask(() async {
          await WorkManagerKeepAlive.initialize();
          debugPrint('✅ WorkManager 初始化完成');
        });
        
        // 检查是否需要恢复发送任务
        optimizer.addInitTask(() async {
          await _checkAndRecoverSendingTask();
          debugPrint('✅ 发送任务恢复检查完成');
        });
      } else {
        debugPrint('🌐 Web平台：跳过原生服务初始化');
      }
      
      // 开始分批初始化
      await optimizer.startInitialization();
      
      _isInitialized = true;
      debugPrint('🚀 [AppInitializer] 初始化核心任务完成'); // Modified debugPrint message
      
      // LLM 模型按需加载：仅在用户点击目录「功德利益」时初始化
      // 不在启动时预加载，避免卡顿和 iOS 内存警告

    } catch (e) {
      debugPrint('应用初始化失败: $e');
      _isInitialized = true;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }
  
  // 检查并恢复发送任务
  static Future<void> _checkAndRecoverSendingTask() async {
    try {
      final snapshot = await WorkManagerKeepAlive.checkNeedsRecovery();
      if (snapshot != null) {
        debugPrint('🔄 检测到需要恢复的发送任务');
        debugPrint('   轮次: ${snapshot.loopCount}');
        debugPrint('   文件: ${snapshot.filePaths.length} 个');
        debugPrint('   上次活跃: ${snapshot.lastActiveTime}');
        // 注意：实际恢复发送的逻辑需要在 FileTransferModel 中实现
        // 这里只是记录检测结果
      }
    } catch (e) {
      debugPrint('⚠️ 恢复检查失败: $e');
    }
  }

  // 确保默认设置存在
  static Future<void> _ensureDefaultSettings() async {
    try {
      final savedUrl = await AppSettings.getBackendUrl();
      if (savedUrl.isEmpty) {
        await AppSettings.setBackendUrl(AppConfig.currentBackendUrl);
      }
    } catch (e) {
      debugPrint('设置加载失败: $e');
    }
  }

  // 重新初始化（用于设置更改后）
  static Future<void> reinitialize() async {
    _isInitialized = false;
    _isInitializing = false;
    UnifiedApiService().dispose(); // 清理旧实例
    await initialize();
  }

  // 重试上传未完成的传输数据
  static Future<void> _retryPendingUploads() async {
    try {
      // 注意：这里需要一个静态方法，不依赖Provider
      final model = FileTransferModel();
      await model.retryPendingUploads();
    } catch (e) {
      debugPrint('重试上传失败: $e');
    }
  }

  // 检查是否已初始化
  static bool get isInitialized => _isInitialized;

  // 清理资源
  static void dispose() {
    try {
      UnifiedApiService().dispose();
      _isInitialized = false;
      debugPrint('应用资源清理完成');
    } catch (e) {
      debugPrint('应用资源清理失败: $e');
    }
  }

  // 获取初始化状态信息
  static Future<Map<String, dynamic>> getInitializationInfo() async {
    return {
      'isInitialized': _isInitialized,
      'currentBackendUrl': AppConfig.currentBackendUrl,
      'isProduction': AppConfig.isProduction,
      'isWeb': AppConfig.isWeb,
      'enableApiLogging': AppConfig.enableApiLogging,
      'savedBackendUrl': await AppSettings.getBackendUrl(),
      'testMode': await AppSettings.getTestMode(),
    };
  }
}
