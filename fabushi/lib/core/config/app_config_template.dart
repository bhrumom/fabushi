/// 应用配置
/// 统一管理所有配置项
class AppConfig {
  // 私有构造函数
  AppConfig._();

  // 单例
  static final AppConfig instance = AppConfig._();

  // 环境配置
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'production');

  // 是否为生产环境
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';

  // API配置
  static const String productionApiUrl = 'https://ombhrum.com';
  static const String stagingApiUrl = 'https://staging.ombhrum.com';
  static const String developmentApiUrl = 'http://localhost:8787';

  // 根据环境获取API URL
  static String get apiUrl {
    switch (environment) {
      case 'production':
        return productionApiUrl;
      case 'staging':
        return stagingApiUrl;
      case 'development':
        return developmentApiUrl;
      default:
        return productionApiUrl;
    }
  }

  // API端点
  static const String authEndpoint = '/api/auth';
  static const String membershipEndpoint = '/api/membership';
  static const String transferEndpoint = '/api/transfer';
  static const String leaderboardEndpoint = '/api/leaderboard';

  // 应用信息
  static const String appName = '全球法布施';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // 功能开关
  static const bool enableFirebaseAuth = true;
  static const bool enableAlipay = true;
  static const bool enableVideoFeed = true;
  static const bool enableDebugMode = !isProduction;

  // 传输配置
  static const int fileChunkSize = 1024;
  static const int maxRetryCount = 3;
  static const int timeoutDuration = 5000;
  static const int maxConcurrentTransfers = 5;

  // 缓存配置
  static const int cacheMaxAge = 7; // 天
  static const int maxCacheSize = 100; // MB

  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

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
    'ES',
    'UG',
    'AR',
    'DZ',
    'SD',
    'UA',
    'CA',
    'PL',
    'MA',
    'SA',
    'UZ',
    'PE',
    'AF',
    'MY',
    'AO',
    'MZ',
    'GH',
    'YE',
    'NP',
    'VE',
    'MG',
    'AU',
    'KP',
    'CM',
    'NE',
    'TW',
    'LK',
    'BF',
    'ML',
    'RO',
    'MW',
    'CL',
    'KZ',
    'ZM',
    'GT',
    'EC',
    'SY',
    'NL',
    'SN',
    'KH',
    'TD',
    'SO',
    'ZW',
    'GN',
    'RW',
    'BJ',
    'TN',
    'BI',
    'BO',
    'HT',
    'BE',
    'CU',
    'SS',
    'DO',
    'CZ',
    'GR',
    'JO',
    'PT',
    'AZ',
    'SE',
    'HN',
    'HU',
    'TJ',
    'AE',
    'BY',
    'IL',
    'TG',
    'AT',
    'RS',
    'PG',
    'CH',
    'SL',
    'HK',
    'LA',
    'LY',
    'BG',
    'KG',
    'NI',
    'ER',
    'TM',
    'SG',
    'DK',
    'FI',
    'CG',
    'SK',
    'NO',
    'OM',
    'PS',
    'CR',
    'LB',
    'NZ',
    'CF',
    'IE',
    'LR',
    'MR',
    'PA',
    'GE',
    'UY',
    'BA',
    'MN',
    'AM',
    'JM',
    'QA',
    'AL',
    'PR',
    'LT',
    'NA',
    'GM',
    'BW',
    'GA',
    'SI',
    'GW',
    'HR',
    'MK',
    'LS',
    'KW',
    'XK',
    'TT',
    'EE',
    'MU',
    'SZ',
    'DJ',
    'FJ',
    'RE',
    'CY',
    'BH',
    'KM',
    'GQ',
    'BT',
    'ME',
    'SB',
    'MO',
    'LU',
    'SR',
    'CV',
    'MV',
    'MT',
    'BN',
    'BZ',
    'IS',
    'BB',
    'BS',
    'PF',
    'VU',
    'NC',
    'GY',
    'ST',
    'WS',
    'LC',
    'GD',
    'TO',
    'VC',
    'KI',
    'MH',
    'FM',
    'PW',
    'NR',
    'TV',
  ];

  // 日志配置
  static const bool enableLogging = true;
  static const bool enableNetworkLogging = !isProduction;
  static const bool enablePerformanceLogging = !isProduction;
}
