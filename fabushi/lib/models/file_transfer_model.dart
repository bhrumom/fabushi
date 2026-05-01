import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
// Android 和 iOS 统一使用 audio_service MediaSession
import '../services/wifi_field_broadcast_service.dart';
import '../services/hotspot_manager_service.dart';
import '../services/keep_alive_service.dart';
import '../widgets/download_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import '../core/startup/deferred_loader.dart';
import '../services/local_loopback_service.dart';

import '../services/workmanager_keep_alive.dart';

enum TransferStatus { idle, transferring, completed, error }

/// 优化的文件传输模型 - 极致性能版本
///
/// 实现 WidgetsBindingObserver 以监听应用生命周期变化，
/// 在前后台切换时智能调整本地回环的运行模式。
class FileTransferModel extends ChangeNotifier with WidgetsBindingObserver {
  // 传输模式状态
  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  bool _isFieldEnergyMode = false; // 无网场能模式
  double _sendRateMB = 1.0;
  int _loopCount = 0; // 循环发送计数
  int _loopbackCount = 0; // 本地回环激活次数
  int _fieldBroadcastCount = 0; // 场能广播次数

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

  // 场能广播服务
  WiFiFieldBroadcastService? _fieldBroadcastService;
  final HotspotManagerService _hotspotManager = HotspotManagerService();
  String _hotspotMessage = ''; // 热点状态消息

  // 统一保活服务（基于 audio_service + MediaSession）
  final KeepAliveService _keepAliveService = KeepAliveService.instance;
  bool _needsHotspotGuide = false; // 是否需要显示热点指导

