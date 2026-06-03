import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import '../core/config/app_config.dart';
import '../core/constants/country_servers.dart' as country_catalog;
import '../screens/asset_screen.dart';
import '../services/asset_loader_service.dart';
import '../services/shared_asset_manager.dart';
import '../services/download_manager.dart' show DownloadStatus;
import '../services/real_global_send_service.dart';
import '../services/platform_global_send_service.dart';
import '../services/ip_location_service.dart';
import '../services/leaderboard_service.dart';
import '../services/wifi_field_broadcast_service.dart';
import '../services/hotspot_manager_service.dart';
import '../services/keep_alive_service.dart';
import '../widgets/download_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/startup/deferred_loader.dart';
import '../services/local_loopback_service.dart';
import '../services/workmanager_keep_alive.dart';

enum TransferStatus { idle, transferring, completed, error }

class LinkSendHistoryEntry {
  final String url;
  final String title;
  final String preview;
  final DateTime savedAt;

  const LinkSendHistoryEntry({
    required this.url,
    required this.title,
    required this.preview,
    required this.savedAt,
  });

  factory LinkSendHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LinkSendHistoryEntry(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'preview': preview,
    'savedAt': savedAt.toIso8601String(),
  };
}

class FileTransferModel extends ChangeNotifier with WidgetsBindingObserver {
  static const String _linkHistoryPrefsKey = 'send_link_history_v1';
  static const String _sendCountryListPrefsKey = 'send_country_list_v1';
  static const int _maxLinkHistoryEntries = 20;
  static const int _linkHistoryPreviewLimit = 600;
  static const int _largePayloadThresholdBytes = 1024 * 1024;

  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  bool _isLocalLoopbackEnabled = false;
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
  double? _currentCountryProgress;

  RealGlobalSendService? _realGlobalSendService;
  PlatformGlobalSendService? _platformGlobalSendService;
  List<CountrySendStatus> _countryStatuses = [];
  String _currentLog = '';
  String _currentSendingScripture = '';
  String _selectedContentKind = '';
  String _selectedContentTitle = '';
  String _selectedContentSubtitle = '';
  String? _selectedContentPreviewText;
  String? _selectedContentSourceUrl;
  List<LinkSendHistoryEntry> _linkHistory = [];

  final SharedAssetManager _sharedAssetManager = SharedAssetManager();
  final IPLocationService _ipLocationService = IPLocationService();
  final Map<String, Uint8List> _downloadedScriptureMemory = {};

  WiFiFieldBroadcastService? _fieldBroadcastService;
  final HotspotManagerService _hotspotManager = HotspotManagerService();
  String _hotspotMessage = '';

  final KeepAliveService _keepAliveService = KeepAliveService.instance;
  bool _needsHotspotGuide = false;

  LocalLoopbackService? _localLoopbackService;

