import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

class AppSettings {
  static const String _testModeKey = 'test_mode';
  static const String _ttsMutedKey = 'tts_muted';
  static const String _defaultTtsMutedKey = 'default_tts_muted';

  // 默认设置
  static const bool _defaultTestMode = false; // 使用真实后端

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

  // 获取后端URL - 现在始终使用统一配置
  static Future<String> getBackendUrl() async {
    // 始终使用统一配置的当前URL，不再支持用户自定义
    return AppConfig.currentBackendUrl;
  }

  // 设置后端URL - 已移除，不再支持用户自定义后端URL
  @deprecated
  static Future<void> setBackendUrl(String url) async {
    // 此方法已废弃，不再执行任何操作
    // 所有后端URL配置都通过 unified_config.dart 统一管理
  }

  // 重置为默认设置
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testModeKey, _defaultTestMode);
    // 不再重置后端URL，因为它现在始终使用统一配置
  }

  // ============ TTS 静音设置 ============

  /// 获取TTS是否静音
  static Future<bool> getTtsMuted() async {
    final prefs = await SharedPreferences.getInstance();
    // 首次启动时使用默认设置
    if (!prefs.containsKey(_ttsMutedKey)) {
      return await getDefaultTtsMuted();
    }
    return prefs.getBool(_ttsMutedKey) ?? true;
  }

  /// 设置TTS静音状态
  static Future<void> setTtsMuted(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsMutedKey, muted);
  }

  /// 获取启动时默认静音设置
  static Future<bool> getDefaultTtsMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_defaultTtsMutedKey) ?? true; // 默认静音
  }

  /// 设置启动时默认静音
  static Future<void> setDefaultTtsMuted(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_defaultTtsMutedKey, muted);
  }
}