  // 本地回环服务
  LocalLoopbackService? _localLoopbackService;

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
    // 延迟初始化，避免阻塞启动
    DeferredLoader().scheduleTask(
      'file_transfer_init',
      const Duration(milliseconds: 300),
      _initializeModel,
    );
  }

  Future<void> _initializeModel() async {
    try {
      // 注册生命周期观察者
      WidgetsBinding.instance.addObserver(this);

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

  /// 应用生命周期变化回调
  ///
  /// 本地回环始终保持主线程模式运行，不进行前后台切换
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 本地回环默认使用主线程模式，不再进行模式切换
    // 主线程模式可以保持应用活跃，避免被系统杀死
  }

  // Getters
  bool get isGlobalSendEnabled => _isGlobalSendEnabled;
  bool get isLooping => _isLooping;
  bool get isFieldEnergyMode => _isFieldEnergyMode;
  int get loopCount => _loopCount;
  int get loopbackCount => _loopbackCount;
  int get fieldBroadcastCount => _fieldBroadcastCount;
  String get hotspotMessage => _hotspotMessage;
  bool get needsHotspotGuide => _needsHotspotGuide;

  /// 清除热点指导标记
  void clearHotspotGuide() {
    _needsHotspotGuide = false;
    notifyListeners();
  }

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

  /// 设置无网场能模式
  Future<void> setFieldEnergyMode(bool enabled) async {
    _isFieldEnergyMode = enabled;
    _hotspotMessage = '';
    _needsHotspotGuide = false;
    notifyListeners();
    debugPrint('🌟 无网场能模式: ${enabled ? "开启" : "关闭"}');

    if (enabled && !kIsWeb) {
      // 自动尝试开启热点
      final result = await _hotspotManager.enableHotspot();
      _hotspotMessage = result.message;
      debugPrint('📡 热点状态: ${result.message}');

      // 如果需要用户手动操作，显示指导
      if (result.needsManualAction) {
        _needsHotspotGuide = true;
      }
      notifyListeners();
    } else if (!enabled) {
      // 关闭热点（如果是我们开启的）
      await _hotspotManager.disableHotspot();
      _needsHotspotGuide = false;
    }
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
      // 内存优化：不使用 withData: true，避免大文件加载到内存
      // 而是使用 withReadStream: true（如果支持）或只获取路径
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        // 不设置 withData: true，这样大文件不会加载到内存
        // 本地平台会返回 file.path，可以流式读取
        // 只有 Web 平台需要 withData，但 Web 平台不支持大文件流式发送
        withData: kIsWeb, // 只在 Web 平台加载数据
        withReadStream: !kIsWeb, // 本地平台使用流式读取
      );

      if (result != null) {
        _selectedFiles.addAll(result.files);
        notifyListeners();

        // 打印文件信息用于调试
        for (final file in result.files) {
          debugPrint(
            '已选择文件: ${file.name}, 大小: ${(file.size / 1024 / 1024).toStringAsFixed(1)}MB, 路径: ${file.path ?? "无"}',
          );
        }
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

  Future<int> prepareDefaultNonR2AssetsForSending() async {
    final manifestString = await rootBundle.loadString(
      'assets/data/asset-manifest.json',
    );
    final List<dynamic> files = json.decode(manifestString);

    final assetPaths =
        files
            .whereType<Map<String, dynamic>>()
            .where((fileInfo) {
              final key = (fileInfo['key'] ?? '').toString();
              final source = (fileInfo['source'] ?? '').toString();

              return source != 'r2' &&
                  key.isNotEmpty &&
                  key.toLowerCase().endsWith('.txt') &&
                  !key.contains('/.DS_Store') &&
                  !key.startsWith('.');
            })
            .map((fileInfo) => (fileInfo['key'] ?? '').toString())
            .toList()
          ..sort();

    _selectedFiles = assetPaths.map((assetPath) {
      final fileName = assetPath.split('/').last;
      final bytes = Uint8List.fromList(
        utf8.encode('全球法布施素材\n$fileName\n$assetPath'),
      );
      return PlatformFile(name: fileName, size: bytes.length, bytes: bytes);
    }).toList();

    _isLooping = true;
    debugPrint('📚 已准备默认非 R2 经文素材: ${_selectedFiles.length} 个，循环发送已开启');
    notifyListeners();
    return _selectedFiles.length;
  }

  Future<void> _downloadSelectedAssets(
    BuildContext context,
    List<String> assetPaths,
  ) async {
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
        // 获取复用失败（文件不存在）的素材列表
        final failedAssets = await _reuseDownloadedAssets(
          context,
          alreadyDownloadedAssets,
        );
        // 把获取失败的素材加入需要下载的列表
        if (failedAssets.isNotEmpty) {
          needDownloadAssets.addAll(failedAssets);
          debugPrint('⚠️ ${failedAssets.length} 个素材需要重新下载');
        }
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

  /// 复用已下载的素材，返回获取失败的素材列表（需要重新下载）
  Future<List<String>> _reuseDownloadedAssets(
    BuildContext context,
    List<String> assetPaths,
  ) async {
    final List<String> failedAssets = [];
    try {
      for (String assetPath in assetPaths) {
        final file = await _sharedAssetManager.getDownloadedAsset(assetPath);
        if (file != null) {
          addFiles([file]);
          debugPrint('✅ 复用已下载素材: ${file.name}');
        } else {
          // 文件不存在，移除无效的下载记录并标记为需要重新下载
          debugPrint('⚠️ 已下载素材文件不存在，需要重新下载: $assetPath');
          await _sharedAssetManager.removeAssetDownloadRecord(assetPath);
          failedAssets.add(assetPath);
        }
      }
    } catch (e) {
      debugPrint('复用已下载素材失败: $e');
      rethrow;
    }
    return failedAssets;
  }

  Future<void> _downloadSingleAsset(
    BuildContext context,
    String assetPath,
  ) async {
    try {
      final taskId = await _sharedAssetManager.downloadAsset(assetPath);
      final fileName = assetPath.split('/').last;

      // 使用 Completer 等待下载完成后再返回
      await _showDownloadProgressDialog(context, taskId, fileName, assetPath);

      debugPrint('✅ 素材下载完成并关闭对话框: $fileName');
    } catch (e) {
      debugPrint('下载素材失败: $e');
      rethrow;
    }
  }

  Future<void> _showDownloadProgressDialog(
    BuildContext context,
    String taskId,
    String fileName,
    String assetPath,
  ) async {
    // 使用 Completer 来等待下载完成
    final completer = Completer<void>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DownloadProgressDialog(
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

            final file = await _sharedAssetManager.getDownloadedAsset(
              assetPath,
            );
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
            // 完成 Completer，让调用者知道下载已完成
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        },
      ),
    );

    // 启动下载任务
    _sharedAssetManager.startDownload(taskId);

    // 同时监听下载任务的状态变化，防止非正常完成情况
    _sharedAssetManager.downloadManager.taskStream
        .where((task) => task.id == taskId)
        .listen((task) {
          if (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.failed) {
            if (!completer.isCompleted) {
              // 给一点时间让 onComplete 先执行
              Future.delayed(Duration(milliseconds: 200), () {
                if (!completer.isCompleted) {
                  completer.complete();
                }
              });
            }
          }
        });

    // 等待下载完成
    await completer.future;
  }

  void addFiles(List<PlatformFile> files) {
    _selectedFiles.addAll(files);
    debugPrint(
      '📁 添加文件: ${files.map((f) => f.name).join(', ')}，当前总数: ${_selectedFiles.length}',
    );
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

  Function(
    double,
    double,
    double,
    double, {
    String? fromLabel,
    String? toLabel,
    Duration? displayDuration,
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
      Duration? displayDuration,
    })?
    callback,
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
    _loopbackCount = 0;

    _schedulePersist(_persistTransferState);
    _scheduleNotify();

    try {
      debugPrint(
        '🚀 开始全球传输 - 文件数量: ${_selectedFiles.length}, 循环: $_isLooping, 轮次: $_loopCount, 场能模式: $_isFieldEnergyMode',
      );

      // 启动后台服务（仅首次）
      if (!isLoopContinuation) {
        await _startBackgroundService();

        // 如果开启了场能模式，同时启动场能广播
        if (_isFieldEnergyMode && !kIsWeb) {
          await _startFieldEnergyBroadcast();
        }
      }

      // 启动本地回环（默认开启）
      await _startLocalLoopback();

      debugPrint('🔧 准备初始化平台全球发送服务...');
      await _initializePlatformGlobalSendService();
      debugPrint('🔧 平台服务初始化完成，准备开始发送...');
      // 传递循环参数给底层服务，让底层服务处理循环逻辑
      await _platformGlobalSendService?.startSending(
        files: _selectedFiles,
        isLoop: _isLooping,
      );
      debugPrint('🔧 发送方法执行完毕，准备上传数据...');
      await _uploadPendingData();

      debugPrint('✅ 传输完成，循环模式: $_isLooping, 轮次: $_loopCount');

      // 停止场能广播
      _stopFieldEnergyBroadcast();

      // 发送完成，停止后台服务
      await _stopBackgroundService();
      _isTransferring = false;
      _status = TransferStatus.completed;
    } catch (e) {
      debugPrint('❌ 传输失败: $e');
      _status = TransferStatus.error;
      _isTransferring = false;
      _stopFieldEnergyBroadcast();
      await _stopBackgroundService();
      _schedulePersist(_persistTransferState);
      _scheduleNotify();
    }
  }

  /// 启动场能广播
  Future<void> _startFieldEnergyBroadcast() async {
    if (kIsWeb) return; // Web 平台不支持
    if (_selectedFiles.isEmpty) return;

    // 如果场能模式下没有开始全球传输，也需要启动本地回环
    if (!_isTransferring) {
      await _startLocalLoopback();
    }

    try {
      _fieldBroadcastService = WiFiFieldBroadcastService(
        onLog: (message) {
          debugPrint('🌟 [场能] $message');
        },
        onBroadcastCount: (count) {
          _fieldBroadcastCount = count;
          _scheduleNotify();
        },
      );

      await _fieldBroadcastService!.initialize();

      // 获取第一个文件的数据进行广播
      final file = _selectedFiles.first;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        final fileObj = File(file.path!);
        fileBytes = await fileObj.readAsBytes();
      }

      if (fileBytes != null) {
        await _fieldBroadcastService!.startBroadcast(
          data: fileBytes,
          fileName: file.name,
        );
        debugPrint('🌟 场能广播已启动: ${file.name}');
      }
    } catch (e) {
      debugPrint('⚠️ 启动场能广播失败: $e');
    }
  }

  /// 停止场能广播
  void _stopFieldEnergyBroadcast() {
    _fieldBroadcastService?.stopBroadcast();
    _fieldBroadcastService?.dispose();
    _fieldBroadcastService = null;

    // 如果没有在全球传输，则停止本地回环
    if (!_isTransferring) {
      _stopLocalLoopback();
    }
    debugPrint('🛑 场能广播已停止');
  }

  /// 启动本地回环
  Future<void> _startLocalLoopback() async {
    if (kIsWeb) return;
    if (_selectedFiles.isEmpty) return;
    if (_localLoopbackService != null && _localLoopbackService!.isRunning)
      return;

    try {
      _localLoopbackService = LocalLoopbackService(
        onLog: (msg) => debugPrint('[Loopback] $msg'),
        onHeartbeat: (loopCount) {
          // loopCount is cumulative within the service isolate life
          _loopbackCount = loopCount;
          _scheduleNotify();

          // 实时更新通知栏计数（即使应用不在前台）
          if (_isTransferring) {
            final currentCountry =
                _countryStatuses.isNotEmpty &&
                    _globalSentCount > 0 &&
                    _globalSentCount <= _countryStatuses.length
                ? _countryStatuses[_globalSentCount - 1].countryName
                : '全球';

            // 更新系统媒体控制中心（统一使用 audio_service）
            _keepAliveService.updateProgress(
              sentCount: _globalSentCount,
              totalCount: _totalCountriesCount,
              currentCountry: currentCountry,
              loopCount: _loopCount,
              isLoopbackActive: true,
              loopbackCount: _loopbackCount,
            );
          }

          // This callback runs on main thread, keeping it active
          // Log periodically to avoid flooding (every ~30 seconds = 15 heartbeats at 2s interval)
          if (loopCount % 15 == 0) {
            debugPrint('💓 Main Thread Pulse - 本地回环循环次数: $loopCount');
          }
          // Update keep-alive service timestamp to signal activity
          WorkManagerKeepAlive.updateLastActiveTime();
        },
      );

      final file = _selectedFiles.first;

      // 直接使用文件路径或内存数据进行流式回环
      await _localLoopbackService!.start(
        data: file.bytes,
        filePath: file.path,
        fileName: file.name,
      );
    } catch (e) {
      debugPrint('⚠️ 启动本地回环失败: $e');
    }
  }

  /// 停止本地回环
  void _stopLocalLoopback() {
    _localLoopbackService?.stop();
    _localLoopbackService?.dispose();
    _localLoopbackService = null;
    _scheduleNotify();
  }

  void stopTransfer() {
    if (!_isTransferring) return;

    _isTransferring = false;
    _status = TransferStatus.idle;

    _platformGlobalSendService?.stopSending();

    // 停止场能广播
    _stopFieldEnergyBroadcast();

    // 停止本地回环
    _stopLocalLoopback();

    // 停止后台服务
    _stopBackgroundService();

    // 重置循环计数
    _loopCount = 0;
    _loopbackCount = 0;
    _fieldBroadcastCount = 0;

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

  /// 综合使用 audio_service 和 flutter_foreground_task
  Future<void> _startBackgroundService() async {
    try {
      final fileName = _selectedFiles.isNotEmpty
          ? _selectedFiles.first.name
          : '未知文件';

      // 1. 启动 KeepAliveService (audio_service)
      await _keepAliveService.start(
        audioName: fileName,
        totalCountries: _countryStatuses.length,
      );

      debugPrint('✅ 后台音频服务已启动');
    } catch (e) {
      debugPrint('⚠️ 启动后台服务失败: $e');
    }
  }

  /// 切换音频静音状态
  void _onToggleAudioMute() async {
    debugPrint('🔇 收到静音切换请求');
    await _keepAliveService.toggleMute();
  }

  /// 停止后台服务
  Future<void> _stopBackgroundService() async {
    try {
      await _keepAliveService.stop();
      debugPrint('✅ 后台音频服务已停止');
    } catch (e) {
      debugPrint('⚠️ 停止后台服务失败: $e');
    }
  }

  /// 更新后台服务进度
  void _updateBackgroundServiceProgress(String country, int sent, int total) {
    _keepAliveService.updateProgress(
      sentCount: sent,
      totalCount: total,
      currentCountry: country,
      loopCount: _loopCount,
      isLoopbackActive: _localLoopbackService?.isRunning ?? false,
      loopbackCount: _loopbackCount,
    );
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
        debugPrint(
          '📍 传输服务使用用户位置: ${userLocation.country}, ${userLocation.city}',
        );
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
        if (message.contains('成功') ||
            message.contains('失败') ||
            message.contains('HTTP') ||
            message.contains('UDP') ||
            message.contains('🚀') ||
            message.contains('📤') ||
            message.contains('✅') ||
            message.contains('❌') ||
            message.contains('初始化') ||
            message.contains('Socket') ||
            message.contains('🔄')) {
          updateLog(message);
          _parseLogAndUpdateCountryStatus(message);
        }
      },
      onTransferBeam: _onTransferBeam,
      onCountrySent: (bytes) async {
        await _saveToLocal(bytes);
      },
      onLoopStart: (loopNum) {
        // 更新轮次计数
        _loopCount = loopNum;
        debugPrint('🔄 轮次更新: $_loopCount');
        _scheduleNotify();
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
    // 匹配 UDP 格式: "✅ UDP 发送到 中国 (CN) 成功" 或 HTTP 格式
    if (logMessage.contains('成功')) {
      // UDP 格式: 发送到 国家名 (代码) 成功
      final udpRegex = RegExp(r'发送到\s+([^\s(]+)\s+\(([A-Z]{2})\)\s+成功');
      final udpMatch = udpRegex.firstMatch(logMessage);
      if (udpMatch != null) {
        final countryName = udpMatch.group(1)?.trim();
        if (countryName != null) {
          updateCountryStatus(countryName, SendStatus.success);
          // 直接更新通知栏进度
          _updateBackgroundServiceProgress(
            countryName,
            _globalSentCount,
            _countryStatuses.isNotEmpty ? _countryStatuses.length : 200,
          );
        }
        return;
      }

      // HTTP 格式: 发送到 国家名 (代码) ... 成功
      final httpRegex = RegExp(r'发送到\s+([^()]+)\s+\([^()]+\)\s+.*成功');
      final httpMatch = httpRegex.firstMatch(logMessage);
      if (httpMatch != null) {
        final countryName = httpMatch.group(1)?.trim();
        if (countryName != null) {
          updateCountryStatus(countryName, SendStatus.success);
          _updateBackgroundServiceProgress(
            countryName,
            _globalSentCount,
            _countryStatuses.isNotEmpty ? _countryStatuses.length : 200,
          );
        }
      }
    } else if (logMessage.contains('失败')) {
      final udpRegex = RegExp(r'发送到\s+([^\s(]+)\s+\(([A-Z]{2})\)\s+失败');
      final udpMatch = udpRegex.firstMatch(logMessage);
      if (udpMatch != null) {
        final countryName = udpMatch.group(1)?.trim();
        updateCountryStatus(countryName, SendStatus.failed);
        return;
      }

      final httpRegex = RegExp(r'发送到\s+([^()]+)\s+\([^()]+\)\s+.*失败');
      final httpMatch = httpRegex.firstMatch(logMessage);
      if (httpMatch != null) {
        final countryName = httpMatch.group(1)?.trim();
        updateCountryStatus(countryName, SendStatus.failed);
      }
    }
  }

  void updateProgress(int count) {
    _globalSentCount = count;

    // 获取当前正在发送的国家名称
    String currentCountry = '全球';
    if (_countryStatuses.isNotEmpty &&
        count > 0 &&
        count <= _countryStatuses.length) {
      currentCountry = _countryStatuses[count - 1].countryName;
    }

    // 同步更新后台服务进度通知
    _updateBackgroundServiceProgress(
      currentCountry,
      count,
      _totalCountriesCount,
    );

    _scheduleNotify();
  }

  // 辅助获取总国家数
  int get _totalCountriesCount =>
      _countryStatuses.isNotEmpty ? _countryStatuses.length : 249;

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

    final index = _countryStatuses.indexWhere(
      (status) => status.countryName == countryName,
    );
    if (index != -1) {
      _countryStatuses[index] = _countryStatuses[index].copyWith(
        status: status,
      );
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
    _platformGlobalSendService?.stopSending();
    stopTransfer();

    // 移除生命周期观察者
    WidgetsBinding.instance.removeObserver(this);

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
