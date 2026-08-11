// Platform core initialization.
//
// Global Dharma distribution, video feed, background transfer recovery and
// local media pipelines belong to MiniApps or optional tools and must not be
// initialized by the host platform.

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/startup/startup_optimizer.dart';
import 'app_settings.dart';
import 'unified_api_service.dart';

class AppInitializer {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  static Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      final optimizer = StartupOptimizer();
      optimizer.addInitTask(() async {
        UnifiedApiService().initialize();
        debugPrint('✅ Platform API initialized');
      });
      optimizer.addInitTask(() async {
        await _ensureDefaultSettings();
        debugPrint('✅ Platform settings initialized');
      });
      await optimizer.startInitialization();
      _isInitialized = true;
      debugPrint('🚀 [AppInitializer] platform core ready');
    } catch (error) {
      debugPrint('Platform core initialization failed: $error');
      _isInitialized = true;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  static Future<void> _ensureDefaultSettings() async {
    final savedUrl = await AppSettings.getBackendUrl();
    if (savedUrl.isEmpty) {
      await AppSettings.setBackendUrl(AppConfig.currentBackendUrl);
    }
  }

  static Future<void> reinitialize() async {
    _isInitialized = false;
    _isInitializing = false;
    UnifiedApiService().dispose();
    await initialize();
  }

  static bool get isInitialized => _isInitialized;

  static void dispose() {
    UnifiedApiService().dispose();
    _isInitialized = false;
  }

  static Future<Map<String, dynamic>> getInitializationInfo() async => {
    'isInitialized': _isInitialized,
    'currentBackendUrl': AppConfig.currentBackendUrl,
    'isProduction': AppConfig.isProduction,
    'isWeb': AppConfig.isWeb,
    'enableApiLogging': AppConfig.enableApiLogging,
    'savedBackendUrl': await AppSettings.getBackendUrl(),
    'testMode': await AppSettings.getTestMode(),
  };
}