  bool _isDisposed = false;
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
  bool get isLocalLoopbackEnabled => _isLocalLoopbackEnabled;
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
  double? get currentCountryProgress => _currentCountryProgress;
  List<CountrySendStatus> get countryStatuses => _countryStatuses;
  String get currentLog => _currentLog;
  String get currentSendingScripture => _currentSendingScripture;
  bool get isCurrentMaterialCompleted =>
      (_currentLog.contains('文件《') && _currentLog.contains('发送完成')) ||
      (_currentLog.contains('UDP 发送到') && _currentLog.contains('成功')) ||
      _currentLog.contains('已完整发送') ||
      _currentLog.contains('流式发送完成');
  String get selectedContentKind => _selectedContentKind;
  String get selectedContentTitle => _selectedContentTitle;
  String get selectedContentSubtitle => _selectedContentSubtitle;
  String? get selectedContentPreviewText => _selectedContentPreviewText;
  String? get selectedContentSourceUrl => _selectedContentSourceUrl;
  bool get hasSelectedContentPreview =>
      (_selectedContentPreviewText?.trim().isNotEmpty ?? false);
  List<LinkSendHistoryEntry> get linkHistory => List.unmodifiable(_linkHistory);

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
    _schedulePersist(_persistSendPreferences);
    notifyListeners();
  }

  void setLooping(bool looping) {
    _isLooping = looping;
    _schedulePersist(_persistSendPreferences);
    notifyListeners();
  }

  void setLocalLoopbackEnabled(bool enabled) {
    if (_isLocalLoopbackEnabled == enabled) return;
    _isLocalLoopbackEnabled = enabled;
    if (!enabled) {
      _loopbackCount = 0;
      _stopLocalLoopback();
    }
    _schedulePersist(_persistSendPreferences);
    notifyListeners();
  }

  Future<void> setFieldEnergyMode(bool enabled) async {
    _isFieldEnergyMode = enabled;
    _hotspotMessage = '';
    _needsHotspotGuide = false;
    _schedulePersist(_persistSendPreferences);
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
    _countryList = countries.isEmpty ? <String>[] : countries.toSet().toList();
    _schedulePersist(_persistSendPreferences);
    notifyListeners();
  }

  List<String>? get _selectedGlobalCountryCodes {
    if (!_isGlobalSendEnabled || _countryList.isEmpty) {
      return const [];
    }
    if (_countryList.contains('ALL')) {
      return null;
    }
    return _countryList
        .where(
          (code) => country_catalog.GLOBAL_COUNTRY_SERVERS.containsKey(code),
        )
        .toSet()
        .toList();
  }

  void _prepareCountryStatusesForTargets(List<String>? countryCodes) {
    final servers = countryCodes == null
        ? country_catalog.GLOBAL_COUNTRY_SERVERS
        : {
            for (final code in countryCodes)
              if (country_catalog.GLOBAL_COUNTRY_SERVERS.containsKey(code))
                code: country_catalog.GLOBAL_COUNTRY_SERVERS[code]!,
          };
    initializeCountryStatuses(servers, country_catalog.COUNTRY_NAMES);
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

  void _releaseCachedScriptures({bool clearSelection = true}) {
    _downloadedScriptureMemory.clear();
    if (clearSelection) {
      _selectedFiles = [];
      _clearSelectedContentSummary();
    }
  }

  void _setSelectedContentSummary({
    required String kind,
    required String title,
    required String subtitle,
    String? previewText,
    String? sourceUrl,
  }) {
    _selectedContentKind = kind;
    _selectedContentTitle = title.trim().isEmpty ? kind : title.trim();
    _selectedContentSubtitle = subtitle.trim();
    _selectedContentPreviewText = previewText;
    _selectedContentSourceUrl = sourceUrl;
  }

  void _clearSelectedContentSummary() {
    _selectedContentKind = '';
    _selectedContentTitle = '';
    _selectedContentSubtitle = '';
    _selectedContentPreviewText = null;
    _selectedContentSourceUrl = null;
  }

  void _updateFileSelectionSummary({String kind = '文件'}) {
    if (_selectedFiles.isEmpty) {
      _clearSelectedContentSummary();
      return;
    }

    final totalBytes = _selectedFiles.fold<int>(
      0,
      (sum, file) => sum + file.size,
    );
    final first = _selectedFiles.first;
    final title = _selectedFiles.length == 1
        ? first.name
        : '${first.name} 等 ${_selectedFiles.length} 个文件';
    _setSelectedContentSummary(
      kind: kind,
      title: title,
      subtitle: '${getFileSizeString(totalBytes)} · 点此重新选择发送内容',
      previewText: _selectedFiles.length == 1
          ? '文件名: ${first.name}\n大小: ${getFileSizeString(first.size)}'
          : '已选择 ${_selectedFiles.length} 个文件\n总大小: ${getFileSizeString(totalBytes)}',
    );
  }

  Future<int> startDefaultScriptureSendSequence() async {
    if (_isPreparingSend || _isTransferring) return 0;

    if (!hasFiles) {
      updateLog('请先选择链接、文本、本机文件或3D佛像素材后再发送。');
      return 0;
    }

    await startGlobalTransfer(forceSingleRound: true);
    return _globalSentCount;
  }

  Future<int> prepareDefaultNonR2AssetsForSending() async {
    if (!hasFiles) {
      updateLog('请先选择链接、文本、本机文件或3D佛像素材后再发送。');
      return 0;
    }

    _isLooping = true;
    updateLog('已使用当前选择的内容准备发送。');
    notifyListeners();
    return _selectedFiles.length;
  }

  Future<bool> selectFiles({bool replaceExisting = true}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: kIsWeb,
        withReadStream: !kIsWeb,
      );

      if (result != null) {
        if (replaceExisting) {
          _selectedFiles = result.files;
        } else {
          _selectedFiles.addAll(result.files);
        }
        _downloadedScriptureMemory.clear();
        _updateFileSelectionSummary(kind: '本机文件');
        notifyListeners();

        for (final file in result.files) {
          debugPrint(
            '已选择文件: ${file.name}, 大小: ${(file.size / 1024 / 1024).toStringAsFixed(1)}MB, 路径: ${file.path ?? "无"}',
          );
        }
        debugPrint('已选择 ${result.files.length} 个文件');
        return result.files.isNotEmpty;
      }
    } catch (e) {
      debugPrint('选择文件失败: $e');
    }
    return false;
  }

  Future<void> selectBuiltInAssets(BuildContext context) async {
    final selectedAssets = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AssetScreen()),
    );

    if (selectedAssets != null &&
        selectedAssets is List &&
        selectedAssets.isNotEmpty) {
      if (!context.mounted) return;
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
      if (!context.mounted) return;

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
          alreadyDownloadedAssets,
        );
        if (failedAssets.isNotEmpty) {
          needDownloadAssets.addAll(failedAssets);
          debugPrint('⚠️ ${failedAssets.length} 个素材需要重新下载');
        }
      }

      if (needDownloadAssets.isNotEmpty) {
        for (String assetPath in needDownloadAssets) {
          if (!context.mounted) return;
          await _downloadSingleAsset(context, assetPath);
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('所有素材处理完成')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<String>> _reuseDownloadedAssets(List<String> assetPaths) async {
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
      if (!context.mounted) return;
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
    _updateFileSelectionSummary(kind: '素材文件');
    debugPrint(
      '📁 添加文件: ${files.map((f) => f.name).join(', ')}，当前总数: ${_selectedFiles.length}',
    );
    notifyListeners();
  }

  Future<void> addTextContentForSending({
    required String title,
    required String text,
    bool replaceExisting = true,
    String sourceKind = '文本',
    String? sourceUrl,
    String? previewText,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError('请输入要发送的文本内容');
    }

    final fileName = '${_safeFileName(title.isEmpty ? 'text' : title)}.txt';
    final bytes = Uint8List.fromList(utf8.encode(normalizedText));
    final file = PlatformFile(name: fileName, size: bytes.length, bytes: bytes);

    if (replaceExisting) {
      _selectedFiles = [file];
      _downloadedScriptureMemory
        ..clear()
        ..[file.name] = bytes;
    } else {
      addFiles([file]);
      _downloadedScriptureMemory[file.name] = bytes;
      _setSelectedContentSummary(
        kind: sourceKind,
        title: title.isEmpty ? file.name : title,
        subtitle:
            '${normalizedText.length} 字 · ${getFileSizeString(bytes.length)}',
        previewText: previewText ?? normalizedText,
        sourceUrl: sourceUrl,
      );
      return;
    }

    _currentSendingScripture = _displayScriptureName(file.name);
    _setSelectedContentSummary(
      kind: sourceKind,
      title: title.isEmpty ? _currentSendingScripture : title,
      subtitle:
          '${normalizedText.length} 字 · ${getFileSizeString(bytes.length)}',
      previewText: previewText ?? normalizedText,
      sourceUrl: sourceUrl,
    );
    _currentLog = sourceKind == '链接'
        ? '已选择链接内容: ${title.isEmpty ? file.name : title}'
        : '已选择文本内容: ${file.name}';
    notifyListeners();
  }

  Future<void> addUrlContentForSending(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw ArgumentError('请输入 http/https 链接');
    }

    beginPreparingSend('正在读取链接内容...');
    try {
      final response = await _fetchReadableLink(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('链接读取失败: HTTP ${response.statusCode}');
      }

      final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (_looksLikeWeChatVerificationPage(raw)) {
        throw StateError('微信链接返回了环境验证页，请稍后重试或重新复制文章链接。');
      }
      final contentType = response.headers['content-type'] ?? '';
      final isHtml =
          contentType.toLowerCase().contains('html') ||
          RegExp(r'<html|<body|<p[>\s]', caseSensitive: false).hasMatch(raw);
      final extractedTitle = isHtml ? _extractHtmlTitle(raw) : null;
      final bodyText = isHtml ? _htmlToReadableText(raw) : raw.trim();
      final title = extractedTitle?.trim().isNotEmpty == true
          ? extractedTitle!.trim()
          : _titleFromUri(uri);
      final sendText = [
        '来源链接: ${uri.toString()}',
        '',
        bodyText.isEmpty ? uri.toString() : bodyText,
      ].join('\n');

      await addTextContentForSending(
        title: title,
        text: sendText,
        sourceKind: '链接',
        sourceUrl: uri.toString(),
        previewText: bodyText.isEmpty ? uri.toString() : bodyText,
      );
      await _rememberLinkHistory(
        url: uri.toString(),
        title: title,
        preview: bodyText.isEmpty ? uri.toString() : bodyText,
      );
      _currentLog = bodyText.isEmpty
          ? '链接未返回正文，已保存链接: $title'
          : '已读取链接正文: $title（${bodyText.length} 字）';
    } finally {
      _finishPreparingSend();
      notifyListeners();
    }
  }

  Future<http.Response> _fetchReadableLink(Uri uri) async {
    final candidates = <Uri>[
      if (_isWeChatArticleUri(uri)) _withWeChatArticleFlags(uri),
      uri,
    ];

    http.Response? lastResponse;
    Object? lastError;
    for (final candidate in candidates) {
      try {
        final response = await http
            .get(candidate, headers: _linkRequestHeaders(candidate))
            .timeout(const Duration(seconds: 25));
        lastResponse = response;
        final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            !_looksLikeWeChatVerificationPage(raw)) {
          return response;
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (lastResponse != null) return lastResponse;
    throw StateError('链接读取失败: $lastError');
  }

  Map<String, String> _linkRequestHeaders(Uri uri) {
    final isWeChat = _isWeChatArticleUri(uri);
    return {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,text/plain;q=0.8,*/*;q=0.7',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Cache-Control': 'no-cache',
      'User-Agent': isWeChat
          ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.49'
          : 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
      if (isWeChat) 'Referer': 'https://mp.weixin.qq.com/',
    };
  }

  bool _isWeChatArticleUri(Uri uri) =>
      uri.host.toLowerCase() == 'mp.weixin.qq.com' &&
      (uri.path == '/s' || uri.path.startsWith('/s/'));

  Uri _withWeChatArticleFlags(Uri uri) {
    final query = Map<String, String>.from(uri.queryParameters);
    query.putIfAbsent('nwr_flag', () => '1');
    return uri.replace(queryParameters: query);
  }

  bool _looksLikeWeChatVerificationPage(String html) {
    return html.contains('当前环境异常') &&
        html.contains('完成验证后即可继续访问') &&
        html.contains('环境异常');
  }

  Future<void> _rememberLinkHistory({
    required String url,
    required String title,
    required String preview,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) return;

    final normalizedPreview = _compactPreview(preview);
    _linkHistory = [
      LinkSendHistoryEntry(
        url: normalizedUrl,
        title: title.trim().isEmpty ? normalizedUrl : title.trim(),
        preview: normalizedPreview,
        savedAt: DateTime.now(),
      ),
      ..._linkHistory.where((entry) => entry.url != normalizedUrl),
    ].take(_maxLinkHistoryEntries).toList();

    _schedulePersist(_persistLinkHistory);
  }

  String _compactPreview(String value) {
    final normalized = value
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (normalized.length <= _linkHistoryPreviewLimit) {
      return normalized;
    }
    return '${normalized.substring(0, _linkHistoryPreviewLimit)}...';
  }

  Future<void> addZenBuddhaAssetForSending() async {
    beginPreparingSend('正在准备3D佛像素材...');
    try {
      final file = await AssetLoaderService.getPersistentAssetFile(
        AppConfig.buddhaModelAssetPath,
        ensureLoaded: true,
        onProgress: (progress) {
          _preparingSendMessage =
              '正在准备3D佛像素材 ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
          notifyListeners();
        },
      );
      if (file == null || !await file.exists()) {
        throw StateError('未找到3D佛像素材');
      }

      final size = await file.length();
      final platformFile = PlatformFile(
        name: _pathBasename(AppConfig.buddhaModelAssetPath),
        size: size,
        path: file.path,
      );
      _selectedFiles = [platformFile];
      _downloadedScriptureMemory.clear();
      _currentSendingScripture = AppConfig.zenBuddhaAssetDisplayName;
      _currentLog =
          '已选择${AppConfig.zenBuddhaAssetDisplayName}: ${platformFile.name}';
      _setSelectedContentSummary(
        kind: AppConfig.zenBuddhaAssetDisplayName,
        title: AppConfig.zenBuddhaAssetDisplayName,
        subtitle: '${getFileSizeString(size)} · ${platformFile.name} · 点此查看素材',
        previewText:
            '${AppConfig.zenBuddhaAssetDisplayName}\n文件名: ${platformFile.name}\n大小: ${getFileSizeString(size)}',
      );
    } finally {
      _finishPreparingSend();
      notifyListeners();
    }
  }

  void removeFile(PlatformFile file) {
    _selectedFiles.remove(file);
    _downloadedScriptureMemory.remove(file.name);
    _updateFileSelectionSummary();
    debugPrint('🗑️ 移除文件: ${file.name}，当前总数: ${_selectedFiles.length}');
    notifyListeners();
  }

  void clearFiles() {
    _selectedFiles.clear();
    _downloadedScriptureMemory.clear();
    _clearSelectedContentSummary();
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
    final targetCountryCodes = _selectedGlobalCountryCodes;
    final shouldSendGlobal =
        _isGlobalSendEnabled &&
        (targetCountryCodes == null || targetCountryCodes.isNotEmpty);
    final shouldRunLocal =
        _isFieldEnergyMode || (_isLocalLoopbackEnabled && !kIsWeb);

    if (!shouldSendGlobal && !shouldRunLocal) {
      updateLog('请先在地区中选择全球、国家、本地场能或本地转经轮。');
      _finishPreparingSend();
      _scheduleNotify();
      return;
    }

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

    if (shouldSendGlobal) {
      _prepareCountryStatusesForTargets(targetCountryCodes);
    } else {
      _countryStatuses = [];
    }

    _globalSentCount = 0;
    _loopbackCount = 0;
    _currentCountryProgress = null;

    _schedulePersist(_persistTransferState);
    _scheduleNotify();

    try {
      debugPrint(
        '🚀 开始传输 - 文件数量: ${_selectedFiles.length}, 全球发送: $shouldSendGlobal, 循环: $shouldLoop, 轮次: $_loopCount, 场能模式: $_isFieldEnergyMode, 本地回环: $_isLocalLoopbackEnabled',
      );

      if (!isLoopContinuation) {
        await _startBackgroundService();
        if (_isFieldEnergyMode && !kIsWeb) {
          await _startFieldEnergyBroadcast();
        }
      }

      if (_isLocalLoopbackEnabled) {
        await _startLocalLoopback();
      }

      if (!shouldSendGlobal) {
        updateLog('本地模块运行中，可点击停止结束。');
        _schedulePersist(_persistTransferState);
        _scheduleNotify();
        return;
      }

      debugPrint('🔧 准备初始化平台全球发送服务...');
      await _initializePlatformGlobalSendService();
      debugPrint('🔧 平台服务初始化完成，准备开始发送...');
      await _platformGlobalSendService?.startSending(
        files: _selectedFiles,
        isLoop: shouldLoop,
        countryCodes: targetCountryCodes,
      );
      debugPrint('🔧 发送方法执行完毕，准备上传数据...');
      await _uploadPendingData();

      debugPrint('✅ 传输完成，循环模式: $shouldLoop, 轮次: $_loopCount');

      _stopFieldEnergyBroadcast();
      _stopLocalLoopback();
      await _stopBackgroundService();
      _isTransferring = false;
      _status = TransferStatus.completed;
      _currentSendingScripture = '';
      _currentCountryProgress = null;
    } catch (e) {
      debugPrint('❌ 传输失败: $e');
      _status = TransferStatus.error;
      _isTransferring = false;
      _finishPreparingSend();
      _currentSendingScripture = '';
      _currentCountryProgress = null;
      _stopFieldEnergyBroadcast();
      _stopLocalLoopback();
      await _stopBackgroundService();
      _schedulePersist(_persistTransferState);
      _scheduleNotify();
    }
  }

  Future<void> _startFieldEnergyBroadcast() async {
    if (kIsWeb) return;
    if (_selectedFiles.isEmpty) return;

    if (!_isTransferring && _isLocalLoopbackEnabled) {
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
      final originalSize = file.size;

      if (fileBytes != null || file.path != null) {
        await _fieldBroadcastService!.startBroadcast(
          data: fileBytes,
          filePath: file.path,
          fileName: file.name,
          originalSize: originalSize,
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

    if (!_isTransferring && _isLocalLoopbackEnabled) {
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
      final isLargePayload = file.size >= _largePayloadThresholdBytes;
      await _localLoopbackService!.start(
        data: file.bytes,
        filePath: file.path,
        fileName: file.name,
        mode: LoopbackRunMode.isolate,
        speedLevel: isLargePayload
            ? LoopbackSpeedLevel.normal
            : LoopbackSpeedLevel.high,
      );
      _loopbackCount = 1;
      _scheduleNotify();
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
    if (!_isTransferring && !_isPreparingSend) return;

    _isTransferring = false;
    _finishPreparingSend();
    _status = TransferStatus.idle;
    _currentSendingScripture = '';
    _currentCountryProgress = null;

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
    _currentCountryProgress = null;
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

      debugPrint('✅ 无音频后台辅助服务已启动');
    } catch (e) {
      debugPrint('⚠️ 启动后台服务失败: $e');
    }
  }

  // ignore: unused_element
  void _onToggleAudioMute() async {
    debugPrint('🔇 收到静音切换请求');
    await _keepAliveService.toggleMute();
  }

  Future<void> _stopBackgroundService() async {
    try {
      await _keepAliveService.stop();
      debugPrint('✅ 无音频后台辅助服务已停止');
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
      onCountryProgress: (progress) {
        _currentCountryProgress = progress.clamp(0.0, 1.0);
        _scheduleNotify();
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

  // ignore: unused_element
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
    _currentCountryProgress = null;

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
    if (isCurrentMaterialCompleted) {
      _currentCountryProgress = 1.0;
    }
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

  String _safeFileName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    if (safe.isEmpty) return 'content';
    return safe.length > 80 ? safe.substring(0, 80) : safe;
  }

  String _pathBasename(String value) {
    final parts = value.split(RegExp(r'[\\/]'));
    return parts.isEmpty || parts.last.isEmpty ? value : parts.last;
  }

  String _titleFromUri(Uri uri) {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty) {
      return Uri.decodeComponent(
        uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), ''),
      );
    }
    return uri.host.isEmpty ? 'link' : uri.host;
  }

  String? _extractHtmlTitle(String html) {
    final metaTitle = RegExp(
      r'<meta[^>]+property=["'
      ']og:title["'
      '][^>]+content=["'
      ']([^"'
      ']+)["'
      '][^>]*>',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (metaTitle != null && metaTitle.trim().isNotEmpty) {
      return _decodeHtmlEntities(metaTitle).trim();
    }

    final activityName = _extractHtmlSectionById(html, 'activity-name');
    if (activityName != null && activityName.trim().isNotEmpty) {
      return _decodeHtmlEntities(
        activityName.replaceAll(RegExp(r'<[^>]+>'), ''),
      ).trim();
    }

    final title = RegExp(
      r'<title>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (title == null) return null;
    return _decodeHtmlEntities(title.replaceAll(RegExp(r'<[^>]+>'), '')).trim();
  }

  String _htmlToReadableText(String html) {
    final bodyMatch = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(html);
    var source =
        _extractHtmlSectionById(html, 'js_content') ??
        _extractHtmlSectionById(html, 'js_content_container') ??
        bodyMatch?.group(1) ??
        html;
    source = source
        .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<rt[\s\S]*?</rt>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<rp[\s\S]*?</rp>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'<(p|div|section|br|h[1-6]|li|tr)\b[^>]*>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(
          RegExp(r'</(p|div|section|h[1-6]|li|tr)>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '');

    return _decodeHtmlEntities(source)
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String? _extractHtmlSectionById(String html, String id) {
    final startMatch = RegExp(
      '<([a-zA-Z0-9]+)[^>]*\\bid=["\\\']${RegExp.escape(id)}["\\\'][^>]*>',
      caseSensitive: false,
    ).firstMatch(html);
    if (startMatch == null) return null;

    final tag = startMatch.group(1);
    if (tag == null || tag.isEmpty) return null;

    final tagRegex = RegExp('</?$tag\\b[^>]*>', caseSensitive: false);
    var depth = 1;
    for (final match in tagRegex.allMatches(html, startMatch.end)) {
      final token = match.group(0) ?? '';
      final isClosing = token.startsWith('</');
      final isSelfClosing = token.endsWith('/>');
      if (isClosing) {
        depth--;
        if (depth == 0) {
          return html.substring(startMatch.end, match.start);
        }
      } else if (!isSelfClosing) {
        depth++;
      }
    }

    return null;
  }

  String _decodeHtmlEntities(String value) {
    const named = {
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
      'nbsp': ' ',
    };
    return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
      match,
    ) {
      final code = match.group(1) ?? '';
      if (code.startsWith('#x') || code.startsWith('#X')) {
        final parsed = int.tryParse(code.substring(2), radix: 16);
        return parsed == null ? match.group(0)! : String.fromCharCode(parsed);
      }
      if (code.startsWith('#')) {
        final parsed = int.tryParse(code.substring(1));
        return parsed == null ? match.group(0)! : String.fromCharCode(parsed);
      }
      return named[code] ?? match.group(0)!;
    });
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
      _isGlobalSendEnabled = prefs.getBool('send_global_enabled') ?? true;
      _isLooping = prefs.getBool('send_looping') ?? false;
      _isFieldEnergyMode = prefs.getBool('send_field_energy') ?? false;
      _isLocalLoopbackEnabled = prefs.getBool('send_local_loopback') ?? false;

      final countryListJson = prefs.getString(_sendCountryListPrefsKey);
      if (countryListJson != null && countryListJson.isNotEmpty) {
        final decoded = json.decode(countryListJson);
        if (decoded is List) {
          _countryList = decoded
              .whereType<String>()
              .where(
                (code) =>
                    code == 'ALL' ||
                    country_catalog.GLOBAL_COUNTRY_SERVERS.containsKey(code),
              )
              .toSet()
              .toList();
        }
      }
      if (_countryList.isEmpty && _isGlobalSendEnabled) {
        _countryList = ['ALL'];
      }

      final linkHistoryJson = prefs.getString(_linkHistoryPrefsKey);
      if (linkHistoryJson != null && linkHistoryJson.isNotEmpty) {
        final decoded = json.decode(linkHistoryJson);
        if (decoded is List) {
          _linkHistory = decoded
              .whereType<Map<String, dynamic>>()
              .map(LinkSendHistoryEntry.fromJson)
              .where((entry) => entry.url.isNotEmpty)
              .take(_maxLinkHistoryEntries)
              .toList();
        }
      }

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

  Future<void> _persistSendPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('send_global_enabled', _isGlobalSendEnabled);
      await prefs.setBool('send_looping', _isLooping);
      await prefs.setBool('send_field_energy', _isFieldEnergyMode);
      await prefs.setBool('send_local_loopback', _isLocalLoopbackEnabled);
      await prefs.setString(
        _sendCountryListPrefsKey,
        json.encode(_countryList),
      );
    } catch (e) {
      debugPrint('持久化发送偏好失败: $e');
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

  Future<void> _persistLinkHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        _linkHistory.map((entry) => entry.toJson()).toList(),
      );
      await prefs.setString(_linkHistoryPrefsKey, encoded);
    } catch (e) {
      debugPrint('持久化链接历史失败: $e');
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
      await prefs.remove(_linkHistoryPrefsKey);
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
