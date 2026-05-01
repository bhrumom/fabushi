import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../screens/asset_screen.dart';
import '../core/config/app_config.dart';
import '../services/downloaded_assets_service.dart';
import '../services/download_manager.dart';
import '../services/real_global_send_service.dart';
import '../services/ip_location_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/download_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

enum TransferStatus { idle, transferring, completed, error }

/// 优化的文件传输模型 - 极致性能版本
class FileTransferModel extends ChangeNotifier {
  // 传输模式状态
  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  double _sendRateMB = 1.0;

  // 文件相关
  List<PlatformFile> _selectedFiles = [];
  List<String> _countryList = ['ALL'];

  // 传输状态
  bool _isTransferring = false;
  TransferStatus _status = TransferStatus.idle;

  // 统计数据
  int _globalSentCount = 0;
  double _globalDataSentMB = 0.0;

  // 服务
  RealGlobalSendService? _realGlobalSendService;
  List<CountrySendStatus> _countryStatuses = [];
  String _currentLog = '';

  final DownloadedAssetsService _downloadedAssetsService =
      DownloadedAssetsService();
  final DownloadManager _downloadManager = DownloadManager();
  Map<String, String> _assetToTaskMap = {};
  final IPLocationService _ipLocationService = IPLocationService();

  bool _isDisposed = false;

  // 首页属性
  PlatformFile? get selectedFile =>
      _selectedFiles.isNotEmpty ? _selectedFiles.first : null;
  double _progress = 0.0;
  double get progress => _progress;

  // 性能优化：批量更新定时器
  Timer? _batchUpdateTimer;
  bool _hasPendingUpdate = false;

  // 性能优化：持久化队列
  final List<Future<void> Function()> _persistQueue = [];
  bool _isPersisting = false;

  FileTransferModel() {
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    await _loadPersistedState();
    if (_isTransferring) {
      _isTransferring = false;
      _schedulePersist(_persistTransferState);
      debugPrint('🔄 应用启动，清除传输状态');
      _scheduleNotify();
    }
  }

  // Getters
  bool get isGlobalSendEnabled => _isGlobalSendEnabled;
  bool get isLooping => _isLooping;
  double get sendRateMB => _sendRateMB;
  List<PlatformFile> get selectedFiles => _selectedFiles;
  List<String> get countryList => _countryList;
  bool get isTransferring => _isTransferring;
  TransferStatus get status => _status;
  bool get hasFiles => _selectedFiles.isNotEmpty;
  int get globalSentCount => _globalSentCount;
  double get globalDataSentMB => _globalDataSentMB;
  List<CountrySendStatus> get countryStatuses => _countryStatuses;
  String get currentLog => _currentLog;

