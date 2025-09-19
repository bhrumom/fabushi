import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:global_dharma_sharing/services/app_settings.dart';
import '../config/country_servers.dart';
import '../config/dharma_assets.dart';

import '../config/unified_config.dart';
import 'app_settings.dart';
import '../core/locations.dart';
import '../utils/http_with_progress.dart';

// 定义发送状态的枚举
enum TransferStatus {
  idle,
  running,
  paused,
  stopped,
  completed,
}

// 定义进度更新的数据模型
class TransferProgress {
  final TransferStatus status;
  final int totalFiles;
  final int completedFiles;
  final int totalCountries;
  final int completedCountriesInCurrentFile;
  final String currentFile;
  final String logMessage;

  // 计算当前文件的发送进度
  double get fileProgress => totalCountries > 0 ? (completedCountriesInCurrentFile / totalCountries) * 100 : 0;
  
  // 计算总体发送进度
  double get overallProgress {
    if (totalFiles == 0) return 0;
    // 基础进度是已完成的文件数
    double baseProgress = (completedFiles / totalFiles) * 100;
    // 加上当前正在处理的文件的进度
    double currentFileProgress = (1 / totalFiles) * fileProgress;
    return baseProgress + currentFileProgress;
  }

  TransferProgress({
    this.status = TransferStatus.idle,
    this.totalFiles = 0,
    this.completedFiles = 0,
    this.totalCountries = 0,
    this.completedCountriesInCurrentFile = 0,
    this.currentFile = '',
    this.logMessage = '',
  });
}

/// 全球法布施发送服务
///
/// 该服务移植自原生Web应用的 `service-worker.js` 和 `global-country-servers.js` 的核心逻辑。
/// 它负责管理素材队列，并以可控的方式将它们发送到全球各地的服务器。
class GlobalTransferService {
  // 使用 StreamController 来广播发送进度
  final _progressController = StreamController<TransferProgress>.broadcast();
  Stream<TransferProgress> get progressStream => _progressController.stream;

  TransferStatus _status = TransferStatus.idle;
  List<Map<String, String>> _assetQueue = [];
  bool _loopMode = false;
  int _concurrency = 5;
  bool _stopSignal = false;
  // final _queueLock = Lock(); // Temporarily removed due to build issue

  /// 开始全球发送流程
  void start({required List<Map<String, String>> assets, bool loop = false, int concurrency = 5}) {
    if (_status == TransferStatus.running) {
      _log("发送任务已在运行中。");
      return;
    }
    _status = TransferStatus.running;
    _stopSignal = false;
    _loopMode = loop;
    _concurrency = concurrency > 0 ? concurrency : 1;
    _assetQueue = List.from(assets); // 使用传入的素材队列
    _log("🚀 发送服务已启动 (并发: $_concurrency)，准备发送 ${_assetQueue.length} 个文件...");
    _processQueue();
  }

  /// 停止发送流程
  void stop() {
    if (_status == TransferStatus.running) {
      _stopSignal = true;
      _status = TransferStatus.stopped;
      _log("⏹️ 收到停止指令，将在当前任务完成后安全停止。");
    }
  }

  /// 内部日志记录并通过Stream发送
  void _log(String message, {int? completedFiles, String? currentFile, int? completedCountries, int? totalCountries}) {
    debugPrint(message); // 在控制台打印日志
    _progressController.add(TransferProgress(
      status: _status,
      logMessage: message,
      totalFiles: _assetQueue.length,
      completedFiles: completedFiles ?? 0,
      currentFile: currentFile ?? '',
      completedCountriesInCurrentFile: completedCountries ?? 0,
      totalCountries: totalCountries ?? GLOBAL_COUNTRY_SERVERS.length,
    ));
  }

