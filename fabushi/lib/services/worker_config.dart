/// Cloudflare Worker 配置
class WorkerConfig {
  // API 端点配置
  static const Map<String, String> apiEndpoints = {
    // 认证相关
    'login': '/api/auth/login',
    'register': '/api/auth/register',
    'verify': '/api/auth/verify',
    'logout': '/api/auth/logout',
    'sendVerificationCode': '/api/auth/send-verification-code',
    'verifyCode': '/api/auth/verify-code',
    'forgotPassword': '/api/auth/forgot-password',
    'resetPassword': '/api/auth/reset-password',
    'userInfo': '/api/auth/user-info',
    'bindEmail': '/api/auth/bind-email',

    // 微信登录相关
    'wechatLoginUrl': '/api/auth/wechat/login-url',
    'wechatLogin': '/api/auth/wechat/login',
    'wechatBind': '/api/auth/wechat/bind',
    'wechatRegister': '/api/auth/wechat/register',
    'wechatUnbind': '/api/auth/wechat/unbind',

    // 支付宝登录相关
    'alipayLoginUrl': '/api/auth/alipay/login-url',
    'alipayLogin': '/api/auth/alipay/login',
    'alipayBind': '/api/auth/alipay/bind',
    'alipayRegister': '/api/auth/alipay/register',
    'alipayUnbind': '/api/auth/alipay/unbind',

    // Stripe 支付相关
    'membershipStatus': '/api/stripe/membership-status',
    'createSubscription': '/api/stripe/create-subscription',
    'cancelSubscription': '/api/stripe/cancel-subscription',
    'stripeWebhook': '/api/stripe/webhook',

    // 支付宝相关
    'alipayCreateOrder': '/api/alipay/create-order',
    'alipayQueryOrder': '/api/alipay/query-order',
    'alipayNotify': '/api/alipay/notify',
    'alipayMembershipStatus': '/api/alipay/check-membership',

    // 用户反馈
    'submitFeedback': '/api/feedback',

    // 管理员相关
    'adminCheckStatus': '/api/admin/check-status',
    'adminCreateRedeemCode': '/api/admin/create-redeem-code',
    'adminListRedeemCodes': '/api/admin/redeem-codes',
    'adminUseRedeemCode': '/api/admin/use-redeem-code',
    'adminDeleteRedeemCode': '/api/admin/delete-redeem-code',
    'adminGetPrice': '/api/admin/get-price',
    'adminPurchaseHistory': '/api/admin/purchase-history',
    'adminRedeemHistory': '/api/admin/redeem-history',
  };

  // 会员计划配置
  static const Map<String, Map<String, dynamic>> membershipPlans = {
    'monthly': {
      'name': '月度会员',
      'duration': 30,
      'price': '21.00',
      'adminPrice': '0.01',
      'features': ['基础功能访问', '每日10次使用额度', '邮件支持'],
    },
    'quarterly': {
      'name': '季度会员',
      'duration': 90,
      'price': '63.00',
      'adminPrice': '0.01',
      'features': ['基础功能访问', '每日30次使用额度', '邮件支持', '优先客服'],
    },
    'yearly': {
      'name': '年度会员',
      'duration': 365,
      'price': '252.00',
      'adminPrice': '0.01',
      'features': ['基础功能访问', '每日100次使用额度', '邮件支持', '优先客服', '专属功能'],
    },
  };

  // 兑换码类型配置
  static const Map<String, Map<String, dynamic>> redeemCodeTypes = {
    'trial_7': {'name': '7天试用', 'days': 7, 'type': 'trial'},
    'monthly': {'name': '月度会员', 'days': 30, 'type': 'premium'},
    'quarterly': {'name': '季度会员', 'days': 90, 'type': 'premium'},
    'yearly': {'name': '年度会员', 'days': 365, 'type': 'premium'},
  };

  // 错误消息映射
  static const Map<String, String> errorMessages = {
    'NETWORK_ERROR': '网络连接失败，请检查网络设置',
    'INVALID_TOKEN': '登录已过期，请重新登录',
    'UNAUTHORIZED': '权限不足',
    'VALIDATION_ERROR': '输入数据格式错误',
    'SERVER_ERROR': '服务器内部错误',
    'RATE_LIMIT': '请求过于频繁，请稍后再试',
  };

  // 获取 API 端点
  static String getEndpoint(String key) {
    return apiEndpoints[key] ?? '';
  }

  // 获取会员计划信息
  static Map<String, dynamic>? getMembershipPlan(String planKey) {
    return membershipPlans[planKey];
  }

  // 获取兑换码类型信息
  static Map<String, dynamic>? getRedeemCodeType(String typeKey) {
    return redeemCodeTypes[typeKey];
  }

  // 获取错误消息
  static String getErrorMessage(String errorKey, [String? defaultMessage]) {
    return errorMessages[errorKey] ?? defaultMessage ?? '未知错误';
  }

  // 验证邮箱格式
  static bool isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  // 验证用户名格式
  static bool isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  // 验证密码强度
  static Map<String, dynamic> validatePassword(String password) {
    final result = {'isValid': true, 'errors': <String>[]};

    if (password.length < 8) {
      result['isValid'] = false;
      (result['errors'] as List<String>).add('密码长度至少8个字符');
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      result['isValid'] = false;
      (result['errors'] as List<String>).add('密码必须包含大写字母');
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      result['isValid'] = false;
      (result['errors'] as List<String>).add('密码必须包含小写字母');
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      result['isValid'] = false;
      (result['errors'] as List<String>).add('密码必须包含数字');
    }

    return result;
  }
}
