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

  static bool get isProduction {
    if (kIsWeb) {
      final currentUrl = Uri.base.toString();
      if (currentUrl.contains('fabushi-flutter-web-dev') ||
          currentUrl.contains('localhost')) {
        return false;
      }
      if (currentUrl.contains('fabushi-flutter-web-prod')) {
        return true;
      }
    }
    return environment == 'production';
  }

  static bool get isDevelopment => !isProduction;
  static bool get isStaging => environment == 'staging';
  static bool get isWeb => kIsWeb;

  // API配置
  static const String primaryBackendUrl = 'https://flutter.ombhrum.com';
  static const String cloudflareWorkerProdUrl = 'https://flutter.ombhrum.com';
  static const String cloudflareWorkerDevUrl = 'https://flutter.ombhrum.com';
  static const String localDevUrl = 'http://localhost:8787';

  static String get currentBackendUrl {
    // 统一使用 flutter.ombhrum.com 作为后端地址
    return primaryBackendUrl;
  }

  static String get apiUrl => currentBackendUrl;

  // 应用信息
  static const String appName = '大乘';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // 功能开关
  static const bool enableFirebaseAuth = true;
  static const bool enableAlipay = true;
  static const bool enableAppleIAP = true;
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
  static const String backendUrlStorageKey = 'backend_url';
  static const String testModeStorageKey = 'test_mode';

  // API端点
  static String get loginUrl => '$currentBackendUrl/api/auth/login';
  static String get registerUrl => '$currentBackendUrl/api/auth/register';
  static String get verifyUrl => '$currentBackendUrl/api/auth/verify';
  static String get logoutUrl => '$currentBackendUrl/api/auth/logout';
  static String get deleteAccountUrl => '$currentBackendUrl/api/auth/delete';
  static String get sendVerificationCodeUrl =>
      '$currentBackendUrl/api/auth/send-verification-code';
  static String get verifyCodeUrl => '$currentBackendUrl/api/auth/verify-code';
  static String get forgotPasswordUrl =>
      '$currentBackendUrl/api/auth/forgot-password';
  static String get resetPasswordUrl =>
      '$currentBackendUrl/api/auth/reset-password';
  static String get userInfoUrl => '$currentBackendUrl/api/auth/user-info';
  static String get bindEmailUrl => '$currentBackendUrl/api/auth/bind-email';

  static String get alipayCreateOrderUrl =>
      '$currentBackendUrl/api/alipay/create-order';
  static String get alipayQueryOrderUrl =>
      '$currentBackendUrl/api/alipay/query-order';
  static String get alipayMembershipStatusUrl =>
      '$currentBackendUrl/api/alipay/check-membership';

  static String get stripeMembershipStatusUrl =>
      '$currentBackendUrl/api/stripe/membership-status';
  static String get stripeCreateSubscriptionUrl =>
      '$currentBackendUrl/api/stripe/create-subscription';
  static String get stripeSessionStatusUrl =>
      '$currentBackendUrl/api/stripe/session-status';

  static String get appleVerifyReceiptUrl =>
      '$currentBackendUrl/api/apple/verify-receipt';

  static String get adminCheckStatusUrl =>
      '$currentBackendUrl/api/admin/check-status';
  static String get adminCreateRedeemCodeUrl =>
      '$currentBackendUrl/api/admin/create-redeem-code';
  static String get adminRedeemCodesUrl =>
      '$currentBackendUrl/api/admin/redeem-codes';
  static String get adminUseRedeemCodeUrl =>
      '$currentBackendUrl/api/admin/use-redeem-code';
  static String get adminPurchaseHistoryUrl =>
      '$currentBackendUrl/api/admin/purchase-history';
  static String get adminRedeemHistoryUrl =>
      '$currentBackendUrl/api/admin/redeem-history';

  static String get leaderboardUrl => '$currentBackendUrl/api/leaderboard';
  static String get updateTransferDataUrl =>
      '$currentBackendUrl/api/leaderboard/update';

  static String get healthCheckUrl => '$currentBackendUrl/health';

  // iOS 后台保活静音音频
  static String get silenceAudioUrl =>
      '$currentBackendUrl/static/audio/silence.mp3';

  // 3D 佛像模型配置
  // 如果 R2 上需要切换到新的对象键，优先改这里，便于强制绕开旧缓存。
  static const String buddhaModelAssetPath = 'models/buddha_model.model';
  // 当前线上正确模型明显大于 48MB，小于该阈值视为误传/降质文件。
  static const int minBuddhaModelSizeBytes = 100 * 1024 * 1024;

  // 请求头
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'FabushiApp/${isWeb ? "Web" : "Mobile"}',
  };

  // 错误消息
  static const Map<String, String> errorMessages = {
    'network_error': '网络连接失败，请检查网络设置',
    'server_error': '服务器错误，请稍后重试',
    'timeout_error': '请求超时，请检查网络连接',
    'auth_error': '认证失败，请重新登录',
    'permission_error': '权限不足',
    'validation_error': '数据验证失败',
    'unknown_error': '未知错误，请联系客服',
  };

  // 备用地址
  static List<String> get fallbackUrls {
    return [primaryBackendUrl];
  }

  // 调试配置
  static const bool enableApiLogging = true;
  static const bool debugMode = bool.fromEnvironment(
    'DEBUG',
    defaultValue: false,
  );

  static void printConfigInfo() {
    if (kDebugMode) {
      print('=== 应用配置 ===');
      print('环境: ${isProduction ? "生产" : "开发"}');
      print('平台: ${isWeb ? "Web" : "Native"}');
      print('API URL: $currentBackendUrl');
      print('================');
    }
  }

  static void printCurrentConfig() => printConfigInfo();
}
