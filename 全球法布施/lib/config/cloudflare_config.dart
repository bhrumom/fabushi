import 'package:flutter/foundation.dart';

class CloudflareConfig {
  // 默认的 Worker URL，指向生产环境
  static const String workerUrl = 'https://fabushi-flutter-web-prod.bhrumom.workers.dev';
  
  // 开发/Staging 环境 URL
  static const String stagingWorkerUrl = 'https://fabushi-flutter-web-dev.bhrumom.workers.dev';
  
  // 生产环境 URL
  static const String productionWorkerUrl = 'https://fabushi-flutter-web-prod.bhrumom.workers.dev';
  
  // 获取当前环境的 Worker URL
  static String getCurrentWorkerUrl() {
    // 通过 --dart-define=ENVIRONMENT=... 在构建时注入环境
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    
    switch (environment) {
      case 'development':
        return stagingWorkerUrl; // 开发环境 API
      case 'production':
        return productionWorkerUrl; // 生产环境 API
      default:
        // 默认回退到生产环境，以保安全
        return productionWorkerUrl;
    }
  }
  
  // API 端点配置
  static const Map<String, String> apiEndpoints = {
    'auth': '/api/auth',
    'membership': '/api/stripe',
    'admin': '/api/admin',
    'alipay': '/api/alipay',
  };
  
  // 请求超时配置
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // 重试配置
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // 是否启用调试模式
  static const bool debugMode = bool.fromEnvironment('DEBUG', defaultValue: false);
}