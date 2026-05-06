class AppConstants {
  AppConstants._();

  // 应用信息
  static const String appName = '大乘';
  static const String appVersion = '1.0.0+16';

  // 支持的国家代码
  static const List<String> supportedCountries = [
    'ALL',
    'US',
    'CN',
    'IN',
    'ID',
    'BR',
    'PK',
    'NG',
    'BD',
    'RU',
    'MX',
    'JP',
    'ET',
    'PH',
    'EG',
    'VN',
    'CD',
    'TR',
    'IR',
    'DE',
    'TH',
    'GB',
    'FR',
    'IT',
    'ZA',
    'TZ',
    'MM',
    'KE',
    'KR',
    'CO',
  ];

  // 会员类型
  static const String membershipTrial = 'trial';
  static const String membershipPaid = 'paid';
  static const String membershipExpired = 'expired';

  // 传输状态
  static const String transferPending = 'pending';
  static const String transferInProgress = 'in_progress';
  static const String transferCompleted = 'completed';
  static const String transferFailed = 'failed';
}