  /// 性能优化：批量通知更新（防抖）
  void _scheduleNotify() {
    if (_hasPendingUpdate) return;
    _hasPendingUpdate = true;

    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 16), () {
      if (!_isDisposed) {
        _hasPendingUpdate = false;
        notifyListeners();
      }
    });
  }

  /// 性能优化：异步持久化队列
  void _schedulePersist(Future<void> Function() persistFunc) {
    _persistQueue.add(persistFunc);
    if (!_isPersisting) {
      _processPersistQueue();
    }
  }

  Future<void> _processPersistQueue() async {
    if (_isPersisting || _persistQueue.isEmpty) return;
    _isPersisting = true;

    while (_persistQueue.isNotEmpty) {
      final func = _persistQueue.removeAt(0);
      try {
        await func();
      } catch (e) {
        debugPrint('持久化失败: $e');
      }
      // 避免阻塞主线程
      await Future.delayed(Duration.zero);
    }

    _isPersisting = false;
  }

  void startTransfer() {
    _isTransferring = true;
    _progress = 0.0;
    _scheduleNotify();
  }

  void updateProgressValue(double value) {
    _progress = value;
    _scheduleNotify();
  }

  void completeTransfer() {
    _isTransferring = false;
    _progress = 0.0;
    _globalSentCount++;
    _scheduleNotify();
  }

  void setGlobalSendEnabled(bool enabled) {
    _isGlobalSendEnabled = enabled;
    notifyListeners();
  }

  void setLooping(bool looping) {
    _isLooping = looping;
    notifyListeners();
  }

  void setSendRateMB(double rateMB) {
    _sendRateMB = rateMB.clamp(0.1, 5.0);
    notifyListeners();
  }

  void setCountryList(List<String> countries) {
    _countryList = countries;
    notifyListeners();
  }

  Future<void> selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );

      if (result != null) {
        _selectedFiles.addAll(result.files);
        notifyListeners();
        debugPrint('已选择 ${result.files.length} 个文件');
      }
    } catch (e) {
      debugPrint('选择文件失败: $e');
    }
  }

  Future<void> selectBuiltInAssets(BuildContext context) async {
    final selectedAssets = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AssetScreen()),
    );

    if (selectedAssets != null &&
        selectedAssets is List &&
        selectedAssets.isNotEmpty) {
      final List<String> assetPaths = selectedAssets
          .map((asset) => asset.toString())
          .toList();
      _downloadSelectedAssets(context, assetPaths);
    }
  }

  Future<void> _downloadSelectedAssets(
    BuildContext context,
    List<String> assetPaths,
  ) async {
    try {
      await _downloadedAssetsService.initialize();

      final List<String> needDownloadAssets = [];
      final List<String> alreadyDownloadedAssets = [];

      for (String assetPath in assetPaths) {
        if (_downloadedAssetsService.isAssetDownloaded(assetPath)) {
          alreadyDownloadedAssets.add(assetPath);
        } else {
          needDownloadAssets.add(assetPath);
        }
      }

      String message = '';
      if (alreadyDownloadedAssets.isNotEmpty && needDownloadAssets.isNotEmpty) {
        message =
            '发现 ${alreadyDownloadedAssets.length} 个素材已下载，将下载 ${needDownloadAssets.length} 个新素材';
      } else if (alreadyDownloadedAssets.isNotEmpty) {
        message = '所有 ${alreadyDownloadedAssets.length} 个素材都已下载，将直接复用';
      } else if (needDownloadAssets.isNotEmpty) {
        message = '开始下载 ${needDownloadAssets.length} 个素材';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (alreadyDownloadedAssets.isNotEmpty) {
        await _reuseDownloadedAssets(context, alreadyDownloadedAssets);
      }

      if (needDownloadAssets.isNotEmpty) {
        for (String assetPath in needDownloadAssets) {
          await _downloadSingleAsset(context, assetPath);
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('所有素材处理完成')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reuseDownloadedAssets(
    BuildContext context,
    List<String> assetPaths,
  ) async {
    try {
      for (String assetPath in assetPaths) {
        final fileName = assetPath.split('/').last;

        if (kIsWeb) {
          final fileData = await _getFileFromWebStorage(fileName);
          if (fileData != null) {
            final fileInfo = PlatformFile(
              name: fileName,
              size: fileData.length,
              path: null,
              bytes: Uint8List.fromList(fileData),
            );
            addFiles([fileInfo]);
            debugPrint('Web平台复用已下载素材: $fileName');
          }
        } else {
          final Directory? dir;
          if (Platform.isAndroid) {
            dir = await getExternalStorageDirectory();
          } else {
            dir = await getApplicationDocumentsDirectory();
          }

          if (dir != null) {
            final filePath = '${dir.path}/$fileName';
            final file = File(filePath);

            if (await file.exists()) {
              final fileInfo = PlatformFile(
                name: fileName,
                size: await file.length(),
                path: filePath,
              );
              addFiles([fileInfo]);
              debugPrint('本地平台复用已下载素材: $fileName');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('复用已下载素材失败: $e');
      rethrow;
    }
  }

  Future<List<int>?> _getFileFromWebStorage(String fileName) async {
    try {
      if (!kIsWeb) return null;

      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);

      final fileInfo = savedFiles.firstWhere(
        (f) => f['name'] == fileName,
        orElse: () => null,
      );

      if (fileInfo == null) return null;

      final fileDataStr = html.window.localStorage['file_$fileName'];
      if (fileDataStr == null) return null;

      return base64.decode(fileDataStr);
    } catch (e) {
      debugPrint('从Web存储获取文件失败: $e');
      return null;
    }
  }

  Future<void> _downloadSingleAsset(
    BuildContext context,
    String assetPath,
  ) async {
    try {
      final bool isStaticFile =
          assetPath.contains('乾隆大藏经') ||
          assetPath.contains('房山石经陀罗尼') ||
          assetPath.contains('咒语') ||
          assetPath.contains('经文');

      final String url;
      if (isStaticFile) {
        final cleanAssetPath = assetPath.startsWith('web/')
            ? assetPath.substring(4)
            : assetPath;

        if (kIsWeb) {
          url = '/$cleanAssetPath';
        } else {
          final String baseUrl = AppConfig.isProduction
              ? AppConfig.cloudflareWorkerProdUrl
              : AppConfig.cloudflareWorkerDevUrl;
          url = '$baseUrl/$cleanAssetPath';
        }
      } else {
        url =
            '${AppConfig.currentBackendUrl}/r2?file=${Uri.encodeComponent(assetPath)}';
      }

      debugPrint('下载素材URL: $url');

      final fileName = assetPath.split('/').last;

      final existingTaskId = _assetToTaskMap[assetPath];
      if (existingTaskId != null) {
        final task = _downloadManager.tasks[existingTaskId];
        if (task != null && task.status == DownloadStatus.paused) {
          await _downloadManager.resumeDownload(existingTaskId);
          return;
        }
      }

      final taskId = await _downloadManager.createTask(
        url,
        fileName,
        assetPath,
      );
      _assetToTaskMap[assetPath] = taskId;

      _showDownloadProgressDialog(context, taskId, fileName);

      await _downloadManager.startDownload(taskId);
    } catch (e) {
      debugPrint('下载素材失败: $e');
      rethrow;
    }
  }

  void _showDownloadProgressDialog(
    BuildContext context,
    String taskId,
    String fileName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        taskId: taskId,
        downloadManager: _downloadManager,
        onComplete: () async {
          debugPrint('📥 下载完成回调开始执行');

          try {
            final task = _downloadManager.tasks[taskId];
            if (task != null && task.status == DownloadStatus.completed) {
              final fileName = task.fileName;
              debugPrint('📁 处理下载完成的文件: $fileName');

              if (kIsWeb) {
                final fileData = await _downloadManager.getDownloadedFile(
                  fileName,
                );
                if (fileData != null) {
                  final fileInfo = PlatformFile(
                    name: fileName,
                    size: fileData.length,
                    path: null,
                    bytes: fileData,
                  );

                  addFiles([fileInfo]);
                  await _downloadedAssetsService.markAssetAsDownloaded(
                    task.assetPath,
                  );
                  await Future.delayed(Duration(milliseconds: 200));
                }
              } else {
                final Directory? dir;
                if (Platform.isAndroid) {
                  dir = await getExternalStorageDirectory();
                } else {
                  dir = await getApplicationDocumentsDirectory();
                }

                if (dir != null) {
                  final filePath = '${dir.path}/$fileName';
                  final file = File(filePath);

                  if (await file.exists()) {
                    final fileInfo = PlatformFile(
                      name: fileName,
                      size: await file.length(),
                      path: filePath,
                    );

                    addFiles([fileInfo]);
                    await _downloadedAssetsService.markAssetAsDownloaded(
                      task.assetPath,
                    );
                    await Future.delayed(Duration(milliseconds: 200));
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('❌ 下载完成处理出错: $e');
          } finally {
            _assetToTaskMap.remove(taskId);

            if (!_isDisposed && context.mounted) {
              try {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                debugPrint('⚠️ 关闭对话框时出错: $e');
              }
            }
          }
        },
      ),
    );
  }

  void addFiles(List<PlatformFile> files) {
    _selectedFiles.addAll(files);
    notifyListeners();
  }

  void removeFile(PlatformFile file) {
    _selectedFiles.remove(file);
    notifyListeners();
  }

  void clearFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }

  String getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return '图片';
      case 'mp4':
      case 'avi':
      case 'mov':
        return '视频';
      case 'mp3':
      case 'wav':
      case 'flac':
        return '音频';
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return '文档';
      case 'txt':
        return '文本';
      default:
        return '文件';
    }
  }

  String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Function(
    double,
    double,
    double,
    double, {
    String? fromLabel,
    String? toLabel,
  })?
  _onTransferBeam;

  void setTransferBeamCallback(
    Function(
      double,
      double,
      double,
      double, {
      String? fromLabel,
      String? toLabel,
    })?
    callback,
  ) {
    _onTransferBeam = callback;
  }

  Future<void> startGlobalTransfer() async {
    if (_isTransferring || _selectedFiles.isEmpty) return;

    _isTransferring = true;
    _status = TransferStatus.transferring;
    _schedulePersist(_persistTransferState);
    _scheduleNotify();

    try {
      debugPrint('🚀 开始真实全球传输 - 文件数量: ${_selectedFiles.length}');

      await _initializeRealGlobalSendService();
      await _realGlobalSendService?.startSending(
        files: _selectedFiles,
        isLoop: _isLooping,
      );
      await _uploadPendingData();
      debugPrint('✅ 传输完成，数据已上传');
    } catch (e) {
      debugPrint('❌ 传输失败: $e');
      _status = TransferStatus.error;
      _isTransferring = false;
      _schedulePersist(_persistTransferState);
      _scheduleNotify();
    }
  }

  void stopTransfer() {
    if (!_isTransferring) return;

    _isTransferring = false;
    _status = TransferStatus.idle;

    _realGlobalSendService?.stopSending();

    _schedulePersist(_persistTransferState);
    debugPrint('🛑 传输已停止');
    _scheduleNotify();
  }

  void _onTransferCompleted() {
    _isTransferring = false;
    _status = TransferStatus.completed;
    _schedulePersist(_persistTransferState);
    _scheduleNotify();
  }

  Future<void> _initializeRealGlobalSendService() async {
    double? userLat;
    double? userLng;

    try {
      final userLocation = await _ipLocationService.getCurrentLocation();
      if (userLocation != null) {
        userLat = userLocation.latitude;
        userLng = userLocation.longitude;
        debugPrint(
          '📍 传输服务使用用户位置: ${userLocation.country}, ${userLocation.city}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ 获取用户位置失败: $e，将使用默认位置');
    }

    _realGlobalSendService = RealGlobalSendService(
      onProgress: (count) {
        updateProgress(count);
      },
      onDataSent: (dataMB) {
        updateDataSent(dataMB);
      },
      onStopped: () {
        _onTransferCompleted();
      },
      onLog: (message) {
        // 性能优化：减少日志处理频率
        if (message.contains('成功') || message.contains('失败')) {
          updateLog(message);
          _parseLogAndUpdateCountryStatus(message);
        }
      },
      onTransferBeam: _onTransferBeam,
      onCountrySent: (bytes) async {
        await _saveToLocal(bytes);
      },
      userLatitude: userLat,
      userLongitude: userLng,
    );

    await _realGlobalSendService?.initialize();
    debugPrint('📋 真实全球发送服务初始化完成');
  }

  void _parseLogAndUpdateCountryStatus(String logMessage) {
    if (logMessage.contains('发送到') && logMessage.contains('成功')) {
      final regex = RegExp(r'发送到\s+([^()]+)\s+\([^()]+\)\s+.*成功');
      final match = regex.firstMatch(logMessage);
      if (match != null) {
        final countryName = match.group(1)?.trim();
        updateCountryStatus(countryName, SendStatus.success);
      }
    } else if (logMessage.contains('发送到') && logMessage.contains('失败')) {
      final regex = RegExp(r'发送到\s+([^()]+)\s+\([^()]+\)\s+.*失败');
      final match = regex.firstMatch(logMessage);
      if (match != null) {
        final countryName = match.group(1)?.trim();
        updateCountryStatus(countryName, SendStatus.failed);
      }
    }
  }

  void updateProgress(int count) {
    _globalSentCount = count;
    _schedulePersist(_persistTransferState);
    _scheduleNotify();
  }

  void updateDataSent(double dataMB) {
    _globalDataSentMB = dataMB;
    _schedulePersist(_persistTransferState);
    _scheduleNotify();
  }

  Future<void> _uploadPendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getInt('pending_transfer_bytes') ?? 0;

      if (pending > 0) {
        await LeaderboardService().updateTransferData(pending);
        await prefs.remove('pending_transfer_bytes');
        debugPrint('✅ 成功上传 ${(pending / 1024 / 1024).toStringAsFixed(2)} MB');
      }
    } catch (e) {
      debugPrint('上传失败: $e，数据已保存到本地待重试');
    }
  }

  Future<void> _saveToLocal(int bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getInt('pending_transfer_bytes') ?? 0;
    await prefs.setInt('pending_transfer_bytes', pending + bytes);
  }

  Future<void> retryPendingUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getInt('pending_transfer_bytes');

      if (pending != null && pending > 0) {
        await LeaderboardService().updateTransferData(pending);
        await prefs.remove('pending_transfer_bytes');
        debugPrint('✅ 成功上传缓存的传输数据: $pending bytes');
      }
    } catch (e) {
      debugPrint('重试上传失败: $e');
    }
  }

  void updateStatus(TransferStatus status) {
    _status = status;
    _scheduleNotify();
  }

  void initializeCountryStatuses(
    Map<String, List<String>> countryServers,
    Map<String, String> countryNames,
  ) {
    _countryStatuses = countryServers.keys.map((countryCode) {
      final countryName = countryNames[countryCode] ?? countryCode;
      return CountrySendStatus(
        countryCode: countryCode,
        countryName: countryName,
        status: SendStatus.pending,
        serverCount: countryServers[countryCode]?.length ?? 0,
      );
    }).toList();
    _scheduleNotify();
  }

  void updateCountryStatus(String? countryName, SendStatus status) {
    if (countryName == null) return;

    final index = _countryStatuses.indexWhere(
      (status) => status.countryName == countryName,
    );
    if (index != -1) {
      _countryStatuses[index] = _countryStatuses[index].copyWith(
        status: status,
      );
      _schedulePersist(_persistCountryStatuses);
      _scheduleNotify();
    }
  }

  void updateLog(String log) {
    _currentLog = log;
    _schedulePersist(_persistTransferState);
    _scheduleNotify();
  }

  int getSuccessCount() {
    return _countryStatuses
        .where((status) => status.status == SendStatus.success)
        .length;
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isTransferring = prefs.getBool('is_transferring') ?? false;
      _globalSentCount = prefs.getInt('global_sent_count') ?? 0;
      _globalDataSentMB = prefs.getDouble('global_data_sent_mb') ?? 0.0;
      _currentLog = prefs.getString('current_log') ?? '';

      final statusesJson = prefs.getString('country_statuses');
      if (statusesJson != null) {
        final List<dynamic> decoded = json.decode(statusesJson);
        _countryStatuses = decoded
            .map(
              (item) => CountrySendStatus(
                countryCode: item['countryCode'],
                countryName: item['countryName'],
                status: SendStatus.values[item['status']],
                serverCount: item['serverCount'],
              ),
            )
            .toList();
      }

      _scheduleNotify();
    } catch (e) {
      debugPrint('加载持久化状态失败: $e');
    }
  }

  Future<void> _persistTransferState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_transferring', _isTransferring);
      await prefs.setInt('global_sent_count', _globalSentCount);
      await prefs.setDouble('global_data_sent_mb', _globalDataSentMB);
      await prefs.setString('current_log', _currentLog);
    } catch (e) {
      debugPrint('持久化传输状态失败: $e');
    }
  }

  Future<void> _persistCountryStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        _countryStatuses
            .map(
              (status) => {
                'countryCode': status.countryCode,
                'countryName': status.countryName,
                'status': status.status.index,
                'serverCount': status.serverCount,
              },
            )
            .toList(),
      );
      await prefs.setString('country_statuses', encoded);
    } catch (e) {
      debugPrint('持久化国家状态失败: $e');
    }
  }

  Future<void> clearPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_transferring');
      await prefs.remove('global_sent_count');
      await prefs.remove('global_data_sent_mb');
      await prefs.remove('current_log');
      await prefs.remove('country_statuses');
    } catch (e) {
      debugPrint('清除持久化状态失败: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _batchUpdateTimer?.cancel();
    _realGlobalSendService?.stopSending();
    stopTransfer();
    super.dispose();
  }
}

enum SendStatus { pending, sending, success, failed }

class CountrySendStatus {
  final String countryCode;
  final String countryName;
  final SendStatus status;
  final int serverCount;

  CountrySendStatus({
    required this.countryCode,
    required this.countryName,
    required this.status,
    required this.serverCount,
  });

  CountrySendStatus copyWith({
    String? countryCode,
    String? countryName,
    SendStatus? status,
    int? serverCount,
  }) {
    return CountrySendStatus(
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      status: status ?? this.status,
      serverCount: serverCount ?? this.serverCount,
    );
  }
}
