// 统一配置管理
// 所有平台和环境的API配置都在这里统一管理

import 'package:flutter/foundation.dart';

class UnifiedConfig {
  // 环境检测
  static bool get isProduction {
    // 优先检查当前URL（用于部署环境）
    if (kIsWeb) {
      final currentUrl = Uri.base.toString();
      if (currentUrl.contains('fabushi-flutter-web-dev') || currentUrl.contains('localhost')) {
        return false; // 开发环境
      }
      if (currentUrl.contains('fabushi-flutter-web-prod')) {
        return true; // 生产环境
      }
    }
    
    // 回退到编译时环境变量
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    return environment == 'production';
  }
  
  static bool get isDevelopment => !isProduction;
  static bool get isWeb => kIsWeb;
  
  // ===== 主要后端地址配置 =====
  
  // 主要后端地址 - 优先使用
  static const String primaryBackendUrl = 'https://ombhrum.com';
  
  // Cloudflare Worker 地址 - 备用
  static const String cloudflareWorkerProdUrl = 'https://flutter.ombhrum.com';
  static const String cloudflareWorkerDevUrl = 'https://flutter-dev.ombhrum.com';
  
  // 本地开发地址
  static const String localDevUrl = 'http://localhost:8787';
  
  // ===== 智能地址选择 =====
  
  // 获取当前应该使用的后端地址
  static String get currentBackendUrl {
    if (isWeb) {
      // Web平台：使用相对路径或当前域名，避免CORS问题
      final currentUrl = Uri.base.toString();
      if (currentUrl.contains('fabushi-flutter-web-dev')) {
        return ''; // 使用相对路径，同域名调用
      } else if (currentUrl.contains('fabushi-flutter-web-prod')) {
        return ''; // 使用相对路径，同域名调用
      } else if (currentUrl.contains('localhost')) {
        // 本地开发时使用开发环境Worker
        return cloudflareWorkerDevUrl;
      }
      // 默认使用生产环境
      return cloudflareWorkerProdUrl;
    } else {
      // 其他平台（移动端、桌面端）：优先使用Cloudflare Worker
      // 因为主要后端地址（ombhrum.com）可能不稳定或返回404
      if (isProduction) {
        // 生产环境优先使用Cloudflare Worker生产地址
        return cloudflareWorkerProdUrl;
      } else {
        // 开发环境使用Cloudflare Worker开发地址
        return cloudflareWorkerDevUrl;
      }
    }
  }
  
  // ===== API 端点配置 =====
  
  // 认证相关API
  static String get loginUrl => '$currentBackendUrl/api/auth/login';
  static String get registerUrl => '$currentBackendUrl/api/auth/register';
  static String get verifyUrl => '$currentBackendUrl/api/auth/verify';
  static String get logoutUrl => '$currentBackendUrl/api/auth/logout';
  static String get sendVerificationCodeUrl => '$currentBackendUrl/api/auth/send-verification-code';
  static String get verifyCodeUrl => '$currentBackendUrl/api/auth/verify-code';
  static String get forgotPasswordUrl => '$currentBackendUrl/api/auth/forgot-password';
  static String get resetPasswordUrl => '$currentBackendUrl/api/auth/reset-password';
  static String get userInfoUrl => '$currentBackendUrl/api/auth/user-info';
  static String get bindEmailUrl => '$currentBackendUrl/api/auth/bind-email';
  
  // 微信登录相关API
  static String get wechatLoginUrlApi => '$currentBackendUrl/api/auth/wechat/login-url';
  static String get wechatLoginUrl => '$currentBackendUrl/api/auth/wechat/login';
  static String get wechatBindUrl => '$currentBackendUrl/api/auth/wechat/bind';
  static String get wechatRegisterUrl => '$currentBackendUrl/api/auth/wechat/register';
  static String get wechatUnbindUrl => '$currentBackendUrl/api/auth/wechat/unbind';
  
  // 支付宝登录相关API
  static String get alipayLoginUrlApi => '$currentBackendUrl/api/auth/alipay/login-url';
  static String get alipayLoginUrl => '$currentBackendUrl/api/auth/alipay/login';
  static String get alipayBindUrl => '$currentBackendUrl/api/auth/alipay/bind';
  static String get alipayRegisterUrl => '$currentBackendUrl/api/auth/alipay/register';
  static String get alipayUnbindUrl => '$currentBackendUrl/api/auth/alipay/unbind';
  
  // 支付宝相关API
  static String get alipayCreateOrderUrl => '$currentBackendUrl/api/alipay/create-order';
  static String get alipayQueryOrderUrl => '$currentBackendUrl/api/alipay/query-order';
  static String get alipayNotifyUrl => '$currentBackendUrl/api/alipay/notify';
  static String get alipayMembershipStatusUrl => '$currentBackendUrl/api/alipay/check-membership';
  
  // Stripe相关API
  static String get stripeMembershipStatusUrl => '$currentBackendUrl/api/stripe/membership-status';
  static String get stripeCreateSubscriptionUrl => '$currentBackendUrl/api/stripe/create-subscription';
  static String get stripeCancelSubscriptionUrl => '$currentBackendUrl/api/stripe/cancel-subscription';
  static String get stripeWebhookUrl => '$currentBackendUrl/api/stripe/webhook';
  
