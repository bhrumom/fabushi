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

class AppInitializer {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  // 初始化应用 - 优化版本，避免阻塞
  static Future<void> initialize() async {
    if (_isInitialized || _isInitializing) {
      return;
    }
    
    _isInitializing = true;

    try {
      final optimizer = StartupOptimizer();
      
      // 添加初始化任务到队列
      optimizer.addInitTask(() async {
        UnifiedApiService().initialize();
        debugPrint('✅ API服务初始化完成');
      });
      
      optimizer.addInitTask(() async {
        await _ensureDefaultSettings();
        debugPrint('✅ 默认设置加载完成');
      });
      
      optimizer.addInitTask(() async {
        await _retryPendingUploads();
        debugPrint('✅ 待上传数据重试完成');
      });
      
      optimizer.addInitTask(() async {
        await LikeService().initialize();
        debugPrint('✅ 点赞服务初始化完成');
      });
      
      // 初始化统一保活服务（基于 audio_service + MediaSession）
      optimizer.addInitTask(() async {
        await KeepAliveService.instance.initialize();
        debugPrint('✅ 统一保活服务初始化完成');
      });
      
      // 开始分批初始化
      await optimizer.startInitialization();
      
      _isInitialized = true;
      debugPrint('🎉 应用初始化完成');
    } catch (e) {
      debugPrint('应用初始化失败: $e');
      _isInitialized = true;
      rethrow;
    } finally {
      _isInitializing = false;
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
