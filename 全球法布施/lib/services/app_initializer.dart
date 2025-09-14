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
      debugPrint('开始初始化应用...');
      
      // 1. 打印当前配置信息
      if (UnifiedConfig.enableApiLogging) {
        UnifiedConfig.printCurrentConfig();
      }
      
      // 2. 初始化API服务
      UnifiedApiService().initialize();
      debugPrint('API服务初始化完成');
      
      // 3. 检查并设置默认配置
      await _ensureDefaultSettings();
      debugPrint('默认设置检查完成');
      
      // 4. 测试后端连接（可选）
      if (UnifiedConfig.enableApiLogging) {
        await _testBackendConnection();
      }
      
      _isInitialized = true;
      debugPrint('应用初始化完成');
      
    } catch (e) {
      debugPrint('应用初始化失败: $e');
      // 即使初始化失败，也标记为已初始化，避免重复尝试
      _isInitialized = true;
      rethrow;
    }
  }
  
  // 确保默认设置存在
  static Future<void> _ensureDefaultSettings() async {
    try {
      // 检查是否有保存的后端URL
      final savedUrl = await AppSettings.getBackendUrl();
      
      // 如果没有保存的URL或URL为空，设置默认值
      if (savedUrl.isEmpty) {
        await AppSettings.setBackendUrl(UnifiedConfig.currentBackendUrl);
        debugPrint('设置默认后端URL: ${UnifiedConfig.currentBackendUrl}');
      } else {
        debugPrint('使用已保存的后端URL: $savedUrl');
      }
      
      // 检查测试模式设置
      final testMode = await AppSettings.getTestMode();
      debugPrint('当前测试模式: $testMode');
      
    } catch (e) {
      debugPrint('设置默认配置失败: $e');
    }
  }
  
  // 测试后端连接
  static Future<void> _testBackendConnection() async {
    try {
      debugPrint('测试后端连接...');
      
      final apiService = UnifiedApiService();
      final isHealthy = await apiService.checkHealth();
      
      if (isHealthy) {
        debugPrint('✅ 后端连接正常');
      } else {
        debugPrint('❌ 后端连接失败，尝试寻找可用的后端...');
        
        // 尝试寻找可用的后端
        final workingUrl = await apiService.findWorkingBackend();
        if (workingUrl != null) {
          await AppSettings.setBackendUrl(workingUrl);
          debugPrint('✅ 找到可用的后端: $workingUrl');
        } else {
          debugPrint('❌ 未找到可用的后端');
        }
      }
    } catch (e) {
      debugPrint('后端连接测试失败: $e');
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