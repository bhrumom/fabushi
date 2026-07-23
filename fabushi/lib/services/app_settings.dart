import 'dart:convert';
import 'dart:math';

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
  @Deprecated('Backend URL is managed through AppConfig.')
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

  // ============ 读诵匹配阈值设置 ============

  static const String _fastMatchThresholdKey = 'fast_match_threshold';
  static const String _matchThresholdKey = 'match_threshold';

  // 默认值（百分比形式，范围 0.0 ~ 1.0）
  static const double _defaultFastMatchThreshold = 0.50; // 快速切换阈值 50%
  static const double _defaultMatchThreshold = 0.50; // 普通匹配阈值 50%

  /// 获取快速切换阈值（匹配度达到此值立即切换）
  static Future<double> getFastMatchThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fastMatchThresholdKey) ??
        _defaultFastMatchThreshold;
  }

  /// 设置快速切换阈值
  static Future<void> setFastMatchThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fastMatchThresholdKey, threshold.clamp(0.1, 1.0));
  }

  /// 获取普通匹配阈值（需配合静音端点检测）
  static Future<double> getMatchThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_matchThresholdKey) ?? _defaultMatchThreshold;
  }

  /// 设置普通匹配阈值
  static Future<void> setMatchThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_matchThresholdKey, threshold.clamp(0.1, 1.0));
  }

  // ============ LLM 模型设置 ============

  static const String _selectedModelKey = 'selected_llm_model';
  static const String _isFirstLaunchKey = 'is_first_launch_v2';
  static const String _modelSetupCompleteKey = 'model_setup_complete';

  /// 获取已选择的 LLM 模型类型（字符串形式存储）
  static Future<String?> getSelectedModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedModelKey);
  }

  /// 设置选择的 LLM 模型
  static Future<void> setSelectedModelName(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, modelName);
  }

  /// 是否首次启动（用于模型设置引导）
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_isFirstLaunchKey);
  }

  /// 标记首次启动完成
  static Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  /// 模型设置是否已完成
  static Future<bool> isModelSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_modelSetupCompleteKey) ?? false;
  }

  /// 设置模型设置完成状态
  static Future<void> setModelSetupComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modelSetupCompleteKey, complete);
  }

  // ============ AI 后端 / 内置 OpenClaw 设置 ============

  static const String _aiBackendModeKey = 'ai_backend_mode_v1';
  static const String _openClawGatewayPortKey = 'openclaw_gateway_port_v1';
  static const String _openClawGatewayTokenKey = 'openclaw_gateway_token_v1';
  static const String _openClawModelKey = 'openclaw_model_v1';
  static const String _openClawModelOverrideKey = 'openclaw_model_override_v1';
  static const String _openClawDeepSeekModelKey = 'openclaw_deepseek_model_v1';
  static const String _openClawRemoteGatewayUrlKey =
      'openclaw_remote_gateway_url_v1';
  static const String _openClawActiveRuntimeSpecKey =
      'openclaw_active_runtime_spec_v1';
  static const String _desktopControlBridgePortKey =
      'desktop_control_bridge_port_v1';
  static const String _desktopControlBridgeTokenKey =
      'desktop_control_bridge_token_v1';
  static const String _chatGptApprovalStateKey = 'chatgpt_approval_state_v1';

  static const String defaultOpenClawGatewayModel = 'openclaw/default';
  static const String defaultOpenClawDeepSeekModel = 'deepseek/deepseek-chat';

  /// AI 后端模式：auto / embedded_openclaw / cloud_api。
  ///
  /// 默认 auto：桌面端走内置 OpenClaw，移动端/Web 继续走云端 API。
  static Future<String> getAiBackendModeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiBackendModeKey) ?? 'auto';
  }

  static Future<void> setAiBackendModeName(String modeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiBackendModeKey, modeName);
  }

  static Future<int> getOpenClawGatewayPort({int defaultValue = 18789}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_openClawGatewayPortKey);
    if (saved == null || saved < 1024 || saved > 65535) {
      return defaultValue;
    }
    return saved;
  }

  static Future<void> setOpenClawGatewayPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_openClawGatewayPortKey, port.clamp(1024, 65535));
  }

  /// 生成并持久化本机 Gateway bearer token。
  /// token 只用于 App 与本机 loopback Gateway 之间通信，不同步到云端。
  static Future<String> getOpenClawGatewayToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_openClawGatewayTokenKey);
    if (existing != null && existing.length >= 32) {
      return existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    await prefs.setString(_openClawGatewayTokenKey, token);
    return token;
  }

  static Future<String> getOpenClawModel({
    String defaultValue = defaultOpenClawGatewayModel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_openClawModelKey)?.trim();
    return value == null || value.isEmpty ? defaultValue : value;
  }

  static Future<void> setOpenClawModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openClawModelKey, model.trim());
  }

  static Future<String> getOpenClawModelOverride({
    String defaultValue = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openClawModelOverrideKey)?.trim() ?? defaultValue;
  }

  static Future<void> setOpenClawModelOverride(String modelOverride) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openClawModelOverrideKey, modelOverride.trim());
  }

  static Future<String> getOpenClawDeepSeekModel({
    String defaultValue = defaultOpenClawDeepSeekModel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_openClawDeepSeekModelKey)?.trim();
    return value == null || value.isEmpty ? defaultValue : value;
  }

  static Future<void> setOpenClawDeepSeekModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openClawDeepSeekModelKey, model.trim());
  }

  static Future<String> getOpenClawRemoteGatewayUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openClawRemoteGatewayUrlKey)?.trim() ?? '';
  }

  static Future<void> setOpenClawRemoteGatewayUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_openClawRemoteGatewayUrlKey);
      return;
    }
    await prefs.setString(_openClawRemoteGatewayUrlKey, trimmed);
  }

  static Future<Map<String, dynamic>?> getOpenClawActiveRuntimeSpec() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_openClawActiveRuntimeSpecKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      await prefs.remove(_openClawActiveRuntimeSpecKey);
    }
    return null;
  }

  static Future<void> setOpenClawActiveRuntimeSpec(
    Map<String, dynamic> spec,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openClawActiveRuntimeSpecKey, jsonEncode(spec));
  }

  static Future<void> clearOpenClawActiveRuntimeSpec() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_openClawActiveRuntimeSpecKey);
  }

  static Future<int> getDesktopControlBridgePort({
    int defaultValue = 18790,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_desktopControlBridgePortKey);
    if (saved == null || saved < 1024 || saved > 65535) {
      return defaultValue;
    }
    return saved;
  }

  static Future<void> setDesktopControlBridgePort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_desktopControlBridgePortKey, port.clamp(1024, 65535));
  }

  /// 生成并持久化桌面工具 loopback bearer token。
  /// token 只在本机大乘 App、内置 OpenClaw 和 Chrome 扩展之间使用。
  static Future<String> getDesktopControlBridgeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_desktopControlBridgeTokenKey);
    if (existing != null && existing.length >= 32) {
      return existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    await prefs.setString(_desktopControlBridgeTokenKey, token);
    return token;
  }

  static Future<Map<String, dynamic>?> getChatGptApprovalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatGptApprovalStateKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      await prefs.remove(_chatGptApprovalStateKey);
    }
    return null;
  }

  static Future<void> setChatGptApprovalState(
    Map<String, dynamic> state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatGptApprovalStateKey, jsonEncode(state));
  }

  // --- Codex & 机器人之父 API 设置 ---
  static const String _codexApiKey = 'codex_api_key_v1';
  static const String _codexBaseUrlKey = 'codex_base_url_v1';
  static const String _codexModelNameKey = 'codex_model_name_v1';
  static const String _codexProviderKey = 'codex_provider_v1';

  static Future<String> getCodexApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_codexApiKey)?.trim();
    return value == null || value.isEmpty || value == 'default'
        ? 'dacheng-openclaw-proxy'
        : value;
  }

  static Future<void> setCodexApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codexApiKey, key);
  }

  static Future<String> getCodexBaseUrl() async {
    return AppConfig.openClawDeepSeekProxyBaseUrl;
  }

  static Future<void> setCodexBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codexBaseUrlKey, url);
  }

  static Future<String> getCodexModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_codexModelNameKey) ?? 'deepseek-chat';
  }

  static Future<void> setCodexModelName(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codexModelNameKey, model);
  }

  static Future<String> getCodexProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_codexProviderKey) ?? 'deepSeek';
  }

  static Future<void> setCodexProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codexProviderKey, provider);
  }
}
