import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/country_servers.dart' as country_catalog;

enum TransferStatus { idle, transferring, completed, error }

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

class FileTransferModel extends ChangeNotifier {
  List<PlatformFile> _selectedFiles = [];
  List<String> _countryList = const ['ALL'];
  List<CountrySendStatus> _countryStatuses = [];

  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  bool _isLocalLoopbackEnabled = false;
  bool _isFieldEnergyMode = false;
  bool _isPreparingSend = false;
  bool _isTransferring = false;
  bool _needsHotspotGuide = false;
  TransferStatus _status = TransferStatus.idle;
  final String _preparingSendMessage = '';
  String _currentLog = '';
  String _currentSendingScripture = '';
  String _selectedContentKind = '';
  String _selectedContentTitle = '';
  String _selectedContentSubtitle = '';
  String? _selectedContentPreviewText;
  String? _selectedContentSourceUrl;
  int _globalSentCount = 0;
  double _globalDataSentMB = 0;
  Timer? _completionTimer;

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

  PlatformFile? get selectedFile =>
      _selectedFiles.isNotEmpty ? _selectedFiles.first : null;
  List<PlatformFile> get selectedFiles => List.unmodifiable(_selectedFiles);
  List<String> get countryList => List.unmodifiable(_countryList);
  bool get isGlobalSendEnabled => _isGlobalSendEnabled;
  bool get isLooping => _isLooping;
  bool get isLocalLoopbackEnabled => _isLocalLoopbackEnabled;
  bool get isFieldEnergyMode => _isFieldEnergyMode;
  bool get needsHotspotGuide => _needsHotspotGuide;
  String get hotspotMessage => kIsWeb && _isFieldEnergyMode
      ? 'Web 平台不支持自动开启热点'
      : '';
  bool get isTransferring => _isTransferring;
  bool get isPreparingSend => _isPreparingSend;
  String get preparingSendMessage => _preparingSendMessage;
  TransferStatus get status => _status;
  bool get hasFiles => _selectedFiles.isNotEmpty;
  int get globalSentCount => _globalSentCount;
  double get globalDataSentMB => _globalDataSentMB;
  List<CountrySendStatus> get countryStatuses =>
      List.unmodifiable(_countryStatuses);
  String get currentLog => _currentLog;
  String get currentSendingScripture => _currentSendingScripture;
  String get selectedContentKind => _selectedContentKind;
  String get selectedContentTitle => _selectedContentTitle;
  String get selectedContentSubtitle => _selectedContentSubtitle;
  String? get selectedContentPreviewText => _selectedContentPreviewText;
  String? get selectedContentSourceUrl => _selectedContentSourceUrl;
  bool get hasSelectedContentPreview =>
      (_selectedContentPreviewText?.trim().isNotEmpty ?? false);

  void setGlobalSendEnabled(bool enabled) {
    _isGlobalSendEnabled = enabled;
    notifyListeners();
  }

  void setLooping(bool looping) {
    _isLooping = looping;
    notifyListeners();
  }

  void setLocalLoopbackEnabled(bool enabled) {
    _isLocalLoopbackEnabled = enabled;
    notifyListeners();
  }

  Future<void> setFieldEnergyMode(bool enabled) async {
    _isFieldEnergyMode = enabled;
    _needsHotspotGuide = false;
    notifyListeners();
  }

  void setCountryList(List<String> countries) {
    _countryList = countries.isEmpty ? <String>[] : countries.toSet().toList();
    notifyListeners();
  }

  void clearHotspotGuide() {
    _needsHotspotGuide = false;
    notifyListeners();
  }

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

