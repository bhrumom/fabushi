import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import '../core/constants/country_servers.dart';
import '../screens/asset_screen.dart';
import '../services/shared_asset_manager.dart';
import '../services/download_manager.dart' show DownloadStatus;
import '../services/real_global_send_service.dart';
import '../services/platform_global_send_service.dart';
import '../services/ip_location_service.dart';
import '../services/leaderboard_service.dart';
import '../services/cbeta_send_text_service.dart';
import '../services/wifi_field_broadcast_service.dart';
import '../services/hotspot_manager_service.dart';
import '../services/keep_alive_service.dart';
import '../widgets/download_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/startup/deferred_loader.dart';
import '../services/local_loopback_service.dart';
import '../services/workmanager_keep_alive.dart';

enum TransferStatus { idle, transferring, completed, error }

class FileTransferModel extends ChangeNotifier with WidgetsBindingObserver {
  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  bool _isFieldEnergyMode = false;
  double _sendRateMB = 1.0;
  int _loopCount = 0;
  int _loopbackCount = 0;
  int _fieldBroadcastCount = 0;

  List<PlatformFile> _selectedFiles = [];
  List<String> _countryList = ['ALL'];

  bool _isTransferring = false;
  bool _isPreparingSend = false;
  String _preparingSendMessage = '';
  TransferStatus _status = TransferStatus.idle;

  int _globalSentCount = 0;
  double _globalDataSentMB = 0.0;

  RealGlobalSendService? _realGlobalSendService;
  PlatformGlobalSendService? _platformGlobalSendService;
  List<CountrySendStatus> _countryStatuses = [];
  String _currentLog = '';
  String _currentSendingScripture = '';

  final SharedAssetManager _sharedAssetManager = SharedAssetManager();
  final IPLocationService _ipLocationService = IPLocationService();
  final CbetaSendTextService _cbetaSendTextService = CbetaSendTextService();
  final Map<String, Uint8List> _downloadedScriptureMemory = {};

  WiFiFieldBroadcastService? _fieldBroadcastService;
  final HotspotManagerService _hotspotManager = HotspotManagerService();
  String _hotspotMessage = '';

  final KeepAliveService _keepAliveService = KeepAliveService.instance;
  bool _needsHotspotGuide = false;

  LocalLoopbackService? _localLoopbackService;

  bool _isDisposed = false;
  bool _stopRequested = false;

  PlatformFile? get selectedFile =>
      _selectedFiles.isNotEmpty ? _selectedFiles.first : null;
  double _progress = 0.0;
  double get progress => _progress;

  Timer? _batchUpdateTimer;
  bool _hasPendingUpdate = false;

  final List<Future<void> Function()> _persistQueue = [];
  bool _isPersisting = false;

  FileTransferModel() {
    DeferredLoader().scheduleTask(
      'file_transfer_init',
      const Duration(milliseconds: 300),
      _initializeModel,
    );
  }

  Future<void> _initializeModel() async {
    try {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  bool get isGlobalSendEnabled => _isGlobalSendEnabled;
  bool get isLooping => _isLooping;
  bool get isFieldEnergyMode => _isFieldEnergyMode;
  int get loopCount => _loopCount;
  int get loopbackCount => _loopbackCount;
  int get fieldBroadcastCount => _fieldBroadcastCount;
  String get hotspotMessage => _hotspotMessage;
  bool get needsHotspotGuide => _needsHotspotGuide;
  double get sendRateMB => _sendRateMB;
  List<PlatformFile> get selectedFiles => _selectedFiles;
  List<String> get countryList => _countryList;
  bool get isTransferring => _isTransferring;
  bool get isPreparingSend => _isPreparingSend;
  String get preparingSendMessage => _preparingSendMessage;
  TransferStatus get status => _status;
  bool get hasFiles => _selectedFiles.isNotEmpty;
  int get globalSentCount => _globalSentCount;
  double get globalDataSentMB => _globalDataSentMB;
  List<CountrySendStatus> get countryStatuses => _countryStatuses;
  String get currentLog => _currentLog;
  String get currentSendingScripture => _currentSendingScripture;

  void clearHotspotGuide() {
    _needsHotspotGuide = false;
    notifyListeners();
  }

  void _scheduleNotify() {
    if (_hasPendingUpdate) return;
    _hasPendingUpdate = true;

    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 16), () async {
      if (!_isDisposed) {
        _hasPendingUpdate = false;
        await Future.delayed(Duration.zero);
        notifyListeners();
      }
    });
  }

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

