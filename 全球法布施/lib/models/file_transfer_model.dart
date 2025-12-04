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
import '../services/shared_asset_manager.dart';
import '../services/download_manager.dart' show DownloadStatus;
import '../services/real_global_send_service.dart';
import '../services/platform_global_send_service.dart';
import '../services/ip_location_service.dart';
import '../services/leaderboard_service.dart';
import '../services/foreground_service_manager.dart';
import '../services/ios_background_audio_handler.dart';
import '../widgets/download_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import '../core/startup/deferred_loader.dart';

enum TransferStatus { idle, transferring, completed, error }

/// 优化的文件传输模型 - 极致性能版本
class FileTransferModel extends ChangeNotifier {
  // 传输模式状态
  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  double _sendRateMB = 1.0;
  int _loopCount = 0;  // 循环发送计数

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
  PlatformGlobalSendService? _platformGlobalSendService;
  List<CountrySendStatus> _countryStatuses = [];
  String _currentLog = '';

  final SharedAssetManager _sharedAssetManager = SharedAssetManager();
  final IPLocationService _ipLocationService = IPLocationService();
  
  // 后台服务管理器
  final ForegroundServiceManager _foregroundService = ForegroundServiceManager();
  IOSBackgroundAudioHandler? _iosAudioHandler;

  bool _isDisposed = false;

  // 首页属性
  PlatformFile? get selectedFile => _selectedFiles.isNotEmpty ? _selectedFiles.first : null;
  double _progress = 0.0;
  double get progress => _progress;

  // 性能优化：批量更新定时器
  Timer? _batchUpdateTimer;
  bool _hasPendingUpdate = false;

  // 性能优化：持久化队列
  final List<Future<void> Function()> _persistQueue = [];
  bool _isPersisting = false;

  FileTransferModel() {
    // 延迟初始化，避免阻塞启动
    DeferredLoader().scheduleTask(
      'file_transfer_init',
      const Duration(milliseconds: 300),
      _initializeModel,
    );
  }

  Future<void> _initializeModel() async {
    try {
      await _loadPersistedState();
      if (_isTransferring) {
        _isTransferring = false;
        _schedulePersist(_persistTransferState);
        debugPrint('🔄 应用启动，清除传输状态');
        _scheduleNotify();
      }
    } catch (e) {
      debugPrint('❌ FileTransferModel初始化失败: $e');
    }
  }

