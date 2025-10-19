// 应用初始化服务
// 统一管理应用启动时的初始化工作

import 'package:flutter/foundation.dart';
import '../config/unified_config.dart';
import 'unified_api_service.dart';
import 'app_settings.dart';

class AppInitializer {
  static bool _isInitialized = false;
  
  // 初始化应用
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      // 1. 初始化API服务（同步操作）
      UnifiedApiService().initialize();
      
      // 2. 异步加载设置（不阻塞启动）
      _ensureDefaultSettings().catchError((e) => debugPrint('设置加载失败: $e'));
      
      _isInitialized = true;
      
    } catch (e) {
      debugPrint('应用初始化失败: $e');
      _isInitialized = true;
      rethrow;
    }
  }
  
  // 确保默认设置存在
  static Future<void> _ensureDefaultSettings() async {
    try {
      final savedUrl = await AppSettings.getBackendUrl();
      if (savedUrl.isEmpty) {
        await AppSettings.setBackendUrl(UnifiedConfig.currentBackendUrl);
      }
    } catch (e) {
      debugPrint('设置加载失败: $e');
    }
  }

  
  // 重新初始化（用于设置更改后）
  static Future<void> reinitialize() async {
    _isInitialized = false;
    await initialize();
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
      'currentBackendUrl': UnifiedConfig.currentBackendUrl,
      'isProduction': UnifiedConfig.isProduction,
      'isWeb': UnifiedConfig.isWeb,
      'enableApiLogging': UnifiedConfig.enableApiLogging,
      'savedBackendUrl': await AppSettings.getBackendUrl(),
      'testMode': await AppSettings.getTestMode(),
    };
  }
}