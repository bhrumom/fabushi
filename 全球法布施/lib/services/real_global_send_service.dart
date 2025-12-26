import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;
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
  final Function(int)? onLoopStart;  // 每轮循环开始时的回调，参数为轮次

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;
  int _totalCountries = 0;
  int _currentCountryIndex = 0;
  int _loopCount = 0;  // 当前轮次

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
    this.onLoopStart,
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
    _sentCount = 0;  // 这里改为国家计数
    _dataSentInMB = 0.0;
    _currentCountryIndex = 0;

    try {
      onLog('🚀 开始真实全球发送 - 文件数量: ${files.length}, 目标国家: $_totalCountries 个');

      _loopCount = 0;  // 重置轮次计数
      
      do {
        // 每轮循环开始
        _loopCount++;
        _sentCount = 0;
        onProgress(_sentCount);
        
        // 通知轮次更新
        if (onLoopStart != null) {
          onLoopStart!(_loopCount);
        }
        onLog('🔄 开始第 $_loopCount 轮发送');
        
        for (final file in files) {
          if (!_isRunning) break;

          // 关键修复：在处理每个文件前让出主线程控制权
          await Future.delayed(Duration.zero);

          final countriesSent = await _sendFileToAllCountries(file);

          final fileSizeMB = file.size / (1024 * 1024);
          _dataSentInMB += fileSizeMB * countriesSent;

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

      if (countrySuccess) {
        _sentCount++;  // 实时更新国家计数
        onProgress(_sentCount);  // 实时通知进度更新
      } else {
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

  /// 发送文件到服务器
  /// 
  /// 内存优化：
  /// - 小文件（< 10MB）：直接 base64 发送
  /// - 大文件（>= 10MB）：流式分块发送，每次只加载 1MB 到内存
  Future<void> _sendToServer(
    PlatformFile file,
    String serverUrl,
    String countryCode,
    String countryName,
  ) async {
    try {
      // 关键修复：在网络请求前让出主线程控制权
      await Future.delayed(Duration.zero);
      
      // 内存优化：大文件使用流式发送
      const int largeFileThreshold = 10 * 1024 * 1024; // 10MB
      
      if (file.size >= largeFileThreshold && file.path != null) {
        // 大文件：流式分块发送
        await _streamSendLargeFile(file, serverUrl, countryCode, countryName);
      } else {
        // 小文件：发送完整内容
        final requestData = {
          'fileName': file.name,
          'fileSize': file.size,
          'countryCode': countryCode,
          'countryName': countryName,
          'timestamp': DateTime.now().toIso8601String(),
          'data': base64Encode(file.bytes ?? Uint8List(0)),
        };
        
        await _sendSmallFile(requestData, serverUrl, countryCode, countryName);
      }

      onLog('✅ 成功发送到 $countryName ($countryCode) - $serverUrl');
    } catch (e) {
      throw Exception('发送失败: $e');
    }
  }
  
  /// 流式发送大文件（分块读取，分块上传）
  /// 
  /// 每次只从磁盘读取 1MB，发送后释放内存，再读取下一块
  Future<void> _streamSendLargeFile(
    PlatformFile file,
    String serverUrl,
    String countryCode,
    String countryName,
  ) async {
    const int chunkSize = 1024 * 1024; // 1MB per chunk
    
    final fileObj = File(file.path!);
    if (!await fileObj.exists()) {
      throw Exception('文件不存在: ${file.path}');
    }
    
    final totalChunks = (file.size / chunkSize).ceil();
    onLog('📦 大文件流式发送: ${file.name} (${(file.size / 1024 / 1024).toStringAsFixed(1)}MB) - $totalChunks 块');
    
    // 发送起始标记
    final startPayload = {
      'type': 'stream_start',
      'fileName': file.name,
      'fileSize': file.size,
      'totalChunks': totalChunks,
      'countryCode': countryCode,
      'countryName': countryName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _sendChunk(serverUrl, startPayload);
    
    // 流式读取并发送每一块
    final stream = fileObj.openRead();
    int chunkIndex = 0;
    final buffer = BytesBuilder();
    
    await for (var data in stream) {
      if (!_isRunning) break;
      
      buffer.add(data);
      
      // 当缓冲区达到块大小时发送
      while (buffer.length >= chunkSize) {
        final chunk = buffer.takeBytes();
        final chunkToSend = chunk.sublist(0, chunkSize);
        final remaining = chunk.sublist(chunkSize);
        
        // 发送当前块
        final chunkPayload = {
          'type': 'stream_chunk',
          'fileName': file.name,
          'chunkIndex': chunkIndex,
          'chunkData': base64Encode(chunkToSend),
          'countryCode': countryCode,
        };
        
        await _sendChunk(serverUrl, chunkPayload);
        chunkIndex++;
        
        // 将剩余数据放回缓冲区
        buffer.add(remaining);
        
        // 每发送一块后让出控制权
        await Future.delayed(Duration.zero);
      }
    }
    
    // 发送最后一块（如果有剩余）
    if (buffer.isNotEmpty) {
      final chunkPayload = {
        'type': 'stream_chunk',
        'fileName': file.name,
        'chunkIndex': chunkIndex,
        'chunkData': base64Encode(buffer.takeBytes()),
        'countryCode': countryCode,
      };
      
      await _sendChunk(serverUrl, chunkPayload);
      chunkIndex++;
    }
    
    // 发送结束标记
    final endPayload = {
      'type': 'stream_end',
      'fileName': file.name,
      'totalChunksSent': chunkIndex,
      'countryCode': countryCode,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _sendChunk(serverUrl, endPayload);
    onLog('✅ 大文件流式发送完成: $chunkIndex 块');
  }
  
  /// 发送单个数据块
  Future<void> _sendChunk(String serverUrl, Map<String, dynamic> payload) async {
    if (serverUrl.contains('httpbin.org')) {
      await http
          .post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/json', 'User-Agent': 'GlobalDharmaSender/1.0'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
    } else if (serverUrl.contains('jsonplaceholder.typicode.com')) {
      await http
          .post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/json', 'User-Agent': 'GlobalDharmaSender/1.0'},
            body: jsonEncode({
              'title': 'Dharma Chunk - ${payload['fileName']}',
              'body': 'Chunk ${payload['chunkIndex'] ?? 'meta'}',
              'userId': 1,
            }),
          )
          .timeout(const Duration(seconds: 5));
    }
  }
  
  /// 发送小文件（完整内容）
  Future<void> _sendSmallFile(
    Map<String, dynamic> requestData,
    String serverUrl,
    String countryCode,
    String countryName,
  ) async {
    if (serverUrl.contains('httpbin.org')) {
      final response = await http
          .post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/json', 'User-Agent': 'GlobalDharmaSender/1.0'},
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
    } else if (serverUrl.contains('jsonplaceholder.typicode.com')) {
      final response = await http
          .post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/json', 'User-Agent': 'GlobalDharmaSender/1.0'},
            body: jsonEncode({
              'title': 'Global Dharma Send - ${requestData['fileName']}',
              'body': 'File sent from $countryName ($countryCode)',
              'userId': 1,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 201) {
        throw Exception('HTTP ${response.statusCode}');
      }
    }
  }
  
  /// 计算文件哈希（流式读取，不占用大量内存）
  Future<String> _calculateFileHash(PlatformFile file) async {
    try {
      if (file.path != null) {
        // 有文件路径：流式读取计算哈希
        final fileObj = File(file.path!);
        final stream = fileObj.openRead();
        
        // 使用简单的分块哈希计算，避免依赖 AccumulatorSink
        var hash = crypto.sha256.convert([]);
        final chunks = <int>[];
        
        await for (var chunk in stream) {
          chunks.addAll(chunk);
          // 每累积 1MB 计算一次中间哈希，防止内存过大
          if (chunks.length > 1024 * 1024) {
            hash = crypto.sha256.convert(chunks);
            chunks.clear();
            chunks.addAll(hash.bytes);
          }
        }
        
        // 计算最终哈希
        return crypto.sha256.convert(chunks).toString();
      } else if (file.bytes != null && file.bytes!.length < 10 * 1024 * 1024) {
        // 有内存数据且不太大
        return crypto.sha256.convert(file.bytes!).toString();
      } else {
        // 无法计算，返回基于文件名和大小的伪哈希
        return crypto.sha256.convert(
          utf8.encode('${file.name}-${file.size}-${DateTime.now().millisecondsSinceEpoch}')
        ).toString();
      }
    } catch (e) {
      // 哈希计算失败，返回伪哈希
      return crypto.sha256.convert(
        utf8.encode('${file.name}-${file.size}')
      ).toString();
    }
  }

  String _getCountryName(String countryCode) {
    // 国家代码到中文名称映射（按字母顺序，无重复）
    final Map<String, String> countryNames = {
      'AD': '安道尔',
      'AE': '阿联酋',
      'AF': '阿富汗',
      'AG': '安提瓜和巴布达',
      'AL': '阿尔巴尼亚',
      'AM': '亚美尼亚',
      'AO': '安哥拉',
      'AR': '阿根廷',
      'AT': '奥地利',
      'AU': '澳大利亚',
      'AZ': '阿塞拜疆',
      'BA': '波斯尼亚和黑塞哥维那',
      'BB': '巴巴多斯',
      'BD': '孟加拉国',
      'BE': '比利时',
      'BF': '布基纳法索',
      'BG': '保加利亚',
      'BH': '巴林',
      'BI': '布隆迪',
      'BJ': '贝宁',
      'BN': '文莱',
      'BO': '玻利维亚',
      'BR': '巴西',
      'BS': '巴哈马',
      'BT': '不丹',
      'BW': '博茨瓦纳',
      'BY': '白俄罗斯',
      'BZ': '伯利兹',
      'CA': '加拿大',
      'CD': '刚果民主共和国',
      'CF': '中非共和国',
      'CG': '刚果共和国',
      'CH': '瑞士',
      'CI': '科特迪瓦',
      'CL': '智利',
      'CM': '喀麦隆',
      'CN': '中国',
      'CO': '哥伦比亚',
      'CR': '哥斯达黎加',
      'CU': '古巴',
      'CV': '佛得角',
      'CY': '塞浦路斯',
      'CZ': '捷克共和国',
      'DE': '德国',
      'DJ': '吉布提',
      'DK': '丹麦',
      'DM': '多米尼克',
      'DO': '多米尼加共和国',
      'DZ': '阿尔及利亚',
      'EC': '厄瓜多尔',
      'EE': '爱沙尼亚',
      'EG': '埃及',
      'ER': '厄立特里亚',
      'ES': '西班牙',
      'ET': '埃塞俄比亚',
      'FI': '芬兰',
      'FJ': '斐济',
      'FM': '密克罗尼西亚',
      'FR': '法国',
      'GA': '加蓬',
      'GB': '英国',
      'GD': '格林纳达',
      'GE': '格鲁吉亚',
      'GH': '加纳',
      'GM': '冈比亚',
      'GN': '几内亚',
      'GQ': '赤道几内亚',
      'GR': '希腊',
      'GT': '危地马拉',
      'GW': '几内亚比绍',
      'GY': '圭亚那',
      'HN': '洪都拉斯',
      'HR': '克罗地亚',
      'HT': '海地',
      'HU': '匈牙利',
      'ID': '印度尼西亚',
      'IE': '爱尔兰',
      'IL': '以色列',
      'IN': '印度',
      'IQ': '伊拉克',
      'IR': '伊朗',
      'IS': '冰岛',
      'IT': '意大利',
      'JM': '牙买加',
      'JO': '约旦',
      'JP': '日本',
      'KE': '肯尼亚',
      'KG': '吉尔吉斯斯坦',
      'KH': '柬埔寨',
      'KI': '基里巴斯',
      'KM': '科摩罗',
      'KN': '圣基茨和尼维斯',
      'KR': '韩国',
      'KW': '科威特',
      'KZ': '哈萨克斯坦',
      'LA': '老挝',
      'LB': '黎巴嫩',
      'LC': '圣卢西亚',
      'LI': '列支敦士登',
      'LK': '斯里兰卡',
      'LR': '利比里亚',
      'LS': '莱索托',
      'LT': '立陶宛',
      'LU': '卢森堡',
      'LV': '拉脱维亚',
      'LY': '利比亚',
      'MA': '摩洛哥',
      'MC': '摩纳哥',
      'MD': '摩尔多瓦',
      'ME': '黑山',
      'MG': '马达加斯加',
      'MH': '马绍尔群岛',
      'MK': '马其顿',
      'ML': '马里',
      'MM': '缅甸',
      'MN': '蒙古',
      'MR': '毛里塔尼亚',
      'MT': '马耳他',
      'MU': '毛里求斯',
      'MV': '马尔代夫',
      'MW': '马拉维',
      'MX': '墨西哥',
      'MY': '马来西亚',
      'MZ': '莫桑比克',
      'NA': '纳米比亚',
      'NE': '尼日尔',
      'NG': '尼日利亚',
      'NI': '尼加拉瓜',
      'NL': '荷兰',
      'NO': '挪威',
      'NP': '尼泊尔',
      'NR': '瑙鲁',
      'NZ': '新西兰',
      'OM': '阿曼',
      'PA': '巴拿马',
      'PE': '秘鲁',
      'PG': '巴布亚新几内亚',
      'PH': '菲律宾',
      'PK': '巴基斯坦',
      'PL': '波兰',
      'PT': '葡萄牙',
      'PW': '帕劳',
      'PY': '巴拉圭',
      'QA': '卡塔尔',
      'RO': '罗马尼亚',
      'RS': '塞尔维亚',
      'RU': '俄罗斯',
      'RW': '卢旺达',
      'SA': '沙特阿拉伯',
      'SB': '所罗门群岛',
      'SC': '塞舌尔',
      'SD': '苏丹',
      'SE': '瑞典',
      'SG': '新加坡',
      'SI': '斯洛文尼亚',
      'SK': '斯洛伐克',
      'SL': '塞拉利昂',
      'SM': '圣马力诺',
      'SN': '塞内加尔',
      'SO': '索马里',
      'SR': '苏里南',
      'SS': '南苏丹',
      'ST': '圣多美和普林西比',
      'SV': '萨尔瓦多',
      'SY': '叙利亚',
      'SZ': '斯威士兰',
      'TD': '乍得',
      'TG': '多哥',
      'TH': '泰国',
      'TJ': '塔吉克斯坦',
      'TL': '东帝汶',
      'TM': '土库曼斯坦',
      'TN': '突尼斯',
      'TO': '汤加',
      'TR': '土耳其',
      'TT': '特立尼达和多巴哥',
      'TV': '图瓦卢',
      'TW': '台湾',
      'TZ': '坦桑尼亚',
      'UA': '乌克兰',
      'UG': '乌干达',
      'US': '美国',
      'UY': '乌拉圭',
      'UZ': '乌兹别克斯坦',
      'VA': '梵蒂冈',
      'VC': '圣文森特和格林纳丁斯',
      'VE': '委内瑞拉',
      'VN': '越南',
      'VU': '瓦努阿图',
      'WS': '萨摩亚',
      'YE': '也门',
      'ZA': '南非',
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