  Future<bool> selectFiles({bool replaceExisting = true}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return false;

    if (replaceExisting) {
      _selectedFiles = files;
    } else {
      _selectedFiles = [..._selectedFiles, ...files];
    }
    _setSelectedContentSummary(
      kind: '本机文件',
      title: files.length == 1 ? files.first.name : '已选择 ${files.length} 个文件',
      subtitle: _fileSummary(_selectedFiles),
      previewText: files.map((file) => file.name).join('\n'),
    );
    notifyListeners();
    return true;
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
    } else {
      _selectedFiles = [..._selectedFiles, file];
    }
    _currentSendingScripture = title.isEmpty ? file.name : title;
    _currentLog = sourceKind == '链接'
        ? '已选择链接内容: ${title.isEmpty ? file.name : title}'
        : '已选择文本内容: $fileName';
    _setSelectedContentSummary(
      kind: sourceKind,
      title: title.isEmpty ? file.name : title,
      subtitle: '${normalizedText.length} 字 · ${_formatSize(bytes.length)}',
      previewText: previewText ?? normalizedText,
      sourceUrl: sourceUrl,
    );
    notifyListeners();
  }

  Future<void> addUrlContentForSending(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw ArgumentError('请输入 http/https 链接');
    }

    await addTextContentForSending(
      title: uri.host,
      text: url.trim(),
      sourceKind: '链接',
      sourceUrl: url.trim(),
      previewText: url.trim(),
    );
  }

  Future<void> addZenBuddhaAssetForSending() async {
    await addTextContentForSending(
      title: '3D佛像素材',
      text: 'Web 端已选择 3D佛像素材。请在 App 内下载完整素材后进行高能发送。',
      sourceKind: '3D佛像素材',
      previewText: 'Web 端保留首页轻量体验，素材下载与本地文件发送请使用 App。',
    );
  }

  void clearFiles() {
    _selectedFiles = [];
    _clearSelectedContentSummary();
    _currentSendingScripture = '';
    _currentLog = '';
    notifyListeners();
  }

  Future<void> startGlobalTransfer({
    bool isLoopContinuation = false,
    bool forceSingleRound = false,
  }) async {
    if (_selectedFiles.isEmpty || _isTransferring) return;

    _completionTimer?.cancel();
    _isPreparingSend = false;
    _isTransferring = true;
    _status = TransferStatus.transferring;
    _currentLog = 'Web 轻量发送正在准备 HTTP 节点';
    _countryStatuses = _buildCountryStatuses(SendStatus.sending);
    _globalSentCount = 0;
    _globalDataSentMB = 0;
    notifyListeners();

    _onTransferBeam?.call(
      31.2304,
      121.4737,
      1.3521,
      103.8198,
      fromLabel: 'Web',
      toLabel: '全球',
      displayDuration: const Duration(seconds: 2),
    );

    _completionTimer = Timer(const Duration(milliseconds: 900), () {
      _isTransferring = false;
      _status = TransferStatus.completed;
      _countryStatuses = _buildCountryStatuses(SendStatus.success);
      _globalSentCount = _countryStatuses.length;
      _globalDataSentMB =
          _selectedFiles.fold<int>(0, (sum, file) => sum + file.size) /
          (1024 * 1024);
      _currentLog = 'Web 首页轻量发送完成';
      notifyListeners();
    });
  }

  void stopTransfer() {
    _completionTimer?.cancel();
    _isPreparingSend = false;
    _isTransferring = false;
    _status = TransferStatus.idle;
    _currentLog = '已停止发送';
    notifyListeners();
  }

  List<CountrySendStatus> _buildCountryStatuses(SendStatus status) {
    final source = _countryList.contains('ALL')
        ? country_catalog.GLOBAL_COUNTRY_SERVERS.entries.take(8)
        : country_catalog.GLOBAL_COUNTRY_SERVERS.entries.where(
            (entry) => _countryList.contains(entry.key),
          );

    return source
        .map(
          (entry) => CountrySendStatus(
            countryCode: entry.key,
            countryName: country_catalog.COUNTRY_NAMES[entry.key] ?? entry.key,
            status: status,
            serverCount: entry.value.length,
          ),
        )
        .toList();
  }

  void _setSelectedContentSummary({
    required String kind,
    required String title,
    required String subtitle,
    String? previewText,
    String? sourceUrl,
  }) {
    _selectedContentKind = kind;
    _selectedContentTitle = title;
    _selectedContentSubtitle = subtitle;
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

  String _fileSummary(List<PlatformFile> files) {
    final totalBytes = files.fold<int>(0, (sum, file) => sum + file.size);
    return '${files.length} 个文件 · ${_formatSize(totalBytes)}';
  }

  String _formatSize(int bytes) {
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  String _safeFileName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return safe.isEmpty ? 'text' : safe;
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }
}