  /// 核心处理队列的异步方法
  Future<void> _processQueue() async {
    int completedFileCount = 0;
    
    do {
      for (int i = 0; i < _assetQueue.length; i++) {
        if (_stopSignal) break;

        final asset = _assetQueue[i];
        final fileName = asset['name']!;
        
        _log("📥 [${i + 1}/${_assetQueue.length}] 开始处理文件: $fileName", completedFiles: i, currentFile: fileName);

        await _sendAssetToAllCountries(asset, (completed, total) {
          // 更新单个文件的发送进度
          _progressController.add(TransferProgress(
            status: _status,
            totalFiles: _assetQueue.length,
            completedFiles: i,
            totalCountries: total,
            completedCountriesInCurrentFile: completed,
            currentFile: fileName,
            logMessage: "国家进度: $completed/$total",
          ));
        });

        if (_stopSignal) break;

        completedFileCount = i + 1;
        _log("✅ 文件 $fileName 处理完成。", completedFiles: completedFileCount, currentFile: fileName);
      }

      if (_stopSignal) {
        _log("发送任务已停止。", completedFiles: completedFileCount);
        break;
      }

      if (_loopMode) {
        _log("🔄 本轮循环完成，15秒后开始下一轮...", completedFiles: _assetQueue.length);
        await Future.delayed(const Duration(seconds: 15));
        completedFileCount = 0; // 重置计数
      }

    } while (_loopMode && !_stopSignal);

    if (!_stopSignal) {
      _status = TransferStatus.completed;
      _log("🎉 所有文件发送任务已完成。", completedFiles: _assetQueue.length);
    }
    
    _status = TransferStatus.idle;
  }

  /// 将单个素材发送到所有国家
  Future<void> _sendAssetToAllCountries(Map<String, String> asset, Function(int, int) onProgress) async {
    final countryCodes = GLOBAL_COUNTRY_SERVERS.keys.toList();
    int completedCount = 0;

    try {
      _log("正在准备素材: ${asset['name']!}...");
      final data = await _getAssetData(asset);
      if (data == null) {
        _log("❌ 获取素材 ${asset['name']} 内容失败，跳过。");
        return;
      }
      _log("素材准备就绪: ${asset['name']!} (${(data.lengthInBytes / 1024).toStringAsFixed(2)} KB)");

      var futures = <Future>[];
      final countryQueue = Queue<String>.from(countryCodes);

      // 使用 Worker Pool 模式来控制并发
      for (int i = 0; i < _concurrency; i++) {
        futures.add(_countryWorker(countryQueue, data, asset['name']!, (success) {
          completedCount++;
          onProgress(completedCount, countryCodes.length);
        }));
      }
      
      await Future.wait(futures);

    } catch (e) {
      _log("❌ 发送素材时发生错误: $e");
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
      }
    }
  }

  /// 并发处理国家的 "Worker"
  Future<void> _countryWorker(Queue<String> queue, Uint8List data, String fileName, Function(bool) onComplete) async {
    while (queue.isNotEmpty && !_stopSignal) {
      String? countryCode;
      try {
        // Not perfectly race-safe, but avoids the Lock build issue for now.
        if (queue.isNotEmpty) {
          countryCode = queue.removeFirst();
        }
      } catch (e) {
        // Another worker probably took the last item.
        break;
      }

      if (countryCode == null) continue;

      final servers = GLOBAL_COUNTRY_SERVERS[countryCode] ?? [];
      final countryName = COUNTRY_NAMES[countryCode!] ?? countryCode;
      bool success = false;

      for (final serverUrl in servers) {
        if (_stopSignal) break;
        try {
          // 简化HTTP POST请求
          await http.post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/octet-stream'},
            body: data,
          ).timeout(const Duration(seconds: 15));
          
          // 假设请求发出即视为成功
          _log("✅ 数据已尝试发送到 $countryName (服务器: $serverUrl)");
          success = true;
          break; // 成功后不再尝试其他服务器
        } catch (e) {
          _log("⚠️ 向 $countryName 的服务器 $serverUrl 发送失败: ${e.toString()}");
        }
      }
      onComplete(success);
    }
  }

  /// 获取素材数据
  Future<Uint8List?> _getAssetData(Map<String, String> asset) async {
    final type = asset['type'];
    final path = asset['path']!;

    try {
      if (type == 'built_in') {
        // 从应用内 assets 加载
        final byteData = await rootBundle.load(path);
        return byteData.buffer.asUint8List();
      } else if (type == 'r2-asset') {
        // 从 Cloudflare R2 worker 下载
        final baseUrl = await AppSettings.getBackendUrl();
        final url = '$baseUrl/r2?file=${Uri.encodeComponent(path)}';
        _log("开始从 R2 下载: $url");
        final response = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 10)); // 10分钟超时
        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          _log("❌ R2 文件下载失败: ${response.statusCode}");
          return null;
        }
      }
    } catch (e) {
      _log("❌ 获取素材数据时发生异常: $e");
      return null;
    }
    return null;
  }

  /// 清理资源
  void dispose() {
    _progressController.close();
  }
}