  // 管理员相关API
  static String get adminCheckStatusUrl => '$currentBackendUrl/api/admin/check-status';
  static String get adminCreateRedeemCodeUrl => '$currentBackendUrl/api/admin/create-redeem-code';
  static String get adminRedeemCodesUrl => '$currentBackendUrl/api/admin/redeem-codes';
  static String get adminUseRedeemCodeUrl => '$currentBackendUrl/api/admin/use-redeem-code';
  static String get adminDeleteRedeemCodeUrl => '$currentBackendUrl/api/admin/delete-redeem-code';
  
  // ===== 调试和配置信息 =====
  
  // 获取当前环境名称
  static String get currentEnvironment {
    return isProduction ? '生产环境' : '开发环境';
  }
  
  // 获取当前URL信息（仅Web平台）
  static String get currentUrlInfo {
    if (kIsWeb) {
      return Uri.base.toString();
    }
    return 'N/A (非Web平台)';
  }
  
  // 打印配置信息（调试用）
  static void printConfigInfo() {
    if (kDebugMode) {
      print('=== 统一配置信息 ===');
      print('当前环境: $currentEnvironment');
      print('平台: ${isWeb ? "Web" : "Native"}');
      print('当前URL: $currentUrlInfo');
      print('当前后端URL: "$currentBackendUrl"');
      print('Web平台策略: ${isWeb ? "同域名调用避免CORS" : "使用ombhrum.com"}');
      print('主要后端: $primaryBackendUrl');
      print('Cloudflare生产: $cloudflareWorkerProdUrl');
      print('Cloudflare开发: $cloudflareWorkerDevUrl');
      print('本地开发: $localDevUrl');
      print('================');
    }
  }
  static String get adminGetPriceUrl => '$currentBackendUrl/api/admin/get-price';
  static String get adminPurchaseHistoryUrl => '$currentBackendUrl/api/admin/purchase-history';
  static String get adminRedeemHistoryUrl => '$currentBackendUrl/api/admin/redeem-history';
  
  // 文件上传相关API
  static String get r2ListUrl => '$currentBackendUrl/r2?list=true';
  
  // 全球发送API
  static String get globalSendUrl => '$currentBackendUrl/send-global';
  
  // ===== 请求配置 =====
  
  // 请求头配置
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'FabushiApp/${isWeb ? "Web" : "Mobile"}',
  };
  
  // 超时配置
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
  
  // 重试配置
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // ===== 存储键名 =====
  static const String tokenStorageKey = 'auth_token';
  static const String userInfoStorageKey = 'user_info';
  static const String backendUrlStorageKey = 'backend_url';
  static const String testModeStorageKey = 'test_mode';
  
  // ===== 调试和日志配置 =====
  static const bool enableApiLogging = true;
  static const bool debugMode = bool.fromEnvironment('DEBUG', defaultValue: false);
  
  // ===== 错误消息配置 =====
  static const Map<String, String> errorMessages = {
    'network_error': '网络连接失败，请检查网络设置',
    'server_error': '服务器错误，请稍后重试',
    'timeout_error': '请求超时，请检查网络连接',
    'auth_error': '认证失败，请重新登录',
    'permission_error': '权限不足',
    'validation_error': '数据验证失败',
    'unknown_error': '未知错误，请联系客服',
  };
  
  // ===== 备用地址列表 =====
  static List<String> get fallbackUrls {
    // 所有平台统一策略：优先使用Cloudflare Worker，ombhrum.com作为备用
    final workerUrl = isProduction ? cloudflareWorkerProdUrl : cloudflareWorkerDevUrl;
    return [
      workerUrl,           // Cloudflare Worker（优先）
      primaryBackendUrl,   // 主要后端（备用）
    ];
  }
  
  // ===== 调试信息 =====
  static void printCurrentConfig() {
    print('=== 统一配置信息 ===');
    print('当前环境: ${isProduction ? "生产环境" : "开发环境"}');
    print('平台: ${isWeb ? "Web" : "移动端"}');
    print('当前后端URL: $currentBackendUrl');
    if (isWeb) {
      print('Web平台策略: 直接调用Cloudflare Worker');
    } else {
      print('Native平台策略: 优先使用Cloudflare Worker');
    }
    print('主要后端: $primaryBackendUrl');
    print('Cloudflare生产: $cloudflareWorkerProdUrl');
    print('Cloudflare开发: $cloudflareWorkerDevUrl');
    print('启用日志: $enableApiLogging');
    print('最大重试次数: $maxRetries');
    print('备用地址数量: ${fallbackUrls.length}');
    print('================');
  }
  
  // ===== 健康检查 =====
  static String get healthCheckUrl => '$currentBackendUrl/health';
  
  // 检查后端是否可用
  static Future<bool> isBackendHealthy() async {
    try {
      // 这里可以添加实际的健康检查逻辑
      return true;
    } catch (e) {
      return false;
    }
  }
}