import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// GeoLite2 IP 数据服务
/// 解析 GeoLite2-Country-Blocks-IPv4.csv 获取每个国家的 IP 地址
class GeoIPDataService {
  static final GeoIPDataService _instance = GeoIPDataService._internal();
  factory GeoIPDataService() => _instance;
  GeoIPDataService._internal();

  bool _isInitialized = false;
  
  // 国家代码 -> IP 地址列表
  final Map<String, List<String>> _countryIPs = {};
  
  // geoname_id -> 国家代码映射（使用方法初始化避免重复键警告）
  late final Map<String, String> _geonameToCountry;

  void _initGeonameMapping() {
    _geonameToCountry = <String, String>{};
    // 主要国家
    _geonameToCountry['2077456'] = 'AU'; // 澳大利亚
    _geonameToCountry['1814991'] = 'CN'; // 中国
    _geonameToCountry['1861060'] = 'JP'; // 日本
    _geonameToCountry['1605651'] = 'TH'; // 泰国
    _geonameToCountry['6252001'] = 'US'; // 美国
    _geonameToCountry['2635167'] = 'GB'; // 英国
    _geonameToCountry['2921044'] = 'DE'; // 德国
    _geonameToCountry['3017382'] = 'FR'; // 法国
    _geonameToCountry['3175395'] = 'IT'; // 意大利
    _geonameToCountry['2510769'] = 'ES'; // 西班牙
    _geonameToCountry['2017370'] = 'RU'; // 俄罗斯
    _geonameToCountry['1269750'] = 'IN'; // 印度
    _geonameToCountry['3469034'] = 'BR'; // 巴西
    _geonameToCountry['6251999'] = 'CA'; // 加拿大
    _geonameToCountry['3996063'] = 'MX'; // 墨西哥
    _geonameToCountry['3865483'] = 'AR'; // 阿根廷
    _geonameToCountry['953987'] = 'ZA'; // 南非
    _geonameToCountry['357994'] = 'EG'; // 埃及
    _geonameToCountry['2328926'] = 'NG'; // 尼日利亚
    _geonameToCountry['192950'] = 'KE'; // 肯尼亚
    _geonameToCountry['1835841'] = 'KR'; // 韩国
    _geonameToCountry['1694008'] = 'PH'; // 菲律宾
    _geonameToCountry['1643084'] = 'ID'; // 印度尼西亚
    _geonameToCountry['1733045'] = 'MY'; // 马来西亚
    _geonameToCountry['1880251'] = 'SG'; // 新加坡
    _geonameToCountry['1562822'] = 'VN'; // 越南
    _geonameToCountry['1227603'] = 'NP'; // 尼泊尔
    _geonameToCountry['1168579'] = 'PK'; // 巴基斯坦
    _geonameToCountry['1210997'] = 'BD'; // 孟加拉国
    _geonameToCountry['1831722'] = 'KH'; // 柬埔寨
    _geonameToCountry['1655842'] = 'LA'; // 老挝
    _geonameToCountry['1327865'] = 'MM'; // 缅甸
    _geonameToCountry['1220409'] = 'BT'; // 不丹
    _geonameToCountry['1282988'] = 'MV'; // 马尔代夫
    _geonameToCountry['1282028'] = 'LK'; // 斯里兰卡
    _geonameToCountry['1149361'] = 'AF'; // 阿富汗
    _geonameToCountry['130758'] = 'IR'; // 伊朗
    _geonameToCountry['99237'] = 'IQ'; // 伊拉克
    _geonameToCountry['163843'] = 'SA'; // 沙特阿拉伯
    _geonameToCountry['290557'] = 'AE'; // 阿联酋
    _geonameToCountry['248816'] = 'JO'; // 约旦
    _geonameToCountry['272103'] = 'IL'; // 以色列
    _geonameToCountry['298795'] = 'TR'; // 土耳其
    _geonameToCountry['294640'] = 'SY'; // 叙利亚
    _geonameToCountry['276781'] = 'LB'; // 黎巴嫩
    _geonameToCountry['285570'] = 'KW'; // 科威特
    _geonameToCountry['289688'] = 'QA'; // 卡塔尔
    _geonameToCountry['286963'] = 'OM'; // 阿曼
    _geonameToCountry['287286'] = 'BH'; // 巴林
    _geonameToCountry['69543'] = 'YE'; // 也门
    // 欧洲
    _geonameToCountry['2658434'] = 'CH'; // 瑞士
    _geonameToCountry['2782113'] = 'AT'; // 奥地利
    _geonameToCountry['2802361'] = 'BE'; // 比利时
    _geonameToCountry['2750405'] = 'NL'; // 荷兰
    _geonameToCountry['2661886'] = 'SE'; // 瑞典
    _geonameToCountry['3144096'] = 'NO'; // 挪威
    _geonameToCountry['2623032'] = 'DK'; // 丹麦
    _geonameToCountry['660013'] = 'FI'; // 芬兰
    _geonameToCountry['2963597'] = 'IE'; // 爱尔兰
    _geonameToCountry['2264397'] = 'PT'; // 葡萄牙
    _geonameToCountry['390903'] = 'GR'; // 希腊
    _geonameToCountry['798544'] = 'PL'; // 波兰
    _geonameToCountry['3077311'] = 'CZ'; // 捷克
    _geonameToCountry['719819'] = 'HU'; // 匈牙利
    _geonameToCountry['798549'] = 'RO'; // 罗马尼亚
    _geonameToCountry['732800'] = 'BG'; // 保加利亚
    _geonameToCountry['3202326'] = 'HR'; // 克罗地亚
    _geonameToCountry['3190538'] = 'SI'; // 斯洛文尼亚
    _geonameToCountry['3057568'] = 'SK'; // 斯洛伐克
    _geonameToCountry['453733'] = 'EE'; // 爱沙尼亚
    _geonameToCountry['458258'] = 'LV'; // 拉脱维亚
    _geonameToCountry['597427'] = 'LT'; // 立陶宛
    _geonameToCountry['630336'] = 'BY'; // 白俄罗斯
    _geonameToCountry['690791'] = 'UA'; // 乌克兰
    _geonameToCountry['617790'] = 'MD'; // 摩尔多瓦
    _geonameToCountry['783754'] = 'AL'; // 阿尔巴尼亚
    _geonameToCountry['3277605'] = 'BA'; // 波黑
    _geonameToCountry['718075'] = 'MK'; // 北马其顿
    _geonameToCountry['6290252'] = 'RS'; // 塞尔维亚
    _geonameToCountry['3194884'] = 'ME'; // 黑山
    // 大洋洲
    _geonameToCountry['2186224'] = 'NZ'; // 新西兰
    _geonameToCountry['2139685'] = 'NC'; // 新喀里多尼亚
    _geonameToCountry['1559582'] = 'PW'; // 帕劳
    _geonameToCountry['2081918'] = 'FM'; // 密克罗尼西亚
    _geonameToCountry['2110425'] = 'SB'; // 所罗门群岛
    _geonameToCountry['2134431'] = 'VU'; // 瓦努阿图
    _geonameToCountry['2205218'] = 'FJ'; // 斐济
    _geonameToCountry['4030945'] = 'KI'; // 基里巴斯
    _geonameToCountry['2110297'] = 'TV'; // 图瓦卢
    _geonameToCountry['2110425'] = 'NR'; // 瑙鲁
    _geonameToCountry['4032283'] = 'TO'; // 汤加
    _geonameToCountry['4034894'] = 'WS'; // 萨摩亚
    // 非洲
    _geonameToCountry['3355338'] = 'NA'; // 纳米比亚
    _geonameToCountry['933860'] = 'BW'; // 博茨瓦纳
    _geonameToCountry['878675'] = 'ZW'; // 津巴布韦
    _geonameToCountry['895949'] = 'ZM'; // 赞比亚
    _geonameToCountry['1036973'] = 'MZ'; // 莫桑比克
    _geonameToCountry['1062947'] = 'MG'; // 马达加斯加
    _geonameToCountry['927384'] = 'MW'; // 马拉维
    _geonameToCountry['149590'] = 'TZ'; // 坦桑尼亚
    _geonameToCountry['226074'] = 'UG'; // 乌干达
    _geonameToCountry['49518'] = 'RW'; // 卢旺达
    _geonameToCountry['433561'] = 'BI'; // 布隆迪
    _geonameToCountry['203312'] = 'CD'; // 刚果民主共和国
    _geonameToCountry['2260494'] = 'CG'; // 刚果共和国
    _geonameToCountry['2400553'] = 'GA'; // 加蓬
    _geonameToCountry['2233387'] = 'CM'; // 喀麦隆
    _geonameToCountry['2309096'] = 'GQ'; // 赤道几内亚
    _geonameToCountry['2410758'] = 'ST'; // 圣多美和普林西比
    _geonameToCountry['239880'] = 'CF'; // 中非共和国
    _geonameToCountry['2434508'] = 'TD'; // 乍得
    _geonameToCountry['2440476'] = 'NE'; // 尼日尔
    _geonameToCountry['2361809'] = 'BF'; // 布基纳法索
    _geonameToCountry['2453866'] = 'ML'; // 马里
    _geonameToCountry['2378080'] = 'MR'; // 毛里塔尼亚
    _geonameToCountry['2245662'] = 'SN'; // 塞内加尔
    _geonameToCountry['2413451'] = 'GM'; // 冈比亚
    _geonameToCountry['2372248'] = 'GW'; // 几内亚比绍
    _geonameToCountry['2420477'] = 'GN'; // 几内亚
    _geonameToCountry['2403846'] = 'SL'; // 塞拉利昂
    _geonameToCountry['2275384'] = 'LR'; // 利比里亚
    _geonameToCountry['2287781'] = 'CI'; // 科特迪瓦
    _geonameToCountry['2300660'] = 'GH'; // 加纳
    _geonameToCountry['2363686'] = 'TG'; // 多哥
    _geonameToCountry['2395170'] = 'BJ'; // 贝宁
    _geonameToCountry['223816'] = 'DJ'; // 吉布提
    _geonameToCountry['338010'] = 'ER'; // 厄立特里亚
    _geonameToCountry['337996'] = 'ET'; // 埃塞俄比亚
    _geonameToCountry['366755'] = 'SD'; // 苏丹
    _geonameToCountry['7909807'] = 'SS'; // 南苏丹
    _geonameToCountry['51537'] = 'SO'; // 索马里
    _geonameToCountry['241170'] = 'SC'; // 塞舌尔
    _geonameToCountry['934292'] = 'MU'; // 毛里求斯
    _geonameToCountry['921929'] = 'KM'; // 科摩罗
    _geonameToCountry['2542007'] = 'MA'; // 摩洛哥
    _geonameToCountry['2589581'] = 'DZ'; // 阿尔及利亚
    _geonameToCountry['2464461'] = 'TN'; // 突尼斯
    _geonameToCountry['2215636'] = 'LY'; // 利比亚
    // 中美洲和加勒比
    _geonameToCountry['3582678'] = 'BZ'; // 伯利兹
    _geonameToCountry['3595528'] = 'GT'; // 危地马拉
    _geonameToCountry['3585968'] = 'SV'; // 萨尔瓦多
    _geonameToCountry['3608932'] = 'HN'; // 洪都拉斯
    _geonameToCountry['3617476'] = 'NI'; // 尼加拉瓜
    _geonameToCountry['3624060'] = 'CR'; // 哥斯达黎加
    _geonameToCountry['3703430'] = 'PA'; // 巴拿马
    _geonameToCountry['3562981'] = 'CU'; // 古巴
    _geonameToCountry['3489940'] = 'JM'; // 牙买加
    _geonameToCountry['3723988'] = 'HT'; // 海地
    _geonameToCountry['3508796'] = 'DO'; // 多米尼加
    _geonameToCountry['3576396'] = 'AG'; // 安提瓜和巴布达
    _geonameToCountry['3374084'] = 'BB'; // 巴巴多斯
    _geonameToCountry['3575830'] = 'DM'; // 多米尼克
    _geonameToCountry['3580239'] = 'GD'; // 格林纳达
    _geonameToCountry['3575174'] = 'KN'; // 圣基茨和尼维斯
    _geonameToCountry['3576468'] = 'LC'; // 圣卢西亚
    _geonameToCountry['3577815'] = 'VC'; // 圣文森特和格林纳丁斯
    _geonameToCountry['3573591'] = 'TT'; // 特立尼达和多巴哥
    // 南美洲
    _geonameToCountry['3378535'] = 'GY'; // 圭亚那
    _geonameToCountry['3382998'] = 'SR'; // 苏里南
    _geonameToCountry['3658394'] = 'EC'; // 厄瓜多尔
    _geonameToCountry['3686110'] = 'CO'; // 哥伦比亚
    _geonameToCountry['3625428'] = 'VE'; // 委内瑞拉
    _geonameToCountry['3932488'] = 'PE'; // 秘鲁
    _geonameToCountry['3923057'] = 'BO'; // 玻利维亚
    _geonameToCountry['3895114'] = 'CL'; // 智利
    _geonameToCountry['3437598'] = 'PY'; // 巴拉圭
    _geonameToCountry['3439705'] = 'UY'; // 乌拉圭
    // 中亚
    _geonameToCountry['1512440'] = 'UZ'; // 乌兹别克斯坦
    _geonameToCountry['1522867'] = 'KZ'; // 哈萨克斯坦
    _geonameToCountry['1220409'] = 'TJ'; // 塔吉克斯坦
    _geonameToCountry['1527747'] = 'KG'; // 吉尔吉斯斯坦
    _geonameToCountry['1218197'] = 'TM'; // 土库曼斯坦
    _geonameToCountry['587116'] = 'AZ'; // 阿塞拜疆
    _geonameToCountry['614540'] = 'GE'; // 格鲁吉亚
    _geonameToCountry['174982'] = 'AM'; // 亚美尼亚
    // 东亚
    _geonameToCountry['2029969'] = 'MN'; // 蒙古
    _geonameToCountry['1819730'] = 'HK'; // 香港
    _geonameToCountry['1821275'] = 'MO'; // 澳门
    _geonameToCountry['1668284'] = 'TW'; // 台湾
    _geonameToCountry['1873107'] = 'KP'; // 朝鲜
    // 小国
    _geonameToCountry['3041565'] = 'AD'; // 安道尔
    _geonameToCountry['2993457'] = 'MC'; // 摩纳哥
    _geonameToCountry['3168068'] = 'SM'; // 圣马力诺
    _geonameToCountry['3164670'] = 'VA'; // 梵蒂冈
    _geonameToCountry['3042058'] = 'LI'; // 列支敦士登
    _geonameToCountry['2562770'] = 'MT'; // 马耳他
    _geonameToCountry['146669'] = 'CY'; // 塞浦路斯
    _geonameToCountry['2629691'] = 'IS'; // 冰岛
    _geonameToCountry['3425505'] = 'GL'; // 格陵兰
    _geonameToCountry['2622320'] = 'FO'; // 法罗群岛
    _geonameToCountry['2411586'] = 'GI'; // 直布罗陀
    _geonameToCountry['934841'] = 'SZ'; // 斯威士兰
    _geonameToCountry['932692'] = 'LS'; // 莱索托
  }