  Future<void> setFieldEnergyMode(bool enabled) async {
    _isFieldEnergyMode = enabled;
    _hotspotMessage = '';
    _needsHotspotGuide = false;
    notifyListeners();
    debugPrint('🌟 无网场能模式: ${enabled ? "开启" : "关闭"}');

    if (enabled && !kIsWeb) {
      final result = await _hotspotManager.enableHotspot();
      _hotspotMessage = result.message;
      debugPrint('📡 热点状态: ${result.message}');
      if (result.needsManualAction) {
        _needsHotspotGuide = true;
      }
      notifyListeners();
    } else if (!enabled) {
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

  void beginPreparingSend(String message) {
    if (_isDisposed) return;
    _isPreparingSend = true;
    _preparingSendMessage = message;
    _currentLog = message;
    notifyListeners();
  }

  void _finishPreparingSend() {
    _isPreparingSend = false;
    _preparingSendMessage = '';
  }

  void _cacheScriptureFile(PlatformFile file) {
    if (file.bytes != null) {
      _downloadedScriptureMemory[file.name] = file.bytes!;
    }
  }

  void _releaseCachedScriptures({bool clearSelection = true}) {
    _downloadedScriptureMemory.clear();
    if (clearSelection) {
      _selectedFiles = [];
    }
  }

  PlatformFile _buildPlatformFileFromText(CbetaSendText text) {
    final content = [
      '来源: CBETA',
      '经名: ${text.title}',
      '编号: ${text.work} 第 ${text.juan} 卷',
      if (text.byline.isNotEmpty) '译者/作者: ${text.byline}',
      if (text.category.isNotEmpty) '分类: ${text.category}',
      if (text.sourceUrl.isNotEmpty) 'CBETA API: ${text.sourceUrl}',
      '',
      text.content,
    ].join('\n');
    final bytes = Uint8List.fromList(utf8.encode(content));
    final file = PlatformFile(
      name: text.fileName.isNotEmpty ? text.fileName : '${text.work}.txt',
      size: bytes.length,
      bytes: bytes,
    );
    _cacheScriptureFile(file);
    return file;
  }

  Future<int> startDefaultScriptureSendSequence() async {
    if (_isPreparingSend || _isTransferring) return 0;

    _stopRequested = false;
    _isLooping = false;
    _status = TransferStatus.idle;
    _globalSentCount = 0;
    _globalDataSentMB = 0;
    _releaseCachedScriptures();
    beginPreparingSend('📚 正在逐部下载经文，下载一部发送一部...');

    final seenScriptures = <String>{};
    int sentScriptureCount = 0;
    int offset = 0;
    String? cursor;
    bool foundAny = false;

    try {
      while (!_stopRequested) {
        final result = await _cbetaSendTextService.fetchSendTextsPage(
          limit: 1,
          offset: offset,
          cursor: cursor,
        );

        if (result.items.isEmpty) {
          break;
        }

        foundAny = true;
        bool pageHadNewItem = false;

        for (final text in result.items) {
          if (_stopRequested) break;

          final scriptureKey =
              '${text.work}_${text.juan}_${text.fileName}_${text.title}';
          if (!seenScriptures.add(scriptureKey)) {
            continue;
          }
          pageHadNewItem = true;

          final file = _buildPlatformFileFromText(text);
          _selectedFiles = [file];
          _currentSendingScripture = text.title;
          _preparingSendMessage = '📚 已下载《${text.title}》，准备发送到全部国家...';
          _currentLog = '📚 已将《${text.title}》下载到内存，开始逐国发送';
          initializeCountryStatuses(GLOBAL_COUNTRY_SERVERS, COUNTRY_NAMES);
          notifyListeners();

          await startGlobalTransfer(forceSingleRound: true);

          if (_stopRequested) {
            break;
          }

          if (_status == TransferStatus.error) {
            _finishPreparingSend();
            notifyListeners();
            return sentScriptureCount;
          }

          sentScriptureCount++;
          _releaseCachedScriptures();
          _currentSendingScripture = '';
          _currentLog = '✅ 已完成《${text.title}》全球发送，准备下一部经文...';
          if (!_stopRequested) {
            beginPreparingSend('📚 《${text.title}》已发送完成，继续下载下一部...');
          }
        }

        if (_stopRequested) {
          break;
        }

        if (!pageHadNewItem) {
          break;
        }

        final nextCursor = result.nextCursor?.trim();
        if (nextCursor != null &&
            nextCursor.isNotEmpty &&
            nextCursor != cursor) {
          cursor = nextCursor;
        } else if (result.hasMore) {
          offset += result.items.length;
        } else {
          break;
        }
      }

      if (!foundAny) {
        _currentLog = '未下载到可发送的 CBETA 经文';
        _finishPreparingSend();
        notifyListeners();
        return 0;
      }

      if (_stopRequested) {
        _currentLog = '🛑 已停止逐部发送';
      } else {
        _currentLog = '✨ 已完成全部经文逐部下载与发送，共 $sentScriptureCount 部';
        _status = TransferStatus.completed;
      }
      _finishPreparingSend();
      notifyListeners();
      return sentScriptureCount;
    } catch (error) {
      _selectedFiles = [];
      _releaseCachedScriptures();
      _currentSendingScripture = '';
      _finishPreparingSend();
      _status = TransferStatus.error;
      updateLog('❌ CBETA 经文逐部下载失败: $error');
      notifyListeners();
      return sentScriptureCount;
    }
  }

  Future<int> prepareDefaultNonR2AssetsForSending() async {
    beginPreparingSend('📚 正在下载默认经文，下载完成后会自动开始发送...');

    try {
      final result = await _cbetaSendTextService.fetchDefaultSendTexts();
      _selectedFiles = result.items.map(_buildPlatformFileFromText).toList();

      _isLooping = true;
      _currentSendingScripture = result.items.isNotEmpty
          ? result.items.first.title
          : '';
      final titles = result.items.map((item) => '《${item.title}》').join('、');
      final warning = result.errors.isEmpty
          ? ''
          : '；部分经文下载失败: ${jsonEncode(result.errors)}';
      _preparingSendMessage = '📚 已下载 ${_selectedFiles.length} 部经文，正在启动发送...';
      updateLog(
        '📚 已从 CBETA 下载 ${_selectedFiles.length} 部经文，准备发送 $titles$warning',
      );
      debugPrint('📚 已从 CBETA 下载 ${_selectedFiles.length} 部经文，循环发送已开启');
      notifyListeners();
      return _selectedFiles.length;
    } catch (error) {
      _selectedFiles = [];
      _releaseCachedScriptures();
      _currentSendingScripture = '';
      _finishPreparingSend();
      updateLog('❌ CBETA 经文下载失败: $error');
      debugPrint('❌ CBETA 经文下载失败: $error');
      notifyListeners();
      return 0;
    }
  }

  Future<void> selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: kIsWeb,
        withReadStream: !kIsWeb,
      );

      if (result != null) {
        _selectedFiles.addAll(result.files);
        notifyListeners();

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
        final failedAssets = await _reuseDownloadedAssets(
          context,
          alreadyDownloadedAssets,
        );
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
      ).showSnackBar(const SnackBar(content: Text('所有素材处理完成')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
            await _sharedAssetManager.markAssetDownloaded(assetPath);
            debugPrint('✅ 已标记为已下载: $assetPath');

            await Future.delayed(const Duration(milliseconds: 100));

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
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        },
      ),
    );

