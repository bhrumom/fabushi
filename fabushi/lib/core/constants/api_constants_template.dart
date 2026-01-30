/// API常量定义
class ApiConstants {
  ApiConstants._();

  // 认证相关
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout = '/api/auth/logout';
  static const String refreshToken = '/api/auth/refresh';
  static const String sendVerificationCode = '/api/auth/send-verification-code';
  static const String verifyEmail = '/api/auth/verify-email';
  static const String resetPassword = '/api/auth/reset-password';
  static const String changePassword = '/api/auth/change-password';

  // 用户相关
  static const String userProfile = '/api/user/profile';
  static const String updateProfile = '/api/user/update';
  static const String deleteAccount = '/api/user/delete';

  // 会员相关
  static const String membershipStatus = '/api/membership/status';
  static const String membershipPlans = '/api/membership/plans';
  static const String subscribe = '/api/membership/subscribe';
  static const String cancelSubscription = '/api/membership/cancel';
  static const String redeemCode = '/api/redeem/use';
  static const String generateCode = '/api/redeem/generate';

  // 支付相关
  static const String createPayment = '/api/payment/create';
  static const String verifyPayment = '/api/payment/verify';
  static const String paymentHistory = '/api/payment/history';
  static const String alipayAuth = '/api/alipay/auth';
  static const String alipayCallback = '/api/alipay/callback';

  // 传输相关
  static const String startTransfer = '/api/transfer/start';
  static const String stopTransfer = '/api/transfer/stop';
  static const String transferStatus = '/api/transfer/status';
  static const String transferHistory = '/api/transfer/history';
  static const String transferStats = '/api/transfer/stats';

  // 排行榜相关
  static const String leaderboard = '/api/leaderboard';
  static const String userRank = '/api/leaderboard/user';
  static const String topUsers = '/api/leaderboard/top';

  // 内容相关
  static const String dharmaContent = '/api/dharma/content';
  static const String searchContent = '/api/dharma/search';
  static const String contentDetail = '/api/dharma/detail';
  static const String downloadContent = '/api/dharma/download';

  // 视频流相关
  static const String videoFeed = '/api/video/feed';
  static const String videoDetail = '/api/video/detail';
  static const String videoLike = '/api/video/like';
  static const String videoComment = '/api/video/comment';

  // 服务器配置
  static const String serverConfig = '/api/config/servers';
  static const String countryServers = '/api/config/countries';

  // HTTP Headers
  static const String headerContentType = 'Content-Type';
  static const String headerAuthorization = 'Authorization';
  static const String headerAccept = 'Accept';
  static const String headerUserAgent = 'User-Agent';

  // Content Types
  static const String contentTypeJson = 'application/json';
  static const String contentTypeFormData = 'multipart/form-data';
  static const String contentTypeUrlEncoded = 'application/x-www-form-urlencoded';

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // 重试配置
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
