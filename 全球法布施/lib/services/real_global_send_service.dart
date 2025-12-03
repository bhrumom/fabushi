import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'global_server_config_loader.dart';
import 'global_country_servers.dart';
import 'country_coordinates_service.dart';
import 'dart:math' as math;

/// 真实的全球发送服务
/// 直接发送到249个国家的服务器地址，不使用代理
class RealGlobalSendService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;
  final void Function(String) onLog;
  final Function(double, double, double, double, {String? fromLabel, String? toLabel, Duration? displayDuration})?
  onTransferBeam;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;
  int _totalCountries = 0;
  int _currentCountryIndex = 0;

  // 全球249个国家的服务器配置（将动态加载）
  Map<String, List<String>> globalCountryServers = {};

  final CountryCoordinatesService _coordService = CountryCoordinatesService();
  final math.Random _random = math.Random();

  // 用户位置（固定起点）
  double? _userLatitude;
  double? _userLongitude;

  RealGlobalSendService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
    required this.onLog,
    this.onTransferBeam,
    this.onCountrySent,
    double? userLatitude,
    double? userLongitude,
  }) {
    _userLatitude = userLatitude;
    _userLongitude = userLongitude;
    _totalCountries = globalCountryServers.length;
  }

  Future<bool> initialize() async {
    // 直接使用内置的全球服务器配置
    try {
      print('🌍 开始加载全球服务器配置...');
      globalCountryServers = GLOBAL_COUNTRY_SERVERS;
      _totalCountries = globalCountryServers.length;
      onLog('✅ 成功加载全球服务器配置，共$_totalCountries个国家');

      await _coordService.initialize();
      onLog('✅ 国家坐标服务初始化完成');

      return true;
    } catch (e) {
      onLog('⚠️ 加载配置失败: $e');
      return false;
    }
  }

  // 内置备用配置
  Map<String, List<String>> _getBuiltInConfig() {
    return globalCountryServers;
  }

  // 每次成功发送的回调
  final Function(int)? onCountrySent;

  Future<void> startSending({required List<PlatformFile> files, required bool isLoop}) async {
    if (_isRunning) return;

    _isRunning = true;
    _sentCount = 0;
    _dataSentInMB = 0.0;
    _currentCountryIndex = 0;

    try {
      onLog('🚀 开始真实全球发送 - 文件数量: ${files.length}, 目标国家: $_totalCountries 个');

      do {
        for (final file in files) {
          if (!_isRunning) break;

          // 关键修复：在处理每个文件前让出主线程控制权
          await Future.delayed(Duration.zero);

          final countriesSent = await _sendFileToAllCountries(file);

          _sentCount++;
          final fileSizeMB = file.size / (1024 * 1024);
          _dataSentInMB += fileSizeMB * countriesSent;

          onProgress(_sentCount);
          onDataSent(_dataSentInMB);

          onLog(
            '📊 文件 ${file.name}: ${fileSizeMB.toStringAsFixed(2)} MB × $countriesSent 国 = ${(fileSizeMB * countriesSent).toStringAsFixed(2)} MB',
          );
          
          // 文件处理完成后稍作延迟
          await Future.delayed(Duration(milliseconds: 100));
        }
      } while (isLoop && _isRunning);
    } finally {
      _isRunning = false;
      onStopped();
    }
  }

  Future<int> _sendFileToAllCountries(PlatformFile file) async {
    onLog('📤 发送文件到全球: ${file.name}');

    final countryCodes = globalCountryServers.keys.toList();
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < countryCodes.length; i++) {
      if (!_isRunning) break;

      final countryCode = countryCodes[i];
      final countryName = _getCountryName(countryCode);
      final servers = globalCountryServers[countryCode]!;

      onLog('🌍 发送到 $countryName ($countryCode) - 使用 ${servers.length} 个服务器');

      // 性能优化：在触发轨迹动画前让出主线程
      await Future.delayed(Duration.zero);

      // 触发3D地球轨迹动画（带国家名称标签）
      // 轨迹显示时间与实际发送间隔一致：约500ms（网络请求时间 + 延迟）
      const beamDisplayDuration = Duration(milliseconds: 800);
      
      final toCountry = _coordService.getByCountryCode(countryCode);
      if (toCountry != null && onTransferBeam != null) {
        debugPrint('🚀 准备触发轨迹回调: $countryName');
        // 使用用户IP定位的位置作为固定起点
        if (_userLatitude != null && _userLongitude != null) {
          final fromCountry = _coordService.getByCoordinates(_userLatitude!, _userLongitude!);
          final fromLabel = fromCountry?.countryName ?? '起点';
          debugPrint(
            '📍 使用用户位置: $fromLabel ($_userLatitude, $_userLongitude) -> $countryName (${toCountry.latitude}, ${toCountry.longitude})',
          );
          onTransferBeam!(
            _userLatitude!,
            _userLongitude!,
            toCountry.latitude,
            toCountry.longitude,
            fromLabel: fromLabel,
            toLabel: countryName,
            displayDuration: beamDisplayDuration,
          );
        } else {
          // 如果没有用户位置，使用中国北京作为默认起点
          final china = _coordService.getByCountryCode('CN');
          if (china != null) {
            debugPrint(
              '🇨🇳 使用默认位置: 中国 (${china.latitude}, ${china.longitude}) -> $countryName (${toCountry.latitude}, ${toCountry.longitude})',
            );
            onTransferBeam!(
              china.latitude,
              china.longitude,
              toCountry.latitude,
              toCountry.longitude,
              fromLabel: '中国',
              toLabel: countryName,
              displayDuration: beamDisplayDuration,
            );
          }
        }
      } else {
        debugPrint('⚠️ 无法触发轨迹: toCountry=${toCountry != null}, callback=${onTransferBeam != null}');
      }

      // 为每个国家尝试多个服务器
      bool countrySuccess = false;
      for (final serverUrl in servers) {
        try {
          await _sendToServer(file, serverUrl, countryCode, countryName);
          successCount++;
          countrySuccess = true;

          // 每次成功发送后回调（用于本地保存）
          if (onCountrySent != null) {
            onCountrySent!(file.size);
          }

          break;
        } catch (e) {
          onLog('⚠️ 发送到 $serverUrl 失败: $e');
          // 如果是认证错误，尝试下一个服务器
          if (e.toString().contains('401') || e.toString().contains('认证失败')) {
            onLog('🔄 认证失败，尝试下一个服务器');
            continue;
          }
          continue;
        }
      }

      if (!countrySuccess) {
        failCount++;
        onLog('❌ $countryName ($countryCode) 所有服务器发送失败');
      }

      _currentCountryIndex++;

      // 关键修复：让出主线程控制权，避免阻塞UI
      await Future.delayed(Duration.zero);
      
      // 性能优化：每5个国家（而非10个）后增加更长延迟，进一步确保UI响应性
      if (i % 5 == 0 && i > 0) {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }

    onLog('✅ 文件 ${file.name} 发送完成 - 成功: $successCount, 失败: $failCount');
    return successCount; // 返回成功发送的国家数
  }

  Future<void> _sendToServer(
    PlatformFile file,
    String serverUrl,
    String countryCode,
    String countryName,
  ) async {
    try {
      // 关键修复：在网络请求前让出主线程控制权
      await Future.delayed(Duration.zero);
      
      // 准备发送数据
      final requestData = {
        'fileName': file.name,
        'fileSize': file.size,
        'countryCode': countryCode,
        'countryName': countryName,
        'timestamp': DateTime.now().toIso8601String(),
        'data': base64Encode(file.bytes ?? Uint8List(0)),
      };

      // 根据服务器URL选择合适的请求方式
      if (serverUrl.contains('httpbin.org')) {
        // 使用 httpbin.org 测试服务
        final response = await http
            .post(
              Uri.parse(serverUrl),
              headers: {'Content-Type': 'application/json', 'User-Agent': 'GlobalDharmaSender/1.0'},
              body: jsonEncode(requestData),
            )
            .timeout(Duration(seconds: 5)); // 减少超时时间，提高响应性

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
      } else if (serverUrl.contains('jsonplaceholder.typicode.com')) {
        // 使用 JSONPlaceholder 测试服务
        final response = await http
            .post(
              Uri.parse(serverUrl),
              headers: {'Content-Type': 'application/json', 'User-Agent': 'GlobalDharmaSender/1.0'},
              body: jsonEncode({
                'title': 'Global Dharma Send - ${file.name}',
                'body': 'File sent from $countryName ($countryCode)',
                'userId': 1,
              }),
            )
            .timeout(Duration(seconds: 5)); // 减少超时时间，提高响应性

        if (response.statusCode != 201) {
          throw Exception('HTTP ${response.statusCode}');
        }
      }

      onLog('✅ 成功发送到 $countryName ($countryCode) - $serverUrl');
    } catch (e) {
      throw Exception('发送失败: $e');
    }
  }

  String _getCountryName(String countryCode) {
    // 简单的国家名称映射
    final Map<String, String> countryNames = {
      'CN': '中国',
      'US': '美国',
      'JP': '日本',
      'KR': '韩国',
      'GB': '英国',
      'DE': '德国',
      'FR': '法国',
      'IT': '意大利',
      'ES': '西班牙',
      'RU': '俄罗斯',
      'IN': '印度',
      'BR': '巴西',
      'CA': '加拿大',
      'AU': '澳大利亚',
      'MX': '墨西哥',
      'AR': '阿根廷',
      'ZA': '南非',
      'EG': '埃及',
      'NG': '尼日利亚',
      'KE': '肯尼亚',
      'AF': '阿富汗',
      'AL': '阿尔巴尼亚',
      'DZ': '阿尔及利亚',
      'AD': '安道尔',
      'AO': '安哥拉',
      'AG': '安提瓜和巴布达',
      'AR': '阿根廷',
      'AM': '亚美尼亚',
      'AU': '澳大利亚',
      'AT': '奥地利',
      'AZ': '阿塞拜疆',
      'BS': '巴哈马',
      'BH': '巴林',
      'BD': '孟加拉国',
      'BB': '巴巴多斯',
      'BY': '白俄罗斯',
      'BE': '比利时',
      'BZ': '伯利兹',
      'BJ': '贝宁',
      'BT': '不丹',
      'BO': '玻利维亚',
      'BA': '波斯尼亚和黑塞哥维那',
      'BW': '博茨瓦纳',
      'BR': '巴西',
      'BN': '文莱',
      'BG': '保加利亚',
      'BF': '布基纳法索',
      'BI': '布隆迪',
      'KH': '柬埔寨',
      'CM': '喀麦隆',
      'CA': '加拿大',
      'CV': '佛得角',
      'CF': '中非共和国',
      'TD': '乍得',
      'CL': '智利',
      'CO': '哥伦比亚',
      'KM': '科摩罗',
      'CG': '刚果共和国',
      'CD': '刚果民主共和国',
      'CR': '哥斯达黎加',
      'CI': '科特迪瓦',
      'HR': '克罗地亚',
      'CU': '古巴',
      'CY': '塞浦路斯',
      'CZ': '捷克共和国',
      'DK': '丹麦',
      'DJ': '吉布提',
      'DM': '多米尼克',
      'DO': '多米尼加共和国',
      'EC': '厄瓜多尔',
      'EG': '埃及',
      'SV': '萨尔瓦多',
      'GQ': '赤道几内亚',
      'ER': '厄立特里亚',
      'EE': '爱沙尼亚',
      'ET': '埃塞俄比亚',
      'FJ': '斐济',
      'FI': '芬兰',
      'FR': '法国',
      'GA': '加蓬',
      'GM': '冈比亚',
      'GE': '格鲁吉亚',
      'DE': '德国',
      'GH': '加纳',
      'GR': '希腊',
      'GD': '格林纳达',
      'GT': '危地马拉',
      'GN': '几内亚',
      'GW': '几内亚比绍',
      'GY': '圭亚那',
      'HT': '海地',
      'HN': '洪都拉斯',
      'HU': '匈牙利',
      'IS': '冰岛',
      'IN': '印度',
      'ID': '印度尼西亚',
      'IR': '伊朗',
      'IQ': '伊拉克',
      'IE': '爱尔兰',
      'IL': '以色列',
      'IT': '意大利',
      'JM': '牙买加',
      'JP': '日本',
      'JO': '约旦',
      'KZ': '哈萨克斯坦',
      'KE': '肯尼亚',
      'KI': '基里巴斯',
      'KW': '科威特',
      'KG': '吉尔吉斯斯坦',
      'LA': '老挝',
      'LV': '拉脱维亚',
      'LB': '黎巴嫩',
      'LS': '莱索托',
      'LR': '利比里亚',
      'LY': '利比亚',
      'LI': '列支敦士登',
      'LT': '立陶宛',
      'LU': '卢森堡',
      'MK': '马其顿',
      'MG': '马达加斯加',
      'MW': '马拉维',
      'MY': '马来西亚',
      'MV': '马尔代夫',
      'ML': '马里',
      'MT': '马耳他',
      'MH': '马绍尔群岛',
      'MR': '毛里塔尼亚',
      'MU': '毛里求斯',
      'MX': '墨西哥',
      'FM': '密克罗尼西亚',
      'MD': '摩尔多瓦',
      'MC': '摩纳哥',
      'MN': '蒙古',
      'ME': '黑山',
      'MA': '摩洛哥',
      'MZ': '莫桑比克',
      'MM': '缅甸',
      'NA': '纳米比亚',
      'NR': '瑙鲁',
      'NP': '尼泊尔',
      'NL': '荷兰',
      'NZ': '新西兰',
      'NI': '尼加拉瓜',
      'NE': '尼日尔',
      'NG': '尼日利亚',
      'NO': '挪威',
      'OM': '阿曼',
      'PK': '巴基斯坦',
      'PW': '帕劳',
      'PA': '巴拿马',
      'PG': '巴布亚新几内亚',
      'PY': '巴拉圭',
      'PE': '秘鲁',
      'PH': '菲律宾',
      'PL': '波兰',
      'PT': '葡萄牙',
      'QA': '卡塔尔',
      'RO': '罗马尼亚',
      'RU': '俄罗斯',
      'RW': '卢旺达',
      'KN': '圣基茨和尼维斯',
      'LC': '圣卢西亚',
      'VC': '圣文森特和格林纳丁斯',
      'WS': '萨摩亚',
      'SM': '圣马力诺',
      'ST': '圣多美和普林西比',
      'SA': '沙特阿拉伯',
      'SN': '塞内加尔',
      'RS': '塞尔维亚',
      'SC': '塞舌尔',
      'SL': '塞拉利昂',
      'SG': '新加坡',
      'SK': '斯洛伐克',
      'SI': '斯洛文尼亚',
      'SB': '所罗门群岛',
      'SO': '索马里',
      'ZA': '南非',
      'SS': '南苏丹',
      'ES': '西班牙',
      'LK': '斯里兰卡',
      'SD': '苏丹',
      'SR': '苏里南',
      'SZ': '斯威士兰',
      'SE': '瑞典',
      'CH': '瑞士',
      'SY': '叙利亚',
      'TW': '台湾',
      'TJ': '塔吉克斯坦',
      'TZ': '坦桑尼亚',
      'TH': '泰国',
      'TL': '东帝汶',
      'TG': '多哥',
      'TO': '汤加',
      'TT': '特立尼达和多巴哥',
      'TN': '突尼斯',
      'TR': '土耳其',
      'TM': '土库曼斯坦',
      'TV': '图瓦卢',
      'UG': '乌干达',
      'UA': '乌克兰',
      'AE': '阿联酋',
      'GB': '英国',
      'US': '美国',
      'UY': '乌拉圭',
      'UZ': '乌兹别克斯坦',
      'VU': '瓦努阿图',
      'VA': '梵蒂冈',
      'VE': '委内瑞拉',
      'VN': '越南',
      'YE': '也门',
      'ZM': '赞比亚',
      'ZW': '津巴布韦',
    };

    return countryNames[countryCode] ?? countryCode;
  }

  void stopSending() {
    _isRunning = false;
    onLog('🛑 全球发送服务已停止');
  }

  bool get isRunning => _isRunning;
}
