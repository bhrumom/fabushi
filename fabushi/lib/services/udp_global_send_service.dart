import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'geoip_data_service.dart';
import 'country_coordinates_service.dart';
import '../core/constants/country_servers.dart' as country_names;

/// UDP 全球发送服务
/// 使用 GeoLite2 IP 数据向全球每个国家发送 UDP 数据包
/// 仅用于非 Web 平台（iOS/Android/macOS）
class UDPGlobalSendService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;
  final void Function(String) onLog;
  final Function(
    double,
    double,
    double,
    double, {
    String? fromLabel,
    String? toLabel,
    Duration? displayDuration,
  })?
  onTransferBeam;
  final Function(int)? onCountrySent;
  final Function(int)? onLoopStart; // 每轮循环开始时的回调，参数为轮次

  // 用户位置
  double? _userLatitude;
  double? _userLongitude;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;
  int _loopCount = 0; // 当前轮次

  final GeoIPDataService _geoIPService = GeoIPDataService();
  final CountryCoordinatesService _coordService = CountryCoordinatesService();

  // UDP 端口（使用常见的可达端口）
  static const int _udpPort = 9999;

  // 每个数据包的最大大小（UDP 推荐不超过 1472 字节以避免分片）
  static const int _maxPacketSize = 1400;

  UDPGlobalSendService({
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
  }

  Future<bool> initialize() async {
    try {
      onLog('🌍 初始化 UDP 全球发送服务...');

      await _geoIPService.initialize();
      onLog('📊 GeoIP 数据: ${_geoIPService.isInitialized ? "已加载" : "未加载"}');

      await _coordService.initialize();

      final countryCodes = _geoIPService.getAllCountryCodes();
      onLog('✅ UDP 服务初始化完成，共 ${countryCodes.length} 个国家');

      // 打印前几个国家的 IP 数量用于调试
      for (final code in countryCodes.take(5)) {
        final ips = _geoIPService.getIPsForCountry(code);
        onLog('  $code: ${ips.length} 个 IP');
      }

      return true;
    } catch (e) {
      onLog('❌ UDP 服务初始化失败: $e');
      return false;
    }
  }

  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
  }) async {
    if (_isRunning) return;

    _isRunning = true;
    _sentCount = 0; // 这里改为国家计数
    _dataSentInMB = 0.0;

    RawDatagramSocket? socket;

    try {
      // 创建 UDP socket
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      onLog('🚀 UDP Socket 已创建，本地端口: ${socket.port}');

      final countryCodes = _geoIPService.getAllCountryCodes();
      onLog(
        '📤 开始 UDP 全球发送 - 文件数: ${files.length}, 目标国家: ${countryCodes.length}',
      );

      _loopCount = 0; // 重置轮次计数

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

          await Future.delayed(Duration.zero);

          // 确保文件有字节数据
          Uint8List? fileBytes = file.bytes;

          // 内存优化：大文件不加载全部内容
          const int largeFileThreshold = 10 * 1024 * 1024; // 10MB

          if (file.size >= largeFileThreshold) {
            // 大文件：只发送元数据，不加载完整内容
            onLog(
              '📦 大文件模式: ${file.name} (${(file.size / 1024 / 1024).toStringAsFixed(1)}MB) - 流式发送',
            );

            // 使用流式发送
            final countriesSent = await _sendLargeFileToAllCountries(
              socket,
              file,
              countryCodes,
            );

            final fileSizeMB = file.size / (1024 * 1024);
            _dataSentInMB += fileSizeMB * countriesSent;
            onDataSent(_dataSentInMB);

            continue; // 跳过下面的小文件处理逻辑
          }

          if (fileBytes == null || fileBytes.isEmpty) {
            // 如果 bytes 为空，尝试从路径读取
            if (file.path != null) {
              try {
                final fileObj = File(file.path!);
                fileBytes = await fileObj.readAsBytes();
                onLog('📂 从路径读取文件: ${file.name}, ${fileBytes.length} 字节');
              } catch (e) {
                onLog('❌ 无法读取文件 ${file.name}: $e');
                continue;
              }
            } else {
              onLog('⚠️ 文件 ${file.name} 无数据可发送');
              continue;
            }
          }

          final countriesSent = await _sendFileToAllCountriesWithBytes(
            socket,
            file.name,
            fileBytes,
            file.size,
            countryCodes,
          );

          final fileSizeMB = file.size / (1024 * 1024);
          _dataSentInMB += fileSizeMB * countriesSent;

          onDataSent(_dataSentInMB);

          onLog(
            '📊 UDP 文件 ${file.name}: ${fileSizeMB.toStringAsFixed(2)} MB × $countriesSent 国 成功',
          );

          await Future.delayed(const Duration(milliseconds: 100));
        }
      } while (isLoop && _isRunning);
    } catch (e) {
      onLog('❌ UDP 发送错误: $e');
    } finally {
      socket?.close();
      _isRunning = false;
      onStopped();
    }
  }

  Future<int> _sendFileToAllCountriesWithBytes(
    RawDatagramSocket socket,
    String fileName,
    Uint8List fileBytes,
    int fileSize,
    List<String> countryCodes,
  ) async {
    int successCount = 0;

    onLog(
      '📤 准备发送文件: $fileName, ${fileBytes.length} 字节到 ${countryCodes.length} 个国家',
    );

    for (int i = 0; i < countryCodes.length; i++) {
      if (!_isRunning) break;

      final countryCode = countryCodes[i];
      final countryName = _getCountryName(countryCode);

      await Future.delayed(Duration.zero);

      // 触发地球轨迹动画
      _triggerBeamAnimation(countryCode, countryName);

      // 获取该国家的 IP 地址
      final ips = _geoIPService.getIPsForCountry(countryCode);
      if (ips.isEmpty) {
        onLog('⚠️ $countryName ($countryCode) 无可用 IP');
        continue;
      }

      // 持续向该国家的多个 IP 发送 UDP 数据包，直到地球视角动画完成（约 2 秒）
      // 这样可以确保用户能看到完整的轨迹动画
      final sendStartTime = DateTime.now();
      const minSendDuration = Duration(milliseconds: 2000); // 最少发送 2 秒

      bool countrySuccess = false;
      int ipIndex = 0;
      int sendCount = 0;

      while (!countrySuccess ||
          DateTime.now().difference(sendStartTime) < minSendDuration) {
        if (!_isRunning) break;

        // 循环使用该国家的所有 IP
        final ip = ips[ipIndex % ips.length];
        ipIndex++;

        try {
          final success = await _sendUDPPacketWithBytes(
            socket,
            fileName,
            fileBytes,
            fileSize,
            ip,
            countryCode,
            countryName,
          );
          if (success) {
            countrySuccess = true;
            sendCount++;
          }
        } catch (e) {
          // UDP 发送失败，继续尝试下一个 IP
        }

        // 短暂延迟，避免发送过快
        await Future.delayed(const Duration(milliseconds: 100));

        // 最多发送 20 次，防止无限循环
        if (ipIndex >= 20) break;
      }

      if (countrySuccess) {
        successCount++;
        _sentCount++; // 实时更新国家计数
        onProgress(_sentCount); // 实时通知进度更新
        onLog('✅ UDP 发送到 $countryName ($countryCode) 成功 ($sendCount 次)');

        if (onCountrySent != null) {
          onCountrySent!(fileSize * sendCount);
        }
      } else {
        onLog('❌ UDP 发送到 $countryName ($countryCode) 失败');
      }
    }

    return successCount;
  }

  /// 大文件流式发送到所有国家
  ///
  /// 真正的流式发送版本：
  /// - 从磁盘分块读取文件（每块 1MB）
  /// - 每次只保留一个块在内存中
  /// - 发送完一个块后才读取下一个块
  Future<int> _sendLargeFileToAllCountries(
    RawDatagramSocket socket,
    PlatformFile file,
    List<String> countryCodes,
  ) async {
    int successCount = 0;

    final fileSizeMB = (file.size / 1024 / 1024).toStringAsFixed(1);
    onLog(
      '📤 大文件流式发送: ${file.name}, ${fileSizeMB}MB 到 ${countryCodes.length} 个国家',
    );

    // 确保有文件路径
    if (file.path == null) {
      onLog('❌ 大文件必须有文件路径才能流式发送');
      return 0;
    }

    final fileObj = File(file.path!);
    if (!await fileObj.exists()) {
      onLog('❌ 文件不存在: ${file.path}');
      return 0;
    }

    for (int i = 0; i < countryCodes.length; i++) {
      if (!_isRunning) break;

      final countryCode = countryCodes[i];
      final countryName = _getCountryName(countryCode);

      await Future.delayed(Duration.zero);

      // 触发地球轨迹动画
      _triggerBeamAnimation(countryCode, countryName);

      // 获取该国家的 IP 地址
      final ips = _geoIPService.getIPsForCountry(countryCode);
      if (ips.isEmpty) {
        continue;
      }

      // 流式发送文件到该国家
      final success = await _streamSendFileToCountry(
        socket,
        fileObj,
        file.name,
        file.size,
        ips.first,
        countryCode,
        countryName,
      );

      if (success) {
        successCount++;
        _sentCount++;
        onProgress(_sentCount);

        if (onCountrySent != null) {
          onCountrySent!(file.size);
        }
      }

      // 每 5 个国家后让出控制权
      if (i % 5 == 0 && i > 0) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    onLog('✅ 大文件 ${file.name} 流式发送完成 - 成功: $successCount 个国家');
    return successCount;
  }

  /// 流式发送文件到单个国家
  ///
  /// 每次只读取并发送 1MB 数据块，避免内存溢出
  Future<bool> _streamSendFileToCountry(
    RawDatagramSocket socket,
    File file,
    String fileName,
    int fileSize,
    String targetIP,
    String countryCode,
    String countryName,
  ) async {
    try {
      final address = InternetAddress(targetIP);

      // 发送文件头信息
      final header = {
        'type': 'dharma_stream_start',
        'fileName': fileName,
        'fileSize': fileSize,
        'countryCode': countryCode,
        'countryName': countryName,
        'timestamp': DateTime.now().toIso8601String(),
        'chunkSize': _streamChunkSize,
        'totalChunks': (fileSize / _streamChunkSize).ceil(),
      };

      final headerBytes = utf8.encode(jsonEncode(header));
      socket.send(headerBytes, address, _udpPort);

      // 流式读取并发送文件
      final stream = file.openRead();
      int chunkIndex = 0;
      int totalBytesSent = headerBytes.length;

      await for (var chunk in stream) {
        if (!_isRunning) break;

        // 分割成 UDP 可发送的小包（最大 1400 字节）
        int offset = 0;
        while (offset < chunk.length) {
          final end = (offset + _maxPacketSize).clamp(0, chunk.length);
          final packet = _buildStreamPacket(
            chunkIndex,
            Uint8List.fromList(chunk.sublist(offset, end)),
            countryCode,
          );

          final sent = socket.send(packet, address, _udpPort);
          totalBytesSent += sent;
          offset = end;
        }

        chunkIndex++;

        // 每发送 10 个块后让出控制权，避免阻塞 UI
        if (chunkIndex % 10 == 0) {
          await Future.delayed(Duration.zero);
        }

        // 每发送 100 个块后稍作延迟，控制发送速率
        if (chunkIndex % 100 == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      // 发送文件结束标记
      final footer = {
        'type': 'dharma_stream_end',
        'fileName': fileName,
        'totalChunks': chunkIndex,
        'totalBytes': totalBytesSent,
        'countryCode': countryCode,
      };

      socket.send(utf8.encode(jsonEncode(footer)), address, _udpPort);

      debugPrint('✅ 流式发送完成: $countryName - $chunkIndex 块, $totalBytesSent 字节');
      return true;
    } catch (e) {
      debugPrint('❌ 流式发送到 $targetIP 失败: $e');
      return false;
    }
  }

  /// 构建流式数据包
  Uint8List _buildStreamPacket(int index, Uint8List data, String countryCode) {
    // 简单的数据包格式: [4字节索引][2字节国家代码长度][国家代码][数据]
    final countryBytes = utf8.encode(countryCode);
    final packet = BytesBuilder();

    // 包索引 (4 字节)
    packet.add(_intToBytes(index));

    // 国家代码长度 (2 字节)
    packet.addByte((countryBytes.length >> 8) & 0xFF);
    packet.addByte(countryBytes.length & 0xFF);

    // 国家代码
    packet.add(countryBytes);

    // 数据
    packet.add(data);

    return packet.toBytes();
  }

  // 流式发送块大小（1MB）
  static const int _streamChunkSize = 1024 * 1024;

  /// 发送元数据 UDP 包（不包含文件内容）- 保留作为备用
  Future<bool> _sendMetadataPacket(
    RawDatagramSocket socket,
    String fileName,
    int fileSize,
    String targetIP,
    String countryCode,
    String countryName,
  ) async {
    try {
      final address = InternetAddress(targetIP);

      // 只发送元数据，不包含文件内容
      final metadata = {
        'type': 'dharma_metadata',
        'fileName': fileName,
        'fileSize': fileSize,
        'countryCode': countryCode,
        'countryName': countryName,
        'timestamp': DateTime.now().toIso8601String(),
        'mode': 'streaming', // 标识为流式模式
      };

      final metadataBytes = utf8.encode(jsonEncode(metadata));
      final sent = socket.send(metadataBytes, address, _udpPort);

      return sent > 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _sendUDPPacketWithBytes(
    RawDatagramSocket socket,
    String fileName,
    Uint8List fileBytes,
    int fileSize,
    String targetIP,
    String countryCode,
    String countryName,
  ) async {
    try {
      final address = InternetAddress(targetIP);

      // 构建数据包头部
      final header = {
        'type': 'dharma_broadcast',
        'fileName': fileName,
        'fileSize': fileSize,
        'countryCode': countryCode,
        'countryName': countryName,
        'timestamp': DateTime.now().toIso8601String(),
        'checksum': _calculateChecksum(fileBytes),
      };

      final headerBytes = utf8.encode(jsonEncode(header));

      // 发送头部包
      final headerSent = socket.send(headerBytes, address, _udpPort);
      debugPrint('📤 UDP 发送头部到 $targetIP:$_udpPort - $headerSent 字节');

      // 如果发送返回 0，可能是网络不可达，尝试下一个 IP
      if (headerSent <= 0) {
        debugPrint('⚠️ UDP 头部发送失败 (0字节)，IP 可能不可达: $targetIP');
        return false;
      }

      // 分片发送文件数据
      int offset = 0;
      int packetIndex = 0;
      int totalBytesSent = headerSent;

      while (offset < fileBytes.length && _isRunning) {
        final end = (offset + _maxPacketSize).clamp(0, fileBytes.length);
        final chunk = fileBytes.sublist(offset, end);

        // 构建数据包
        final packet = _buildDataPacket(packetIndex, chunk, countryCode);

        final sent = socket.send(packet, address, _udpPort);
        totalBytesSent += sent;

        offset = end;
        packetIndex++;

        // 每 10 个包后让出控制权
        if (packetIndex % 10 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      debugPrint(
        '✅ UDP 发送完成: $countryName - $packetIndex 个包, $totalBytesSent 字节',
      );
      return true;
    } catch (e) {
      debugPrint('❌ UDP 发送到 $targetIP 失败: $e');
      return false;
    }
  }

  Uint8List _buildDataPacket(int index, Uint8List data, String countryCode) {
    // 简单的数据包格式: [4字节索引][2字节国家代码长度][国家代码][数据]
    final countryBytes = utf8.encode(countryCode);
    final packet = BytesBuilder();

    // 包索引 (4 字节)
    packet.add(_intToBytes(index));

    // 国家代码长度 (2 字节)
    packet.addByte((countryBytes.length >> 8) & 0xFF);
    packet.addByte(countryBytes.length & 0xFF);

    // 国家代码
    packet.add(countryBytes);

    // 数据
    packet.add(data);

    return packet.toBytes();
  }

  Uint8List _intToBytes(int value) {
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.big);
  }

  String _calculateChecksum(Uint8List data) {
    int sum = 0;
    for (final byte in data) {
      sum = (sum + byte) & 0xFFFFFFFF;
    }
    return sum.toRadixString(16);
  }

  void _triggerBeamAnimation(String countryCode, String countryName) {
    if (onTransferBeam == null) return;

    final toCountry = _coordService.getByCountryCode(countryCode);
    if (toCountry == null) return;

    const beamDuration = Duration(milliseconds: 800);

    if (_userLatitude != null && _userLongitude != null) {
      final fromCountry = _coordService.getByCoordinates(
        _userLatitude!,
        _userLongitude!,
      );
      final fromLabel = fromCountry?.countryCode != null
          ? _getCountryName(fromCountry!.countryCode!)
          : fromCountry?.countryName ?? '起点';
      onTransferBeam!(
        _userLatitude!,
        _userLongitude!,
        toCountry.latitude,
        toCountry.longitude,
        fromLabel: fromLabel,
        toLabel: countryName,
        displayDuration: beamDuration,
      );
    } else {
      // 默认使用中国作为起点
      final china = _coordService.getByCountryCode('CN');
      if (china != null) {
        onTransferBeam!(
          china.latitude,
          china.longitude,
          toCountry.latitude,
          toCountry.longitude,
          fromLabel: '中国',
          toLabel: countryName,
          displayDuration: beamDuration,
        );
      }
    }
  }

  void stopSending() {
    _isRunning = false;
    onLog('🛑 UDP 全球发送已停止');
  }

  bool get isRunning => _isRunning;

  String _getCountryName(String countryCode) {
    final countryName = country_names.COUNTRY_NAMES[countryCode];
    if (countryName != null) return countryName;

    final names = {
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
      'TH': '泰国',
      'VN': '越南',
      'SG': '新加坡',
      'MY': '马来西亚',
      'ID': '印度尼西亚',
      'PH': '菲律宾',
      'NL': '荷兰',
      'BE': '比利时',
      'SE': '瑞典',
      'NO': '挪威',
      'DK': '丹麦',
      'FI': '芬兰',
      'CH': '瑞士',
      'AT': '奥地利',
      'PL': '波兰',
      'CZ': '捷克',
      'PT': '葡萄牙',
      'GR': '希腊',
      'TR': '土耳其',
      'SA': '沙特阿拉伯',
      'AE': '阿联酋',
      'IL': '以色列',
      'NZ': '新西兰',
      'IE': '爱尔兰',
    };
    return names[countryCode] ?? countryCode;
  }
}
