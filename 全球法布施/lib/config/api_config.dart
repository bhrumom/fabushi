class ApiConfig {
  // 环境检测
  static bool get isProduction {
    // 通过 --dart-define=ENVIRONMENT=... 在构建时注入环境
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    return environment == 'production';
  }
  
  static bool get isDevelopment => !isProduction;
  
  // 基础URL - 根据环境自动选择
  static String get baseUrl {
    if (isProduction) {
      // 生产环境地址
      return 'https://fabushi-flutter-web-prod.bhrumom.workers.dev';
    } else {
      // 开发环境地址
      return 'https://fabushi-flutter-web-dev.bhrumom.workers.dev';
    }
  }
  
  // 本地开发URL
  static String get localUrl => 'http://localhost:8787';
  
  // 当前使用的URL（优先使用本地开发服务器）
  static String get currentUrl {
    // 直接根据构建环境决定URL，不再强制使用localhost
    return baseUrl;
  }
  
  // 认证相关API
  static String get loginUrl => '${currentUrl}/api/auth/login';
  static String get registerUrl => '${currentUrl}/api/auth/register';
  static String get verifyUrl => '${currentUrl}/api/auth/verify';
  static String get logoutUrl => '${currentUrl}/api/auth/logout';
  static String get sendVerificationCodeUrl => '${currentUrl}/api/auth/send-verification-code';
  static String get verifyCodeUrl => '${currentUrl}/api/auth/verify-code';
  static String get forgotPasswordUrl => '${currentUrl}/api/auth/forgot-password';
  static String get resetPasswordUrl => '${currentUrl}/api/auth/reset-password';
  
  // 用户相关API
  static String get userInfoUrl => '${currentUrl}/api/auth/user-info';
  static String get bindEmailUrl => '${currentUrl}/api/auth/bind-email';
  
  // 微信登录相关API
  static String get wechatLoginUrlApi => '${currentUrl}/api/auth/wechat/login-url';
  static String get wechatLoginUrl => '${currentUrl}/api/auth/wechat/login';
  static String get wechatBindUrl => '${currentUrl}/api/auth/wechat/bind';
  static String get wechatRegisterUrl => '${currentUrl}/api/auth/wechat/register';
  static String get wechatUnbindUrl => '${currentUrl}/api/auth/wechat/unbind';
  
  // 支付宝相关API
  static String get alipayCreateOrderUrl => '${currentUrl}/api/alipay/create-order';
  static String get alipayQueryOrderUrl => '${currentUrl}/api/alipay/query-order';
  static String get alipayNotifyUrl => '${currentUrl}/api/alipay/notify';
  static String get alipayMembershipStatusUrl => '${currentUrl}/api/alipay/check-membership';
  
  // Stripe相关API
  static String get stripeMembershipStatusUrl => '${currentUrl}/api/stripe/membership-status';
  static String get stripeCreateSubscriptionUrl => '${currentUrl}/api/stripe/create-subscription';
  static String get stripeCancelSubscriptionUrl => '${currentUrl}/api/stripe/cancel-subscription';
  static String get stripeWebhookUrl => '${currentUrl}/api/stripe/webhook';
  
  // 管理员相关API
  static String get adminCheckStatusUrl => '${currentUrl}/api/admin/check-status';
  static String get adminCreateRedeemCodeUrl => '${currentUrl}/api/admin/create-redeem-code';
  static String get adminRedeemCodesUrl => '${currentUrl}/api/admin/redeem-codes';
  static String get adminUseRedeemCodeUrl => '${currentUrl}/api/admin/use-redeem-code';
  static String get adminDeleteRedeemCodeUrl => '${currentUrl}/api/admin/delete-redeem-code';
  static String get adminGetPriceUrl => '${currentUrl}/api/admin/get-price';
  static String get adminPurchaseHistoryUrl => '${currentUrl}/api/admin/purchase-history';
  static String get adminRedeemHistoryUrl => '${currentUrl}/api/admin/redeem-history';
  
  // 文件上传相关API
  static String get r2ListUrl => '${currentUrl}/r2?list=true';
  
  // 请求头配置
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // 超时配置
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
  
  // 存储键名
  static const String tokenStorageKey = 'auth_token';
  static const String userInfoStorageKey = 'user_info';
  
  // 调试和日志配置
  static const bool enableApiLogging = true;
  
  // 重试配置
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // 错误消息配置
  static const Map<String, String> errorMessages = {
    'network_error': '网络连接失败，请检查网络设置',
    'server_error': '服务器错误，请稍后重试',
    'timeout_error': '请求超时，请检查网络连接',
    'auth_error': '认证失败，请重新登录',
    'permission_error': '权限不足',
    'validation_error': '数据验证失败',
    'unknown_error': '未知错误，请联系客服',
  };
  
  // 调试信息
  static void printCurrentConfig() {
    print('=== API配置信息 ===');
    print('当前环境: ${isProduction ? "生产环境" : "开发环境"}');
    print('基础URL: $baseUrl');
    print('当前URL: $currentUrl');
    print('本地URL: $localUrl');
    print('启用日志: $enableApiLogging');
    print('最大重试次数: $maxRetries');
    print('================');
  }
}