  // Getters
  bool get isGlobalSendEnabled => _isGlobalSendEnabled;
  bool get isLooping => _isLooping;
  int get loopCount => _loopCount;
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
    _batchUpdateTimer = Timer(const Duration(milliseconds: 16), () async {
      if (!_isDisposed) {
        _hasPendingUpdate = false;
        // 关键修复：让出主线程控制权，避免阻塞UI
        await Future.delayed(Duration.zero);
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
      // 关键修复：每次持久化操作后让出主线程控制权
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

    if (selectedAssets != null && selectedAssets is List && selectedAssets.isNotEmpty) {
      final List<String> assetPaths = selectedAssets.map((asset) => asset.toString()).toList();
      _downloadSelectedAssets(context, assetPaths);
    }
  }

  Future<void> _downloadSelectedAssets(BuildContext context, List<String> assetPaths) async {
    try {
      await _sharedAssetManager.initialize();

      final List<String> needDownloadAssets = [];
      final List<String> alreadyDownloadedAssets = [];

      for (String assetPath in assetPaths) {
        if (_sharedAssetManager.isAssetDownloaded(assetPath)) {
          alreadyDownloadedAssets.add(assetPath);
        } else {
          needDownloadAssets.add(assetPath);
        }
      }

      String message = '';
      if (alreadyDownloadedAssets.isNotEmpty && needDownloadAssets.isNotEmpty) {
        message = '发现 ${alreadyDownloadedAssets.length} 个素材已下载，将下载 ${needDownloadAssets.length} 个新素材';
      } else if (alreadyDownloadedAssets.isNotEmpty) {
        message = '所有 ${alreadyDownloadedAssets.length} 个素材都已下载，将直接复用';
      } else if (needDownloadAssets.isNotEmpty) {
        message = '开始下载 ${needDownloadAssets.length} 个素材';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      if (alreadyDownloadedAssets.isNotEmpty) {
        await _reuseDownloadedAssets(context, alreadyDownloadedAssets);
      }

      if (needDownloadAssets.isNotEmpty) {
        for (String assetPath in needDownloadAssets) {
          await _downloadSingleAsset(context, assetPath);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('所有素材处理完成')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reuseDownloadedAssets(BuildContext context, List<String> assetPaths) async {
    try {
      for (String assetPath in assetPaths) {
        final file = await _sharedAssetManager.getDownloadedAsset(assetPath);
        if (file != null) {
          addFiles([file]);
          debugPrint('复用已下载素材: ${file.name}');
        }
      }
    } catch (e) {
      debugPrint('复用已下载素材失败: $e');
      rethrow;
    }
  }



  Future<void> _downloadSingleAsset(BuildContext context, String assetPath) async {
    try {
      final taskId = await _sharedAssetManager.downloadAsset(assetPath);
      final fileName = assetPath.split('/').last;

      _showDownloadProgressDialog(context, taskId, fileName, assetPath);

      await _sharedAssetManager.startDownload(taskId);
    } catch (e) {
      debugPrint('下载素材失败: $e');
      rethrow;
    }
  }

  void _showDownloadProgressDialog(BuildContext context, String taskId, String fileName, String assetPath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        taskId: taskId,
        downloadManager: _sharedAssetManager.downloadManager,
        onComplete: () async {
          debugPrint('📥 下载完成回调开始执行 - 文件: $fileName');

          try {
            // 先标记为已下载
            await _sharedAssetManager.markAssetDownloaded(assetPath);
            debugPrint('✅ 已标记为已下载: $assetPath');
            
            // 等待一下确保文件完全写入
            await Future.delayed(Duration(milliseconds: 100));
            
            final file = await _sharedAssetManager.getDownloadedAsset(assetPath);
            debugPrint('💾 获取已下载文件: ${file?.name}, 大小: ${file?.size}');
            
            if (file != null) {
              debugPrint('✅ 即将添加文件到列表: ${file.name}');
              addFiles([file]);
              debugPrint('✅ 文件已添加到列表，当前总数: ${_selectedFiles.length}');
            } else {
              debugPrint('❌ 无法获取已下载的文件: $assetPath');
            }
          } catch (e) {
            debugPrint('❌ 下载完成处理出错: $e');
          } finally {
            _sharedAssetManager.clearTaskMapping(assetPath);
          }
        },
      ),
    );
  }

  void addFiles(List<PlatformFile> files) {
    _selectedFiles.addAll(files);
    debugPrint('📁 添加文件: ${files.map((f) => f.name).join(', ')}，当前总数: ${_selectedFiles.length}');
    notifyListeners(); // 立即通知，不使用防抖
  }

  void removeFile(PlatformFile file) {
    _selectedFiles.remove(file);
    debugPrint('🗑️ 移除文件: ${file.name}，当前总数: ${_selectedFiles.length}');
    notifyListeners(); // 立即通知，不使用防抖
  }

  void clearFiles() {
    _selectedFiles.clear();
    debugPrint('🧹 清空所有文件');
    notifyListeners(); // 立即通知，不使用防抖
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

  Function(double, double, double, double, {String? fromLabel, String? toLabel, Duration? displayDuration})? _onTransferBeam;

  void setTransferBeamCallback(
    Function(double, double, double, double, {String? fromLabel, String? toLabel, Duration? displayDuration})? callback,
  ) {
    _onTransferBeam = callback;
  }

  Future<void> startGlobalTransfer({bool isLoopContinuation = false}) async {
    // 如果不是循环继续，检查是否已在传输中
    if (!isLoopContinuation && _isTransferring) return;
    if (_selectedFiles.isEmpty) return;

    _isTransferring = true;
    _status = TransferStatus.transferring;
    
    // 初始化或增加循环计数
    if (!isLoopContinuation) {
      _loopCount = _isLooping ? 1 : 0;
    } else {
      _loopCount++;
    }
    
    // 重置发送计数（每轮重新开始）
    _globalSentCount = 0;
    
    _schedulePersist(_persistTransferState);
    _scheduleNotify();

    try {
      debugPrint('🚀 开始全球传输 - 文件数量: ${_selectedFiles.length}, 循环: $_isLooping, 轮次: $_loopCount');

      // 启动后台服务（仅首次）
      if (!isLoopContinuation) {
        await _startBackgroundService();
      }

      await _initializePlatformGlobalSendService();
      await _platformGlobalSendService?.startSending(files: _selectedFiles, isLoop: false);
      await _uploadPendingData();
      
      debugPrint('✅ 第 $_loopCount 轮传输完成');
      
      // 检查是否需要循环
      if (_isLooping && _isTransferring) {
        debugPrint('🔄 准备下一轮循环发送...');
        // 等待2秒后开始下一轮
        await Future.delayed(const Duration(seconds: 2));
        
        // 再次检查循环状态（用户可能在等待期间关闭了循环）
        if (_isLooping && _isTransferring) {
          await startGlobalTransfer(isLoopContinuation: true);  // 递归调用开始下一轮
          return;  // 返回，不执行下面的停止服务逻辑
        }
      }
      
      // 发送完成，停止后台服务
      await _stopBackgroundService();
      _isTransferring = false;
      _status = TransferStatus.completed;
      
    } catch (e) {
      debugPrint('❌ 传输失败: $e');
      _status = TransferStatus.error;
      _isTransferring = false;
      await _stopBackgroundService();
      _schedulePersist(_persistTransferState);
      _scheduleNotify();
    }
  }

  void stopTransfer() {
    if (!_isTransferring) return;

    _isTransferring = false;
    _status = TransferStatus.idle;

    _platformGlobalSendService?.stopSending();
    
    // 停止后台服务
    _stopBackgroundService();
    
    // 重置循环计数
    _loopCount = 0;

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

  /// 启动后台服务（Android 前台服务或 iOS 后台音频）
  Future<void> _startBackgroundService() async {
    try {
      final fileName = _selectedFiles.isNotEmpty ? _selectedFiles.first.name : '未知文件';
      
      if (Platform.isAndroid) {
        // Android 前台服务
        await _foregroundService.initialize();
        await _foregroundService.start(
          fileName: fileName,
          totalCountries: _countryStatuses.length,
        );
        debugPrint('✅ Android 前台服务已启动');
      } else if (Platform.isIOS) {
        // iOS 后台音频
        _iosAudioHandler ??= await initIOSBackgroundAudio();
        await _iosAudioHandler?.startBackgroundAudio(
          fileName: fileName,
          totalCountries: _countryStatuses.length,
        );
        debugPrint('✅ iOS 后台音频已启动');
      }
    } catch (e) {
      debugPrint('⚠️ 启动后台服务失败: $e');
    }
  }

  /// 停止后台服务
  Future<void> _stopBackgroundService() async {
    try {
      if (Platform.isAndroid) {
        await _foregroundService.showCompletionNotification(
          totalSent: _globalSentCount,
          loopCount: _loopCount,
        );
      } else if (Platform.isIOS) {
        await _iosAudioHandler?.showCompletion(
          totalSent: _globalSentCount,
          loopCount: _loopCount,
        );
      }
      debugPrint('✅ 后台服务已停止');
    } catch (e) {
      debugPrint('⚠️ 停止后台服务失败: $e');
    }
  }

  /// 更新后台服务进度
  void _updateBackgroundServiceProgress(String country, int sent, int total) {
    if (Platform.isAndroid) {
      _foregroundService.updateProgress(
        sentCount: sent,
        totalCount: total,
        currentCountry: country,
        loopCount: _loopCount,
      );
    } else if (Platform.isIOS) {
      _iosAudioHandler?.updateProgress(
        sentCount: sent,
        totalCount: total,
        currentCountry: country,
        loopCount: _loopCount,
      );
    }
  }

  /// 初始化平台自适应全球发送服务
  /// Web 平台使用 HTTP，其他平台使用 UDP (GeoLite2 IP)
  Future<void> _initializePlatformGlobalSendService() async {
    double? userLat;
    double? userLng;

    try {
      final userLocation = await _ipLocationService.getCurrentLocation();
      if (userLocation != null) {
        userLat = userLocation.latitude;
        userLng = userLocation.longitude;
        debugPrint('📍 传输服务使用用户位置: ${userLocation.country}, ${userLocation.city}');
      }
    } catch (e) {
      debugPrint('⚠️ 获取用户位置失败: $e，将使用默认位置');
    }

    _platformGlobalSendService = PlatformGlobalSendService(
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
        // 打印所有日志用于调试
        debugPrint('📡 [GlobalSend] $message');
        // 更新 UI 日志
        if (message.contains('成功') || message.contains('失败') || 
            message.contains('HTTP') || message.contains('UDP') ||
            message.contains('🚀') || message.contains('📤') ||
            message.contains('✅') || message.contains('❌') ||
            message.contains('初始化') || message.contains('Socket')) {
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

    await _platformGlobalSendService?.initialize();
    
    // 打印当前使用的发送模式
    final mode = _platformGlobalSendService?.sendMode ?? 'Unknown';
    debugPrint('📋 平台全球发送服务初始化完成 - 模式: $mode');
  }

  Future<void> _initializeRealGlobalSendService() async {
    double? userLat;
    double? userLng;

    try {
      final userLocation = await _ipLocationService.getCurrentLocation();
      if (userLocation != null) {
        userLat = userLocation.latitude;
        userLng = userLocation.longitude;
        debugPrint('📍 传输服务使用用户位置: ${userLocation.country}, ${userLocation.city}');
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
    // 关键修复：减少持久化频率，避免过度阻塞UI
    if (count % 10 == 0) {
      _schedulePersist(_persistTransferState);
    }
    
    // 更新后台服务进度
    if (_countryStatuses.isNotEmpty && count > 0 && count <= _countryStatuses.length) {
      final currentCountry = _countryStatuses[count - 1].countryName;
      _updateBackgroundServiceProgress(currentCountry, count, _countryStatuses.length);
    }
    
    _scheduleNotify();
  }

  void updateDataSent(double dataMB) {
    _globalDataSentMB = dataMB;
    // 关键修复：减少持久化频率，避免过度阻塞UI
    if (dataMB.toInt() % 10 == 0) {
      _schedulePersist(_persistTransferState);
    }
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

    final index = _countryStatuses.indexWhere((status) => status.countryName == countryName);
    if (index != -1) {
      _countryStatuses[index] = _countryStatuses[index].copyWith(status: status);
      // 关键修复：只在状态变为成功或失败时持久化，减少频率
      if (status == SendStatus.success || status == SendStatus.failed) {
        _schedulePersist(_persistCountryStatuses);
      }
      _scheduleNotify();
    }
  }

  void updateLog(String log) {
    _currentLog = log;
    // 关键修复：日志更新不需要频繁持久化，只在重要日志时持久化
    if (log.contains('成功') || log.contains('失败') || log.contains('完成')) {
      _schedulePersist(_persistTransferState);
    }
    _scheduleNotify();
  }

  int getSuccessCount() {
    return _countryStatuses.where((status) => status.status == SendStatus.success).length;
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
    _platformGlobalSendService?.stopSending();
    stopTransfer();
    super.dispose();
  }
}

enum SendStatus {
  pending,
  sending,
  success,
  failed,
}

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