  bool get isInitialized => _isInitialized;
  Map<String, List<String>> get countryIPs => _countryIPs;

  /// 初始化服务，加载 GeoLite2 数据
  Future<void> initialize() async {
    if (_isInitialized) return;

    _initGeonameMapping();

    try {
      debugPrint('🌍 开始加载 GeoLite2 IP 数据...');
      
      final csvData = await rootBundle.loadString('assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv');
      final lines = const LineSplitter().convert(csvData);
      
      // 跳过标题行
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length < 2) continue;
        
        final network = parts[0]; // CIDR 格式，如 1.0.0.0/24
        final geonameId = parts[1];
        
        if (geonameId.isEmpty) continue;
        
        // 获取国家代码
        final countryCode = _geonameToCountry[geonameId];
        if (countryCode == null) continue;
        
        // 从 CIDR 提取第一个 IP
        final ip = _getFirstIPFromCIDR(network);
        if (ip != null) {
          _countryIPs.putIfAbsent(countryCode, () => []);
          // 每个国家最多保存 100 个 IP，避免内存过大
          if (_countryIPs[countryCode]!.length < 100) {
            _countryIPs[countryCode]!.add(ip);
          }
        }
      }
      
      _isInitialized = true;
      debugPrint('✅ GeoLite2 数据加载完成，共 ${_countryIPs.length} 个国家');
      
    } catch (e) {
      debugPrint('❌ 加载 GeoLite2 数据失败: $e');
      // 使用备用数据
      _loadFallbackData();
    }
  }

  /// 从 CIDR 格式提取第一个 IP 地址
  String? _getFirstIPFromCIDR(String cidr) {
    try {
      final parts = cidr.split('/');
      if (parts.isEmpty) return null;
      return parts[0];
    } catch (e) {
      return null;
    }
  }

  /// 获取指定国家的 IP 列表
  List<String> getIPsForCountry(String countryCode) {
    return _countryIPs[countryCode] ?? [];
  }

  /// 获取指定国家的随机 IP
  String? getRandomIPForCountry(String countryCode) {
    final ips = _countryIPs[countryCode];
    if (ips == null || ips.isEmpty) return null;
    return ips[DateTime.now().millisecondsSinceEpoch % ips.length];
  }

  /// 获取所有国家代码
  List<String> getAllCountryCodes() {
    return _countryIPs.keys.toList();
  }

  /// 加载备用数据（当 CSV 加载失败时）
  void _loadFallbackData() {
    debugPrint('⚠️ 使用备用 IP 数据');
    
    // 每个国家至少一个代表性 IP
    _countryIPs.addAll({
      'CN': ['1.0.1.0', '1.0.2.0', '1.0.8.0', '1.0.32.0'],
      'US': ['3.0.0.0', '4.0.0.0', '8.0.0.0', '12.0.0.0'],
      'JP': ['1.0.16.0', '1.0.64.0', '1.1.64.0', '1.5.0.0'],
      'KR': ['1.11.0.0', '1.16.0.0', '1.176.0.0', '1.208.0.0'],
      'GB': ['2.16.0.0', '2.24.0.0', '2.96.0.0', '5.0.0.0'],
      'DE': ['2.16.96.0', '5.1.0.0', '5.8.0.0', '5.56.0.0'],
      'FR': ['2.0.0.0', '2.4.0.0', '5.10.0.0', '5.39.0.0'],
      'IT': ['2.32.0.0', '2.40.0.0', '5.88.0.0', '5.90.0.0'],
      'ES': ['2.136.0.0', '2.152.0.0', '5.59.0.0', '5.83.0.0'],
      'RU': ['2.56.0.0', '2.60.0.0', '5.3.0.0', '5.16.0.0'],
      'IN': ['1.6.0.0', '1.22.0.0', '1.38.0.0', '1.186.0.0'],
      'BR': ['2.16.168.0', '5.62.56.0', '5.183.0.0', '23.128.0.0'],
      'CA': ['2.16.0.0', '5.62.0.0', '8.0.0.0', '12.0.0.0'],
      'AU': ['1.0.0.0', '1.0.4.0', '1.40.0.0', '1.120.0.0'],
      'MX': ['2.16.0.0', '5.62.0.0', '8.0.0.0', '12.0.0.0'],
      'AR': ['2.16.0.0', '5.62.0.0', '8.0.0.0', '12.0.0.0'],
      'ZA': ['2.16.0.0', '5.62.0.0', '8.0.0.0', '12.0.0.0'],
      'EG': ['2.16.0.0', '5.62.0.0', '8.0.0.0', '12.0.0.0'],
      'NG': ['2.16.0.0', '5.62.0.0', '8.0.0.0', '12.0.0.0'],
      'KE': ['2.16.0.0', '5.62.0.0', '8.0.0.0', '12.0.0.0'],
      'TH': ['1.0.128.0', '1.0.160.0', '1.0.192.0', '1.46.0.0'],
      'VN': ['1.52.0.0', '1.53.0.0', '1.54.0.0', '1.55.0.0'],
      'SG': ['1.32.128.0', '1.32.192.0', '8.19.0.0', '13.228.0.0'],
      'MY': ['1.9.0.0', '1.32.0.0', '1.32.64.0', '14.0.0.0'],
      'ID': ['1.0.0.0', '1.20.0.0', '1.32.0.0', '14.0.0.0'],
      'PH': ['1.37.0.0', '1.38.0.0', '14.0.0.0', '27.0.0.0'],
    });
    
    _isInitialized = true;
  }
}
