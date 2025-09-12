class CloudflareConfig {
  // Cloudflare Worker 部署 URL
  static const String workerUrl = 'https://fabushi.bhrumom.workers.dev';
  
  // 备用 URL（如果有多个部署环境）
  static const String stagingWorkerUrl = 'https://fabushi.bhrumom.workers.dev';
  
  // 生产环境 URL
  static const String productionWorkerUrl = 'https://fabushi.bhrumom.workers.dev';
  
  // 获取当前环境的 Worker URL
  static String getCurrentWorkerUrl() {
    // 可以根据环境变量或配置来决定使用哪个 URL
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    
    switch (environment) {
      case 'staging':
        return stagingWorkerUrl;
      case 'production':
        return productionWorkerUrl;
      default:
        return workerUrl;
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