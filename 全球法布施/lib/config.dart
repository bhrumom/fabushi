// lib/config.dart

import 'config/cloudflare_config.dart';

class AppConfig {
  // 重要提示：
  // 请将此URL替换为您部署的后端代理服务器的实际地址。
  //
  // 示例:
  // static const String backendUrl = 'https://your-backend-service.com';
  //
  // 本地开发时可以指向本地服务器:
  // static const String backendUrl = 'http://localhost:8080';
  //
  // Cloudflare Worker 部署:
  // 使用 CloudflareConfig.getCurrentWorkerUrl() 获取 Worker URL
  
  // 国家代码列表
  static const List<String> countryCodes = [
    'ALL',
    'US', // 美国
    'CN', // 中国
    'IN', // 印度
    'FR', // 法国
    'DE', // 德国
    'BR', // 巴西
    'RU', // 俄罗斯
    'JP', // 日本
    'KR', // 韩国
    'GB', // 英国
    'CA', // 加拿大
    'AU', // 澳大利亚
  ];

  // 国家名称映射
  static const Map<String, String> countryNames = {
    'ALL': '所有国家',
    'US': '美国',
    'CN': '中国',
    'IN': '印度',
    'FR': '法国',
    'DE': '德国',
    'BR': '巴西',
    'RU': '俄罗斯',
    'JP': '日本',
    'KR': '韩国',
    'GB': '英国',
    'CA': '加拿大',
    'AU': '澳大利亚',
  };

  // 后端代理URL - 支持多种部署方式
  static const String backendUrl = 'https://ombhrum.com';
  
  // Cloudflare Worker URL（优先使用）
  static String get cloudflareWorkerUrl => CloudflareConfig.getCurrentWorkerUrl();
  
  // 获取当前使用的后端 URL
  static String getCurrentBackendUrl() {
    // 优先使用 Cloudflare Worker
    const useCloudflareWorker = bool.fromEnvironment('USE_CLOUDFLARE_WORKER', defaultValue: true);
    
    if (useCloudflareWorker) {
      return cloudflareWorkerUrl;
    }
    
    return backendUrl;
  }
  
  // Cloudflare Worker API 端点
  static const String authApiBase = '/api/auth';
  static const String membershipApiBase = '/api/stripe';
  static const String alipayApiBase = '/api/alipay';
  static const String adminApiBase = '/api/admin';

  // WiFi广播配置
  static const bool enableWifiBroadcast = true;

  // 全球发送配置
  static const bool enableGlobalSending = true;

  // 文件分块大小（字节）
  static const int fileChunkSize = 1024; // 1KB

  // 最大重试次数
  static const int maxRetryCount = 3;

  // 超时时间（毫秒）
  static const int timeoutDuration = 5000;

  // 默认端口
  static const List<int> defaultPorts = [53, 80, 443, 5353];

  // 默认国家
  static const String defaultCountry = 'ALL';
  
  // 是否启用循环发送
  static const bool enableLooping = false;
}
