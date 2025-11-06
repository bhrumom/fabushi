/// API常量定义
class ApiConstants {
  ApiConstants._();

  // 认证相关
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout = '/api/auth/logout';
  static const String sendVerificationCode = '/api/auth/send-verification-code';
  static const String verifyEmail = '/api/auth/verify';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String userInfo = '/api/auth/user-info';

  // 会员相关
  static const String membershipStatus = '/api/membership/status';
  static const String redeemCode = '/api/admin/use-redeem-code';

  // 支付相关
  static const String alipayCreateOrder = '/api/alipay/create-order';
  static const String stripeCreateSubscription = '/api/stripe/create-subscription';

  // 传输相关
  static const String globalSend = '/send-global';
  static const String updateTransferData = '/api/leaderboard/update';

  // 排行榜相关
  static const String leaderboard = '/api/leaderboard';

  // 内容相关
  static const String r2List = '/r2?list=true';

  // HTTP Headers
  static const String headerContentType = 'Content-Type';
  static const String headerAuthorization = 'Authorization';
  static const String headerAccept = 'Accept';

  // Content Types
  static const String contentTypeJson = 'application/json';
}
