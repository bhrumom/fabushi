import 'package:shared_preferences/shared_preferences.dart';
import '../config/unified_config.dart';

class AppSettings {
  static const String _testModeKey = 'test_mode';
  static const String _backendUrlKey = 'backend_url';
  
  // 默认设置
  static const bool _defaultTestMode = false; // 使用真实后端
  static String get _defaultBackendUrl => UnifiedConfig.currentBackendUrl; // 使用统一配置
  
  // 获取测试模式状态
  static Future<bool> getTestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_testModeKey) ?? _defaultTestMode;
  }
  
  // 设置测试模式状态
  static Future<void> setTestMode(bool testMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testModeKey, testMode);
  }
  
  // 获取后端URL
  static Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_backendUrlKey);
    
    // 如果用户没有自定义URL，使用统一配置的当前URL
    if (savedUrl == null || savedUrl.isEmpty) {
      return UnifiedConfig.currentBackendUrl;
    }
    
    return savedUrl;
  }
  
  // 设置后端URL
  static Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url);
  }
  
  // 重置为默认设置
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testModeKey, _defaultTestMode);
    await prefs.setString(_backendUrlKey, _defaultBackendUrl);
  }
}