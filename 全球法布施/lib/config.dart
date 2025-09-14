// lib/config.dart
// 注意：此文件已被弃用，请使用 config/unified_config.dart
// 为了保持向后兼容性，此文件仍然保留

import 'config/unified_config.dart';

class AppConfig {
  // 重要提示：
  // 此配置已迁移到 UnifiedConfig，建议使用新的统一配置系统
  // 新的配置支持：
  // - 智能后端地址选择
  // - 多环境支持
  // - 自动故障转移
  // - 统一的API管理
  
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

  // 后端代理URL - 首选地址（已弃用，使用 UnifiedConfig.currentBackendUrl）
  @Deprecated('使用 UnifiedConfig.currentBackendUrl 替代')
  static const String backendUrl = 'https://ombhrum.com';
  
  // 获取当前使用的后端 URL（已弃用，使用 UnifiedConfig.currentBackendUrl）
  @Deprecated('使用 UnifiedConfig.currentBackendUrl 替代')
  static String getCurrentBackendUrl() {
    // 使用新的统一配置
    return UnifiedConfig.currentBackendUrl;
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
