// Flutter应用API配置
// 配置Cloudflare Worker后端的API端点

class ApiConfig {
  // 基础URL - 请替换为你的Cloudflare Worker域名
  static const String baseUrl = 'https://fabushi-prod.你的账户名.workers.dev';
  
  // 如果使用自定义域名，请替换为:
  // static const String baseUrl = 'https://api.ombhrum.com';
  
  // 认证相关API端点
  static const String loginUrl = '$baseUrl/api/auth/login';
  static const String registerUrl = '$baseUrl/api/auth/register';
  static const String verifyUrl = '$baseUrl/api/auth/verify';
  static const String logoutUrl = '$baseUrl/api/auth/logout';
  static const String sendVerificationCodeUrl = '$baseUrl/api/auth/send-verification-code';
  static const String verifyCodeUrl = '$baseUrl/api/auth/verify-code';
  static const String forgotPasswordUrl = '$baseUrl/api/auth/forgot-password';
  static const String resetPasswordUrl = '$baseUrl/api/auth/reset-password';
  
  // 用户信息API
  static const String userInfoUrl = '$baseUrl/api/auth/user-info';
  static const String bindEmailUrl = '$baseUrl/api/auth/bind-email';
  
  // 微信登录API端点
  static const String wechatLoginUrlApi = '$baseUrl/api/auth/wechat/login-url';
  static const String wechatLoginUrl = '$baseUrl/api/auth/wechat/login';
  static const String wechatBindUrl = '$baseUrl/api/auth/wechat/bind';
  static const String wechatRegisterUrl = '$baseUrl/api/auth/wechat/register';
  static const String wechatUnbindUrl = '$baseUrl/api/auth/wechat/unbind';
  
  // 支付宝支付API端点
  static const String alipayCreateOrderUrl = '$baseUrl/api/alipay/create-order';
  static const String alipayQueryOrderUrl = '$baseUrl/api/alipay/query-order';
  static const String alipayNotifyUrl = '$baseUrl/api/alipay/notify';
  static const String alipayMembershipStatusUrl = '$baseUrl/api/alipay/check-membership';
  
  // Stripe支付API端点
  static const String stripeMembershipStatusUrl = '$baseUrl/api/stripe/membership-status';
  static const String stripeCreateSubscriptionUrl = '$baseUrl/api/stripe/create-subscription';
  static const String stripeCancelSubscriptionUrl = '$baseUrl/api/stripe/cancel-subscription';
  static const String stripeWebhookUrl = '$baseUrl/api/stripe/webhook';
  
  // 管理员系统API端点
  static const String adminCheckStatusUrl = '$baseUrl/api/admin/check-status';
  static const String adminCreateRedeemCodeUrl = '$baseUrl/api/admin/create-redeem-code';
  static const String adminRedeemCodesUrl = '$baseUrl/api/admin/redeem-codes';
  static const String adminUseRedeemCodeUrl = '$baseUrl/api/admin/use-redeem-code';
  static const String adminDeleteRedeemCodeUrl = '$baseUrl/api/admin/delete-redeem-code';
  static const String adminGetPriceUrl = '$baseUrl/api/admin/get-price';
  static const String adminPurchaseHistoryUrl = '$baseUrl/api/admin/purchase-history';
  static const String adminRedeemHistoryUrl = '$baseUrl/api/admin/redeem-history';
  
  // R2文件存储API
  static const String r2ListUrl = '$baseUrl/r2?list=true';
  static String r2FileUrl(String fileName) => '$baseUrl/r2?file=$fileName';
  
  // 请求超时配置
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  // 重试配置
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // 验证码配置
  static const int verificationCodeLength = 6;
  static const Duration verificationCodeExpiry = Duration(minutes: 10);
  static const Duration verificationCodeCooldown = Duration(seconds: 60);
  
  // 会员配置
  static const List<String> membershipPlans = ['monthly', 'quarterly', 'yearly'];
  static const Map<String, String> membershipPlanNames = {
    'monthly': '月度会员',
    'quarterly': '季度会员',
    'yearly': '年度会员',
  };
  
  // 兑换码类型
  static const Map<String, String> redeemCodeTypes = {
    'trial_7': '7天试用',
    'monthly': '月度会员',
    'quarterly': '季度会员',
    'yearly': '年度会员',
  };
  
  // 错误消息
  static const Map<String, String> errorMessages = {
    'network_error': '网络连接失败，请检查网络设置',
    'timeout_error': '请求超时，请重试',
    'server_error': '服务器错误，请稍后重试',
    'auth_error': '认证失败，请重新登录',
    'permission_error': '权限不足',
    'validation_error': '输入数据格式错误',
    'not_found_error': '请求的资源不存在',
  };
  
  // 开发模式配置
  static const bool isDevelopment = bool.fromEnvironment('dart.vm.product') == false;
  
  // 日志配置
  static const bool enableApiLogging = isDevelopment;
  static const bool enableErrorReporting = !isDevelopment;
  
  // 缓存配置
  static const Duration tokenCacheExpiry = Duration(days: 7);
  static const Duration userInfoCacheExpiry = Duration(hours: 1);
  static const Duration membershipStatusCacheExpiry = Duration(minutes: 30);
  
  // 安全配置
  static const String tokenStorageKey = 'auth_token';
  static const String userInfoStorageKey = 'user_info';
  static const String membershipStatusStorageKey = 'membership_status';
  
  // 获取完整的API URL
  static String getApiUrl(String endpoint) {
    if (endpoint.startsWith('http')) {
      return endpoint;
    }
    return '$baseUrl$endpoint';
  }
  
  // 获取带参数的URL
  static String getUrlWithParams(String url, Map<String, dynamic> params) {
    if (params.isEmpty) return url;
    
    final uri = Uri.parse(url);
    final newUri = uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...params.map((key, value) => MapEntry(key, value.toString())),
    });
    
    return newUri.toString();
  }
  
  // 验证URL是否有效
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  // 获取环境特定的配置
  static Map<String, dynamic> getEnvironmentConfig() {
    return {
      'isDevelopment': isDevelopment,
      'baseUrl': baseUrl,
      'enableLogging': enableApiLogging,
      'enableErrorReporting': enableErrorReporting,
      'requestTimeout': requestTimeout.inMilliseconds,
      'maxRetries': maxRetries,
    };
  }
}