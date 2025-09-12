import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AppSettings {
  static const String _testModeKey = 'test_mode';
  static const String _backendUrlKey = 'backend_url';
  
  // 默认设置
  static const bool _defaultTestMode = false; // 使用真实的 Cloudflare Worker 后端
  static String get _defaultBackendUrl => AppConfig.getCurrentBackendUrl();
  
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
    return prefs.getString(_backendUrlKey) ?? _defaultBackendUrl;
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