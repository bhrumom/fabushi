import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config/unified_config.dart';
import 'app_settings.dart';
import '../core/locations.dart';
import '../utils/http_with_progress.dart';

class GlobalTransferService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;
  ValueChanged<List<String>>? onCountryListLoaded;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;
  int _dataSentInBytes = 0;
  int _currentIpIndex = 0;
  Map<String, List<String>> _countryIpMap = {};
  int _currentCountryIndex = 0;
  int _currentCountryIpIndex = 0;

  bool get isRunning => _isRunning;

  GlobalTransferService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
    this.onCountryListLoaded,
  }) {
    _loadIpAddresses();
  }

  Future<void> _loadIpAddresses() async {
    try {
      debugPrint("正在尝试加载IP地址列表...");
      final rawCsv = await rootBundle.loadString('assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv');
      debugPrint("成功读取CSV文件，开始解析...");
      final lines = const CsvToListConverter().convert(rawCsv, eol: '\n');
      debugPrint("CSV解析完成，共 ${lines.length} 行");

      _countryIpMap = {};
      int validEntries = 0;
      
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.length >= 3) {
          final network = line[0].toString();
          final countryId = line[2].toString();
          if (countryId.isNotEmpty) {
            _countryIpMap.putIfAbsent(countryId, () => []).add(network);
            validEntries++;
          }
        }
      }

      if (_countryIpMap.isNotEmpty) {
        debugPrint("成功从CSV加载 ${_countryIpMap.length} 个国家的IP地址，共 $validEntries 条记录");
        
        _countryIpMap.forEach((country, ips) {
          debugPrint("  $country: ${ips.length} 个IP");
        });
        
        final countryNames = _countryIpMap.keys
            .map((code) => countryLocations[code] ?? code)
            .toSet()
            .toList()
          ..sort();
        
        if (!countryNames.contains('ALL')) {
          countryNames.insert(0, 'ALL');
        }
        
        onCountryListLoaded?.call(countryNames);
        debugPrint("国家列表已加载: $countryNames");
      } else {
        debugPrint("未能从CSV加载任何IP地址，将使用内置列表");
        _loadBuiltInIps();
      }
    } catch (e) {
      debugPrint("加载IP地址时发生错误: $e, 将使用内置列表");
      _loadBuiltInIps();
    }
  }

  void _loadBuiltInIps() {
    _countryIpMap = {
      'US': ['1.0.0.0/24', '8.8.8.0/24'],
      'CN': ['114.242.0.0/16', '223.5.5.0/24'],
      'IN': ['157.32.0.0/11', '157.49.0.0/16'],
    };
    final countryNames = _countryIpMap.keys
        .map((code) => countryLocations[code] ?? code)
        .toSet()
        .toList()
      ..sort();
    onCountryListLoaded?.call(countryNames);
    debugPrint("已加载内置IP地址列表");
  }

  (String, String)? _getNextIp(String country) {
    if (_countryIpMap.isEmpty) return null;

    List<String> ips;
    String currentCountryCode;

    if (country == 'ALL') {
      final countryCodes = _countryIpMap.keys.toList();
      if (countryCodes.isEmpty) return null;

      if (_currentCountryIndex >= countryCodes.length) {
        _currentCountryIndex = 0;
      }

      currentCountryCode = countryCodes[_currentCountryIndex];
      ips = _countryIpMap[currentCountryCode] ?? [];

      if (ips.isEmpty) {
        _currentCountryIndex = (_currentCountryIndex + 1) % countryCodes.length;
        _currentCountryIpIndex = 0;
        return _getNextIp(country);
      }
    } else {
      currentCountryCode = country;
      ips = _countryIpMap[country] ?? [];
      if (ips.isEmpty) {
        debugPrint('国家 $country 没有可用的IP地址');
        return null;
      }
    }

    if (_currentCountryIpIndex >= ips.length) {
      _currentCountryIpIndex = 0;

      if (country == 'ALL') {
        _currentCountryIndex = (_currentCountryIndex + 1) % _countryIpMap.keys.length;
        debugPrint('完成当前国家，移动到下一个国家...');
        return _getNextIp(country);
      }
    }

    final ip = ips[_currentCountryIpIndex];
    debugPrint('选择IP: $ip (国家: $currentCountryCode, 索引: $_currentCountryIpIndex, 总数: ${ips.length})');
    _currentCountryIpIndex++;
    return (ip, currentCountryCode);
  }

  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isWeb,
    required bool isLoop,
    required String country,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    _sentCount = 0;
    _dataSentInMB = 0.0;
    _dataSentInBytes = 0;
    _currentIpIndex = 0;
    _currentCountryIndex = 0;
    _currentCountryIpIndex = 0;

    try {
      if (isWeb) {
        await _startSendingWeb(files: files, isLoop: isLoop, country: country);
      } else {
        await _startSendingIO(files: files, isLoop: isLoop, country: country);
      }
    } catch (e) {
      debugPrint('发送过程中发生错误: $e');
    } finally {
      if (_isRunning) {
        _isRunning = false;
        onStopped();
      }
    }
  }

  InternetAddress _getBroadcastAddress(String cidr) {
    try {
      final parts = cidr.split('/');
      if (parts.length != 2) {
        // 如果没有子网掩码，尝试解析为单个IP地址
        try {
          return InternetAddress(parts[0]);
        } catch (e) {
          debugPrint('无法解析IP地址 "${parts[0]}": $e');
          return InternetAddress('8.8.8.8'); // 回退到Google DNS
        }
      }

      final baseIp = parts[0];
      final prefix = int.tryParse(parts[1]);
      
      if (prefix == null || prefix < 0 || prefix > 32) {
        debugPrint('无效的子网前缀: ${parts[1]}，使用基础IP');
        return InternetAddress(baseIp);
      }

      // 对于较大的子网（/24及以上），直接使用基础IP避免广播风暴
      if (prefix >= 24) {
        return InternetAddress(baseIp);
      }

      final ip = InternetAddress(baseIp);
      if (ip.type != InternetAddressType.IPv4) {
        return ip;
      }

      final ipData = ByteData.view(ip.rawAddress.buffer);
      final ipInt = ipData.getUint32(0);

      final hostBits = 32 - prefix;
      if (hostBits > 31) return ip;
      final hostMask = (1 << hostBits) - 1;
      
      final broadcastInt = ipInt | hostMask;

      final broadcastBytes = Uint8List(4);
      final broadcastData = ByteData.view(broadcastBytes.buffer);
      broadcastData.setUint32(0, broadcastInt);

      return InternetAddress.fromRawAddress(broadcastBytes);
    } catch (e) {
      debugPrint('无法解析CIDR "$cidr": $e，使用默认地址');
      // 回退到一些知名的公共DNS服务器
      final fallbackIps = ['8.8.8.8', '1.1.1.1', '208.67.222.222'];
      final randomIp = fallbackIps[Random().nextInt(fallbackIps.length)];
      return InternetAddress(randomIp);
    }
  }

  /// 验证IP地址是否可达
  Future<bool> _isIpReachable(InternetAddress address) async {
    try {
      final socket = await Socket.connect(address, 80, timeout: const Duration(seconds: 10));
      socket.destroy();
      return true;
    } catch (e) {
      // 尝试ping替代方案
      try {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        final testData = utf8.encode('PING_TEST');
        final sentBytes = socket.send(testData, address, 53); // DNS端口
        socket.close();
        return sentBytes > 0;
      } catch (e2) {
        return false;
      }
    }
  }

  /// 获取最佳发送端口
  List<int> _getOptimalPorts() {
    // 按优先级排序的端口列表
    return [
      8080,  // HTTP备用端口
      9000,  // 通用应用端口
      5353,  // mDNS
      4567,  // 自定义应用端口
      1900,  // UPnP
      8888,  // 备用HTTP端口
      7777,  // 通用端口
    ];
  }

  Future<void> _startSendingIO({
    required List<PlatformFile> files,
    required bool isLoop,
    required String country,
  }) async {
    debugPrint('IO端全球发送服务已启动 - 真实网络传输模式');
    debugPrint('全球发送模式: ${country == "ALL" ? "所有国家" : country}');

    RawDatagramSocket? socket;
    
    try {
      // 创建UDP套接字用于真实发送
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      debugPrint('UDP套接字创建成功，开始真实网络传输');
      
      do {
        for (final file in files) {
          if (!_isRunning) break;
          
          final filePath = file.path;
          if (filePath == null) {
            debugPrint('文件 ${file.name} 没有有效路径，跳过');
            continue;
          }

          final ioFile = File(filePath);
          if (!await ioFile.exists()) {
            debugPrint('文件 ${file.name} 不存在，跳过');
            continue;
          }

          debugPrint('📤 真实发送文件: ${file.name}');

          final ipData = _getNextIp(country);
          if (ipData == null) {
            debugPrint('没有可用的IP地址，停止发送');
            break;
          }

          final (ipCidr, currentCountryCode) = ipData;
          debugPrint('正在真实发送到国家: $currentCountryCode, CIDR: $ipCidr');

          try {
            // 获取目标广播地址
            final targetAddress = _getBroadcastAddress(ipCidr);
            final targetPorts = _getOptimalPorts();
            
            final fileSize = await ioFile.length();
            final fileName = file.name;
            
            debugPrint('📊 文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
            debugPrint('🔢 预期数据块数: ${(fileSize / 1024).ceil()}');
            debugPrint('🌐 目标地址: ${targetAddress.address}');
            
            // 发送文件元数据
            final metaData = jsonEncode({
              'type': 'FILE_START',
              'name': fileName,
              'size': fileSize,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'country': currentCountryCode,
              'chunks': (fileSize / 8192).ceil(),
            });
            final metaDataBytes = utf8.encode(metaData);
            
            // 向多个端口发送元数据
            bool metaDataSent = false;
            for (final port in targetPorts) {
              try {
                final sentBytes = socket.send(metaDataBytes, targetAddress, port);
                if (sentBytes > 0) {
                  metaDataSent = true;
                  debugPrint('✓ 成功发送元数据到 ${targetAddress.address}:$port ($sentBytes 字节)');
                  break; // 成功发送到一个端口就够了
                }
              } catch (e) {
                debugPrint('✗ 发送元数据到端口 $port 失败: $e');
              }
            }
            
            if (!metaDataSent) {
              debugPrint('⚠️ 警告: 元数据发送失败，但继续尝试发送文件数据');
            }
            
            // 分块读取并发送文件
            const chunkSize = 1024; // 1KB 块大小
            final expectedChunks = (fileSize / chunkSize).ceil();
            debugPrint('📊 文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
            debugPrint('🔢 预期数据块数: $expectedChunks');
            
            final fileStream = ioFile.openRead();
            
            List<int> buffer = [];
            int totalSent = 0;
            int chunkIndex = 0;
            int successfulChunks = 0;
            int failedChunks = 0;
            
            await for (final chunk in fileStream) {
              if (!_isRunning) break;

              buffer.addAll(chunk);
              
              while (buffer.length >= chunkSize && _isRunning) {
                final dataToSend = buffer.sublist(0, chunkSize);
                buffer = buffer.sublist(chunkSize);
                
                // 创建数据包头
                final chunkHeader = jsonEncode({
                  'type': 'FILE_CHUNK',
                  'index': chunkIndex,
                  'size': dataToSend.length,
                  'fileName': fileName,
                  'country': currentCountryCode,
                });
                final headerBytes = utf8.encode(chunkHeader);
                final separator = utf8.encode('|||'); // 分隔符
                final fullPacket = [...headerBytes, ...separator, ...dataToSend];
                
                // 尝试发送到多个端口
                bool chunkSent = false;
                int attempts = 0;
                const maxAttempts = 3;
                
                while (!chunkSent && attempts < maxAttempts && _isRunning) {
                  for (final port in targetPorts) {
                    try {
                      final sentBytes = socket.send(fullPacket, targetAddress, port);
                      if (sentBytes > 0) {
                        chunkSent = true;
                        successfulChunks++;
                        totalSent += dataToSend.length;
                        _dataSentInBytes += dataToSend.length;
                        _dataSentInMB = _dataSentInBytes / (1024 * 1024);
                        onDataSent(_dataSentInMB);
                        
                        if (chunkIndex % 100 == 0) {
                          debugPrint('✓ 成功发送数据块 $chunkIndex 到 $currentCountryCode (${targetAddress.address}:$port)');
                        }
                        break;
                      }
                    } catch (e) {
                      if (attempts == 0) { // 只在第一次尝试时打印错误
                        debugPrint('✗ 发送数据块 $chunkIndex 到端口 $port 失败: $e');
                      }
                    }
                  }
                  
                  if (!chunkSent) {
                    attempts++;
                    if (attempts < maxAttempts) {
                      await Future.delayed(Duration(milliseconds: 200 * attempts));
                    }
                  }
                }
                
                if (!chunkSent) {
                  failedChunks++;
                  debugPrint('⚠️ 警告: 数据块 $chunkIndex 在 $maxAttempts 次尝试后仍发送失败');
                }
                
                chunkIndex++;
                
                // 进度报告 - 更频繁的进度更新
                if (chunkIndex % 50 == 0) {
                  final progress = (totalSent / fileSize * 100).toStringAsFixed(1);
                  final successRate = (successfulChunks / chunkIndex * 100).toStringAsFixed(1);
                  debugPrint('📊 全球发送进度: $chunkIndex/$expectedChunks 块, ${_dataSentInMB.toStringAsFixed(2)} MB ($progress%), 成功率: $successRate%');
                }
                
                // 控制发送速率，避免网络拥塞
                await Future.delayed(const Duration(milliseconds: 50));
              }
            }
            
            // 发送剩余数据
            if (buffer.isNotEmpty && _isRunning) {
              final chunkHeader = jsonEncode({
                'type': 'FILE_CHUNK',
                'index': chunkIndex,
                'size': buffer.length,
                'fileName': fileName,
                'country': currentCountryCode,
              });
              final headerBytes = utf8.encode(chunkHeader);
              final separator = utf8.encode('|||');
              final fullPacket = [...headerBytes, ...separator, ...buffer];
              
              bool lastChunkSent = false;
              for (final port in targetPorts) {
                try {
                  final sentBytes = socket.send(fullPacket, targetAddress, port);
                  if (sentBytes > 0) {
                    lastChunkSent = true;
                    successfulChunks++;
                    totalSent += buffer.length;
                    _dataSentInBytes += buffer.length;
                    _dataSentInMB = _dataSentInBytes / (1024 * 1024);
                    onDataSent(_dataSentInMB);
                    debugPrint('✓ 成功发送最后数据块到 $currentCountryCode');
                    break;
                  }
                } catch (e) {
                  debugPrint('✗ 发送最后数据块失败: $e');
                }
              }
              
              if (!lastChunkSent) {
                failedChunks++;
              }
              chunkIndex++;
            }
            
            // 发送文件结束标记
            final endMarker = jsonEncode({
              'type': 'FILE_END',
              'fileName': fileName,
              'totalChunks': chunkIndex,
              'totalSize': fileSize,
              'successfulChunks': successfulChunks,
              'failedChunks': failedChunks,
              'country': currentCountryCode,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
            final endMarkerBytes = utf8.encode(endMarker);
            
            bool endMarkerSent = false;
            for (final port in targetPorts) {
              try {
                final sentBytes = socket.send(endMarkerBytes, targetAddress, port);
                if (sentBytes > 0) {
                  endMarkerSent = true;
                  debugPrint('✓ 成功发送文件结束标记到 ${targetAddress.address}:$port');
                  break;
                }
              } catch (e) {
                debugPrint('✗ 发送文件结束标记失败: $e');
              }
            }
            
            _sentCount++;
            onProgress(_sentCount);
            
            final successRate = (successfulChunks / chunkIndex * 100).toStringAsFixed(1);
            final actualSentMB = (totalSent / 1024 / 1024).toStringAsFixed(2);
            
            debugPrint('🎉 文件 ${file.name} 真实发送完成到国家: $currentCountryCode');
            debugPrint('📈 发送统计: 成功块数 $successfulChunks/$chunkIndex, 成功率: $successRate%');
            debugPrint('📊 实际发送: ${actualSentMB} MB, 总发送文件数: $_sentCount');
            debugPrint('🌐 目标地址: ${targetAddress.address}, 累计发送: ${_dataSentInMB.toStringAsFixed(2)} MB');
            
          } catch (e) {
            debugPrint('❌ 发送文件到国家 $currentCountryCode 时发生错误: $e');
          }
        }
      } while (_isRunning && isLoop);
      
    } catch (e) {
      debugPrint('❌ 创建全球发送socket时发生错误: $e');
    } finally {
      socket?.close();
      debugPrint('🔚 IO端全球发送服务已停止 - 真实网络传输结束');
    }
  }

  Future<void> _startSendingWeb({
    required List<PlatformFile> files,
    required bool isLoop,
    required String country,
  }) async {
    debugPrint('Web端全球发送服务已启动');
    final backendUrl = await AppSettings.getBackendUrl();
    final url = Uri.parse('$backendUrl/send-global');

    do {
      for (final file in files) {
        if (!_isRunning) break;
        final ipData = _getNextIp(country);
        if (ipData == null) {
          debugPrint('没有更多IP地址可发送');
          break;
        }
        final (ipCidr, _) = ipData;

        try {
          final request = http.MultipartRequest('POST', url)
            ..fields['fileName'] = file.name
            ..fields['fileSize'] = file.size.toString()
            ..fields['ip'] = ipCidr;

          final multipartFile = http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          );
          request.files.add(multipartFile);

          final client = http.Client();
          final response = await sendMultipartRequestWithProgress(
            request,
            client,
            onProgress: (sent, total) {
              final sentMB = sent / (1024 * 1024);
              final totalMB = total / (1024 * 1024);
              debugPrint('上传进度: ${sentMB.toStringAsFixed(2)}MB / ${totalMB.toStringAsFixed(2)}MB');
              onDataSent(_dataSentInMB + sentMB);
            },
          );

          if (response.statusCode == 200) {
            _sentCount++;
            _dataSentInMB += file.size / (1024 * 1024);
            onProgress(_sentCount);
            onDataSent(_dataSentInMB);
            debugPrint('文件 ${file.name} 已成功提交至后端处理。');
          } else {
            debugPrint('后端在处理文件 ${file.name} 时返回错误，状态码: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('因网络或配置错误，发送文件 ${file.name} 失败: $e');
        }
      }
    } while (_isRunning && isLoop);
    debugPrint('Web端全球发送服务已停止');
  }

  void stopSending() {
    _isRunning = false;
  }

  List<String> getCountryCodes() {
    return _countryIpMap.keys.toList()..sort();
  }
}