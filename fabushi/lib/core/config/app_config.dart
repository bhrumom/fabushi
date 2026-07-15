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
  static const String configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String primaryBackendUrl = 'https://api.ombhrum.com';
  static const String cloudflareWorkerProdUrl = 'https://api.ombhrum.com';
  static const String cloudflareWorkerDevUrl =
      'https://fabushi-flutter-web-dev.bhrumom.workers.dev';
  static const String localDevUrl = 'http://localhost:8787';
  static const String publicWebUrl = 'https://flutter.ombhrum.com';
  static const String configuredAiBackendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: '',
  );
  static const String defaultAiBackendUrl = primaryBackendUrl;
  static const String configuredDachengAiWebUrl = String.fromEnvironment(
    'DACHENG_AI_WEB_URL',
    defaultValue: '',
  );
  static const bool desktopControlEnabled = bool.fromEnvironment(
    'DACHENG_DESKTOP_CONTROL',
    defaultValue: false,
  );
  static const String configuredOpenClawDeepSeekApiKey = String.fromEnvironment(
    'DACHENG_OPENCLAW_DEEPSEEK_API_KEY',
    defaultValue: '',
  );
  static const String defaultDachengAiWebUrl =
      'https://fabushi.ombhrum.com/app/ai';

  static String get currentBackendUrl {
    if (configuredApiBaseUrl.isNotEmpty) {
      return configuredApiBaseUrl;
    }
    if (kIsWeb) {
      final currentUrl = Uri.base;
      final host = currentUrl.host;
      if (host.contains('localhost')) {
        return localDevUrl;
      }
      if (host.contains('fabushi-flutter-web-dev')) {
        return cloudflareWorkerDevUrl;
      }
      if (host.contains('fabushi-flutter-web-prod')) {
        return cloudflareWorkerProdUrl;
      }
    }
    return primaryBackendUrl;
  }

  static String get apiUrl => currentBackendUrl;

  static String get currentAiBackendUrl {
    if (configuredAiBackendUrl.isNotEmpty) {
      return configuredAiBackendUrl;
    }
    return defaultAiBackendUrl;
  }

  static String get dachengAiWebUrl {
    if (configuredDachengAiWebUrl.isNotEmpty) {
      return configuredDachengAiWebUrl;
    }
    return defaultDachengAiWebUrl;
  }

  static String get openClawDeepSeekProxyBaseUrl {
    final baseUrl = currentAiBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    return '$baseUrl/api/openclaw/deepseek/v1';
  }

  /// OpenAI Responses-compatible endpoint consumed by the Mahayana Rust SDK.
  static String get codexDeepSeekResponsesBaseUrl {
    final baseUrl = currentAiBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    return '$baseUrl/codex-deepseek/v1';
  }

  static Uri buildDachengAiWebUri({
    String? prompt,
    String? bookTitle,
    String? context,
  }) {
    final base = Uri.parse(dachengAiWebUrl);
    final query = <String, String>{
      ...base.queryParameters,
      if (prompt != null && prompt.trim().isNotEmpty) 'prompt': prompt.trim(),
      if (bookTitle != null && bookTitle.trim().isNotEmpty)
        'book': bookTitle.trim(),
      if (context != null && context.trim().isNotEmpty)
        'context': context.trim(),
    };
    return base.replace(queryParameters: query.isEmpty ? null : query);
  }

  /// 大厂式 API 网关入口：客户端只允许构造自家后端的相对路径。
  ///
  /// 第三方 API、上游 API、缓存、重试、fallback 都应在后端处理；
  /// App 端不得直接传入 https://... 或 http://... 这类绝对 URL。
  static Uri buildBackendUri(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedEndpoint = endpoint.trim();
    if (normalizedEndpoint.isEmpty || !normalizedEndpoint.startsWith('/')) {
      throw ArgumentError(
        'API endpoint must be a first-party relative path starting with /: $endpoint',
      );
    }
    if (normalizedEndpoint.startsWith('//') ||
        normalizedEndpoint.contains('://')) {
      throw ArgumentError(
        'API endpoint must not be an absolute or protocol-relative URL: $endpoint',
      );
    }

    final baseUrl = currentBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl$normalizedEndpoint');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  static String buildBackendUrl(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) {
    return buildBackendUri(
      endpoint,
      queryParameters: queryParameters,
    ).toString();
  }

  // 应用信息
  static const String appName = '大乘';
  // 保持与 pubspec.yaml 中的 version 同步，供 Web 回退和服务端比对使用。
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 400;

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
  static String get loginUrl => buildBackendUrl('/api/auth/login');
  static String get registerUrl => buildBackendUrl('/api/auth/register');
  static String get verifyUrl => buildBackendUrl('/api/auth/verify');
  static String get logoutUrl => buildBackendUrl('/api/auth/logout');
  static String get deleteAccountUrl => buildBackendUrl('/api/auth/delete');
  static String get sendVerificationCodeUrl =>
      buildBackendUrl('/api/auth/send-verification-code');
  static String get verifyCodeUrl => buildBackendUrl('/api/auth/verify-code');
  static String get forgotPasswordUrl =>
      buildBackendUrl('/api/auth/forgot-password');
  static String get resetPasswordUrl =>
      buildBackendUrl('/api/auth/reset-password');
  static String get userInfoUrl => buildBackendUrl('/api/auth/user-info');
  static String get bindEmailUrl => buildBackendUrl('/api/auth/bind-email');
  static String get appVersionPolicyUrl =>
      buildBackendUrl('/api/app/version-policy');

  static String get agentChatUrl => buildBackendUrl('/api/agent/chat');
  static String get aiQuotaUrl => buildBackendUrl('/api/ai/quota');
  static String agentRunEventsUrl(String runId) =>
      buildBackendUrl('/api/agent/runs/$runId/events');
  static String agentRunCancelUrl(String runId) =>
      buildBackendUrl('/api/agent/runs/$runId/cancel');
  static String agentMessageFeedbackUrl(String messageId) =>
      buildBackendUrl('/api/agent/messages/$messageId/feedback');

  static String get alipayCreateOrderUrl =>
      buildBackendUrl('/api/alipay/create-order');
  static String get alipayQueryOrderUrl =>
      buildBackendUrl('/api/alipay/query-order');
  static String get alipayMembershipStatusUrl =>
      buildBackendUrl('/api/alipay/check-membership');

  static String get stripeMembershipStatusUrl =>
      buildBackendUrl('/api/stripe/membership-status');
  static String get stripeCreateSubscriptionUrl =>
      buildBackendUrl('/api/stripe/create-subscription');
  static String get stripeSessionStatusUrl =>
      buildBackendUrl('/api/stripe/session-status');

  static String get appleVerifyReceiptUrl =>
      buildBackendUrl('/api/apple/verify-receipt');
  static String get purchaseEntitlementUrl =>
      buildBackendUrl('/api/purchases/entitlement');
  static String get walletBalanceUrl => buildBackendUrl('/api/wallet/balance');
  static String get walletSpendUrl => buildBackendUrl('/api/wallet/spend');

  static const String zenBuddhaAssetProductId = 'zen_buddha_asset';
  static const String zenBuddhaAssetDisplayName = '3D佛像素材';
  static const String zenBuddhaAssetPriceLabel = '¥33.00';
  static const int zenBuddhaAssetFudeGoldPrice = 33;
  static const String zenBuddhaAssetCardImagePath =
      'assets/images/zen_buddha_material_card.png';

  static String get adminCheckStatusUrl =>
      buildBackendUrl('/api/admin/check-status');
  static String get adminCreateRedeemCodeUrl =>
      buildBackendUrl('/api/admin/create-redeem-code');
  static String get adminRedeemCodesUrl =>
      buildBackendUrl('/api/admin/redeem-codes');
  static String get adminUseRedeemCodeUrl =>
      buildBackendUrl('/api/admin/use-redeem-code');
  static String get adminPurchaseHistoryUrl =>
      buildBackendUrl('/api/admin/purchase-history');
  static String get adminRedeemHistoryUrl =>
      buildBackendUrl('/api/admin/redeem-history');

  static String get leaderboardUrl => buildBackendUrl('/api/leaderboard');
  static String get updateTransferDataUrl =>
      buildBackendUrl('/api/leaderboard/update');

  static String get healthCheckUrl => buildBackendUrl('/health');

  // 3D 佛像模型配置
  // 如果 R2 上需要切换到新的对象键，优先改这里，便于强制绕开旧缓存。
  static const String buddhaModelAssetPath = 'models/buddha_model.model';
  // Android/iOS both use the R2 flutter_scene .model; local cache misses
  // download through AssetLoaderService.

  // 当前线上正确模型明显大于 100MB，小于该阈值视为误传/降质文件。
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