    _sharedAssetManager.startDownload(taskId);

    _sharedAssetManager.downloadManager.taskStream
        .where((task) => task.id == taskId)
        .listen((task) {
          if (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.failed) {
            if (!completer.isCompleted) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (!completer.isCompleted) {
                  completer.complete();
                }
              });
            }
          }
        });

    await completer.future;
  }

  void addFiles(List<PlatformFile> files) {
    _selectedFiles.addAll(files);
    debugPrint(
      '📁 添加文件: ${files.map((f) => f.name).join(', ')}，当前总数: ${_selectedFiles.length}',
    );
    notifyListeners();
  }

  void removeFile(PlatformFile file) {
    _selectedFiles.remove(file);
    _downloadedScriptureMemory.remove(file.name);
    debugPrint('🗑️ 移除文件: ${file.name}，当前总数: ${_selectedFiles.length}');
    notifyListeners();
  }

  void clearFiles() {
    _selectedFiles.clear();
    _downloadedScriptureMemory.clear();
    debugPrint('🧹 清空所有文件');
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

  Future<void> startGlobalTransfer({
    bool isLoopContinuation = false,
    bool forceSingleRound = false,
  }) async {
    if (!isLoopContinuation && _isTransferring) return;
    if (_selectedFiles.isEmpty) {
      _finishPreparingSend();
      _scheduleNotify();
      return;
    }

    final shouldLoop = !forceSingleRound && _isLooping;

    _isTransferring = true;
    _finishPreparingSend();
    if (_currentSendingScripture.isEmpty && _selectedFiles.isNotEmpty) {
      _currentSendingScripture = _displayScriptureName(
        _selectedFiles.first.name,
      );
    }
    _status = TransferStatus.transferring;

    if (!isLoopContinuation) {
      _loopCount = shouldLoop ? 1 : 0;
    } else {
      _loopCount++;
    }

    _globalSentCount = 0;
    _loopbackCount = 0;

    _schedulePersist(_persistTransferState);
    _scheduleNotify();

    try {
      debugPrint(
        '🚀 开始全球传输 - 文件数量: ${_selectedFiles.length}, 循环: $shouldLoop, 轮次: $_loopCount, 场能模式: $_isFieldEnergyMode',
      );

      if (!isLoopContinuation) {
        await _startBackgroundService();
        if (_isFieldEnergyMode && !kIsWeb) {
          await _startFieldEnergyBroadcast();
        }
      }

      await _startLocalLoopback();

      debugPrint('🔧 准备初始化平台全球发送服务...');
      await _initializePlatformGlobalSendService();
      debugPrint('🔧 平台服务初始化完成，准备开始发送...');
      await _platformGlobalSendService?.startSending(
        files: _selectedFiles,
        isLoop: shouldLoop,
      );
      debugPrint('🔧 发送方法执行完毕，准备上传数据...');
      await _uploadPendingData();

      debugPrint('✅ 传输完成，循环模式: $shouldLoop, 轮次: $_loopCount');

      _stopFieldEnergyBroadcast();
      await _stopBackgroundService();
      _isTransferring = false;
      _status = TransferStatus.completed;
      _currentSendingScripture = '';
    } catch (e) {
      debugPrint('❌ 传输失败: $e');
      _status = TransferStatus.error;
      _isTransferring = false;
      _finishPreparingSend();
      _currentSendingScripture = '';
      _stopFieldEnergyBroadcast();
      await _stopBackgroundService();
      _schedulePersist(_persistTransferState);
      _scheduleNotify();
    }
  }

  Future<void> _startFieldEnergyBroadcast() async {
    if (kIsWeb) return;
    if (_selectedFiles.isEmpty) return;

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

  void _stopFieldEnergyBroadcast() {
    _fieldBroadcastService?.stopBroadcast();
    _fieldBroadcastService?.dispose();
    _fieldBroadcastService = null;

    if (!_isTransferring) {
      _stopLocalLoopback();
    }
    debugPrint('🛑 场能广播已停止');
  }

  Future<void> _startLocalLoopback() async {
    if (kIsWeb) return;
    if (_selectedFiles.isEmpty) return;
    if (_localLoopbackService != null && _localLoopbackService!.isRunning) {
      return;
    }

    try {
      _localLoopbackService = LocalLoopbackService(
        onLog: (msg) => debugPrint('[Loopback] $msg'),
        onHeartbeat: (loopCount) {
          _loopbackCount = loopCount;
          _scheduleNotify();

          if (_isTransferring) {
            final currentCountry =
                _countryStatuses.isNotEmpty &&
                    _globalSentCount > 0 &&
                    _globalSentCount <= _countryStatuses.length
                ? _countryStatuses[_globalSentCount - 1].countryName
                : '全球';

            _keepAliveService.updateProgress(
              sentCount: _globalSentCount,
              totalCount: _totalCountriesCount,
              currentCountry: currentCountry,
              audioName: _currentSendingScripture.isNotEmpty
                  ? _currentSendingScripture
                  : null,
              loopCount: _loopCount,
              isLoopbackActive: true,
              loopbackCount: _loopbackCount,
            );
          }

          if (loopCount % 15 == 0) {
            debugPrint('💓 Main Thread Pulse - 本地回环循环次数: $loopCount');
          }
          WorkManagerKeepAlive.updateLastActiveTime();
        },
      );

      final file = _selectedFiles.first;
      await _localLoopbackService!.start(
        data: file.bytes,
        filePath: file.path,
        fileName: file.name,
      );
    } catch (e) {
      debugPrint('⚠️ 启动本地回环失败: $e');
    }
  }

  void _stopLocalLoopback() {
    _localLoopbackService?.stop();
    _localLoopbackService?.dispose();
    _localLoopbackService = null;
    _scheduleNotify();
  }

  void stopTransfer() {
    _stopRequested = true;
    if (!_isTransferring && !_isPreparingSend) return;

    _isTransferring = false;
    _finishPreparingSend();
    _status = TransferStatus.idle;
    _currentSendingScripture = '';

    _platformGlobalSendService?.stopSending();
    _stopFieldEnergyBroadcast();
    _stopLocalLoopback();
    _stopBackgroundService();

    _loopCount = 0;
    _loopbackCount = 0;
    _fieldBroadcastCount = 0;
    _releaseCachedScriptures();

    _schedulePersist(_persistTransferState);
    debugPrint('🛑 传输已停止');
    _scheduleNotify();
  }

  void _onTransferCompleted() {
    _isTransferring = false;
    _finishPreparingSend();
    _status = TransferStatus.completed;
    _currentSendingScripture = '';
    _schedulePersist(_persistTransferState);
    _scheduleNotify();
  }

  Future<void> _startBackgroundService() async {
    try {
      final fileName = _selectedFiles.isNotEmpty
          ? (_currentSendingScripture.isNotEmpty
                ? _currentSendingScripture
                : _displayScriptureName(_selectedFiles.first.name))
          : '未知文件';

      await _keepAliveService.start(
        audioName: fileName,
        totalCountries: _countryStatuses.length,
      );

      debugPrint('✅ 后台音频服务已启动');
    } catch (e) {
      debugPrint('⚠️ 启动后台服务失败: $e');
    }
  }

  void _onToggleAudioMute() async {
    debugPrint('🔇 收到静音切换请求');
    await _keepAliveService.toggleMute();
  }

  Future<void> _stopBackgroundService() async {
    try {
      await _keepAliveService.stop();
      debugPrint('✅ 后台音频服务已停止');
    } catch (e) {
      debugPrint('⚠️ 停止后台服务失败: $e');
    }
  }

  void _updateBackgroundServiceProgress(String country, int sent, int total) {
    _keepAliveService.updateProgress(
      sentCount: sent,
      totalCount: total,
      currentCountry: country,
      audioName: _currentSendingScripture.isNotEmpty
          ? _currentSendingScripture
          : null,
      loopCount: _loopCount,
      isLoopbackActive: _localLoopbackService?.isRunning ?? false,
      loopbackCount: _loopbackCount,
    );
  }

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
        debugPrint('📡 [GlobalSend] $message');
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
        _loopCount = loopNum;
        debugPrint('🔄 轮次更新: $_loopCount');
        _scheduleNotify();
      },
      userLatitude: userLat,
      userLongitude: userLng,
    );

    await _platformGlobalSendService?.initialize();
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
    if (logMessage.contains('成功')) {
      final udpRegex = RegExp(r'发送到\s+([^\s(]+)\s+\(([A-Z]{2})\)\s+成功');
      final udpMatch = udpRegex.firstMatch(logMessage);
      if (udpMatch != null) {
        final countryName = udpMatch.group(1)?.trim();
        if (countryName != null) {
          updateCountryStatus(countryName, SendStatus.success);
          _updateBackgroundServiceProgress(
            countryName,
            _globalSentCount,
            _countryStatuses.isNotEmpty ? _countryStatuses.length : 200,
          );
        }
        return;
      }

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

    String currentCountry = '全球';
    if (_countryStatuses.isNotEmpty &&
        count > 0 &&
        count <= _countryStatuses.length) {
      currentCountry = _countryStatuses[count - 1].countryName;
    }

    _updateBackgroundServiceProgress(
      currentCountry,
      count,
      _totalCountriesCount,
    );

    _scheduleNotify();
  }

  int get _totalCountriesCount =>
      _countryStatuses.isNotEmpty ? _countryStatuses.length : 249;

  void updateDataSent(double dataMB) {
    _globalDataSentMB = dataMB;
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
      if (status == SendStatus.success || status == SendStatus.failed) {
        _schedulePersist(_persistCountryStatuses);
      }
      _scheduleNotify();
    }
  }

  void updateLog(String log) {
    _currentLog = log;
    _updateCurrentSendingScriptureFromLog(log);
    if (log.contains('成功') || log.contains('失败') || log.contains('完成')) {
      _schedulePersist(_persistTransferState);
    }
    _scheduleNotify();
  }

  void _updateCurrentSendingScriptureFromLog(String log) {
    final match = RegExp(
      r'(?:正在发送到|准备发送|UDP 发送到|发送到)[^《]*《([^》]+)》',
    ).firstMatch(log);
    final scripture = match?.group(1)?.trim();
    if (scripture != null && scripture.isNotEmpty) {
      _currentSendingScripture = scripture;
    }
  }

  String _displayScriptureName(String fileName) {
    final withoutExtension = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final withoutCbetaPrefix = withoutExtension.replaceFirst(
      RegExp(r'^[A-Z][A-Z0-9]?\d{4}[A-Z]?_\d+_'),
      '',
    );
    final normalized = withoutCbetaPrefix.replaceAll('_', ' ').trim();
    return normalized.isEmpty ? withoutExtension : normalized;
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
    _releaseCachedScriptures();
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
