import 'package:flutter/foundation.dart';

/// 应用配置 - 统一管理所有配置项
class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  // 环境配置
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'production',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';
  static bool get isWeb => kIsWeb;

  // API配置
  static const String primaryBackendUrl = 'https://ombhrum.com';
  static const String cloudflareWorkerProdUrl = 'https://flutter.ombhrum.com';
  static const String cloudflareWorkerDevUrl =
      'https://flutter-dev.ombhrum.com';
  static const String localDevUrl = 'http://localhost:8787';

  static String get apiUrl {
    if (isWeb) {
      final currentUrl = Uri.base.toString();
      if (currentUrl.contains('fabushi-flutter-web-dev') ||
          currentUrl.contains('localhost')) {
        return cloudflareWorkerDevUrl;
      }
      return cloudflareWorkerProdUrl;
    }
    return isProduction ? cloudflareWorkerProdUrl : cloudflareWorkerDevUrl;
  }

  // 应用信息
  static const String appName = '全球法布施';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // 功能开关
  static const bool enableFirebaseAuth = true;
  static const bool enableAlipay = true;
  static const bool enableVideoFeed = true;
  static bool get enableDebugMode => !isProduction;

  // 传输配置
  static const int fileChunkSize = 1024;
  static const int maxRetryCount = 3;
  static const int timeoutDuration = 5000;
  static const int maxConcurrentTransfers = 5;

  // 缓存配置
  static const int cacheMaxAge = 7;
  static const int maxCacheSize = 100;

  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // 超时配置
  static final Duration requestTimeout = const Duration(seconds: 30);
  static final Duration connectTimeout = const Duration(seconds: 10);

  // 重试配置
  static const int maxRetries = 3;
  static final Duration retryDelay = const Duration(seconds: 1);

  // 日志配置
  static const bool enableLogging = true;
  static bool get enableNetworkLogging => !isProduction;
  static bool get enablePerformanceLogging => !isProduction;

  // 存储键名
  static const String tokenStorageKey = 'auth_token';
  static const String userInfoStorageKey = 'user_info';

  static void printConfigInfo() {
    if (kDebugMode) {
      print('=== 应用配置 ===');
      print('环境: $environment');
      print('平台: ${isWeb ? "Web" : "Native"}');
      print('API URL: $apiUrl');
      print('================');
    }
  }
}
