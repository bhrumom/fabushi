import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../screens/asset_screen.dart';

import '../config/unified_config.dart';
import '../services/downloaded_assets_service.dart';
import '../services/download_manager.dart';
import '../services/real_global_send_service.dart';
import '../services/ip_location_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/download_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Web平台特定的导入
import 'package:universal_html/html.dart' as html;

/// 传输状态枚举
enum TransferStatus { idle, transferring, completed, error }

/// 文件传输模型
///
/// 管理文件传输的状态和逻辑，支持全球发送和WiFi广播
class FileTransferModel extends ChangeNotifier {
  // 传输模式状态
  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  double _sendRateMB = 1.0; // 每秒发送MB数

  // 文件相关
  List<PlatformFile> _selectedFiles = [];
  List<String> _countryList = ['ALL'];

  // 传输状态
  bool _isTransferring = false;
  TransferStatus _status = TransferStatus.idle;

  // 构造函数中加载持久化状态
  FileTransferModel() {
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    await _loadPersistedState();
    // 应用启动时总是清除传输状态
    if (_isTransferring) {
      _isTransferring = false;
      await _persistTransferState();
      debugPrint('🔄 应用启动，清除传输状态');
      notifyListeners();
    }
  }

  // 统计数据
  int _globalSentCount = 0;
  double _globalDataSentMB = 0.0;

  // 真实的全球发送服务
  RealGlobalSendService? _realGlobalSendService;

  // 国家发送状态（持久化）
  List<CountrySendStatus> _countryStatuses = [];
  String _currentLog = '';

  // 已下载素材服务
  final DownloadedAssetsService _downloadedAssetsService =
      DownloadedAssetsService();
  final DownloadManager _downloadManager = DownloadManager();
  Map<String, String> _assetToTaskMap = {};

  // IP位置服务
  final IPLocationService _ipLocationService = IPLocationService();

  // 用于跟踪widget是否被dispose
  bool _isDisposed = false;

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

  // 新增属性用于首页
  PlatformFile? get selectedFile =>
      _selectedFiles.isNotEmpty ? _selectedFiles.first : null;
  double _progress = 0.0;
  double get progress => _progress;

  void startTransfer() {
    _isTransferring = true;
    _progress = 0.0;
    notifyListeners();
  }

  void updateProgressValue(double value) {
    _progress = value;
    notifyListeners();
  }

  void completeTransfer() {
    _isTransferring = false;
    _progress = 0.0;
    _globalSentCount++;
    notifyListeners();
  }

  /// 设置全球发送启用状态
  void setGlobalSendEnabled(bool enabled) {
    _isGlobalSendEnabled = enabled;
    notifyListeners();
  }

  /// 设置循环发送状态
  void setLooping(bool looping) {
    _isLooping = looping;
    notifyListeners();
  }

  /// 设置发送速度
  void setSendRateMB(double rateMB) {
    _sendRateMB = rateMB.clamp(0.1, 5.0);
    notifyListeners();
  }

  /// 设置国家列表
  void setCountryList(List<String> countries) {
    _countryList = countries;
    notifyListeners();
  }

  /// 选择文件
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

  /// 选择内置素材
  Future<void> selectBuiltInAssets(BuildContext context) async {
    // 所有平台都导航到AssetScreen
    final selectedAssets = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AssetScreen()),
    );

    // 如果用户选择了素材，则从Cloudflare下载
    if (selectedAssets != null &&
        selectedAssets is List &&
        selectedAssets.isNotEmpty) {
      // 将List<dynamic>转换为List<String>
      final List<String> assetPaths = selectedAssets
          .map((asset) => asset.toString())
          .toList();
      _downloadSelectedAssets(context, assetPaths);
    }
  }

  /// 下载选中的素材
  Future<void> _downloadSelectedAssets(
    BuildContext context,
    List<String> assetPaths,
  ) async {
    try {
      // 初始化已下载素材服务
      await _downloadedAssetsService.initialize();

      // 分离已下载和未下载的素材
      final List<String> needDownloadAssets = [];
      final List<String> alreadyDownloadedAssets = [];

      for (String assetPath in assetPaths) {
        if (_downloadedAssetsService.isAssetDownloaded(assetPath)) {
          alreadyDownloadedAssets.add(assetPath);
        } else {
          needDownloadAssets.add(assetPath);
        }
      }

      // 显示智能提示
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

      // 处理已下载的素材（直接复用）
      if (alreadyDownloadedAssets.isNotEmpty) {
        await _reuseDownloadedAssets(context, alreadyDownloadedAssets);
      }

      // 下载未下载的素材
      if (needDownloadAssets.isNotEmpty) {
        for (String assetPath in needDownloadAssets) {
          await _downloadSingleAsset(context, assetPath);
        }
      }

      // 下载完成提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('所有素材处理完成')));
    } catch (e) {
      // 下载失败提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 复用已下载的素材
  Future<void> _reuseDownloadedAssets(
    BuildContext context,
    List<String> assetPaths,
  ) async {
    try {
      for (String assetPath in assetPaths) {
        final fileName = assetPath.split('/').last;

        if (kIsWeb) {
          // Web平台：从本地存储读取文件数据
          final fileData = await _getFileFromWebStorage(fileName);
          if (fileData != null) {
            final fileInfo = PlatformFile(
              name: fileName,
              size: fileData.length,
              path: null, // Web平台没有本地路径
              bytes: Uint8List.fromList(fileData),
            );
            addFiles([fileInfo]);
            debugPrint('Web平台复用已下载素材: $fileName');
          }
        } else {
          // 本地平台：从本地文件读取
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

  /// 从Web存储获取文件
  Future<List<int>?> _getFileFromWebStorage(String fileName) async {
    try {
      // 从Web平台的localStorage获取文件数据
      if (!kIsWeb) return null; // 非Web平台直接返回null

      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);

      // 查找文件信息
      final fileInfo = savedFiles.firstWhere(
        (f) => f['name'] == fileName,
        orElse: () => null,
      );

      if (fileInfo == null) return null;

      // 获取文件数据
      final fileDataStr = html.window.localStorage['file_$fileName'];
      if (fileDataStr == null) return null;

      // 解码base64数据
      return base64.decode(fileDataStr);
    } catch (e) {
      debugPrint('从Web存储获取文件失败: $e');
      return null;
    }
  }

  /// 下载单个素材（增强版，支持进度显示、暂停、断点续传）
  Future<void> _downloadSingleAsset(
    BuildContext context,
    String assetPath,
  ) async {
    try {
      // 构建下载URL - 根据素材路径判断是静态文件还是R2文件
      // 如果路径包含中文佛经或音频文件，说明是静态文件
      final bool isStaticFile =
          assetPath.contains('乾隆大藏经') ||
          assetPath.contains('房山石经陀罗尼') ||
          assetPath.contains('咒语') ||
          assetPath.contains('经文');

      final String url;
      if (isStaticFile) {
        // 静态文件下载策略
        // 修复：去掉assetPath中的web/前缀
        final cleanAssetPath = assetPath.startsWith('web/')
            ? assetPath.substring(4)
            : assetPath;

        if (kIsWeb) {
          // Web平台：使用相对路径，避免CORS问题
          url = '/$cleanAssetPath';
        } else {
          // 非Web平台：使用Cloudflare Worker的完整URL访问静态文件
          // 因为静态文件部署在Web平台上，需要通过Worker代理访问
          final String baseUrl = UnifiedConfig.isProduction
              ? UnifiedConfig.cloudflareWorkerProdUrl
              : UnifiedConfig.cloudflareWorkerDevUrl;
          url = '$baseUrl/$cleanAssetPath';
        }
      } else {
        // R2文件通过Cloudflare Worker下载
        url =
            '${UnifiedConfig.currentBackendUrl}/r2?file=${Uri.encodeComponent(assetPath)}';
      }

      debugPrint('下载素材URL: $url');
      debugPrint(
        '平台: ${kIsWeb ? "Web" : "Native"}, 静态文件: $isStaticFile, 环境: ${UnifiedConfig.isProduction ? "生产" : "开发"}',
      );

      // 获取文件名
      final fileName = assetPath.split('/').last;

      // 检查是否已有下载任务
      final existingTaskId = _assetToTaskMap[assetPath];
      if (existingTaskId != null) {
        final task = _downloadManager.tasks[existingTaskId];
        if (task != null && task.status == DownloadStatus.paused) {
          // 如果任务已暂停，恢复下载
          await _downloadManager.resumeDownload(existingTaskId);
          return;
        }
      }

      // 创建下载任务
      final taskId = await _downloadManager.createTask(
        url,
        fileName,
        assetPath,
      );
      _assetToTaskMap[assetPath] = taskId;

      // 显示下载进度对话框
      _showDownloadProgressDialog(context, taskId, fileName);

      // 开始下载
      await _downloadManager.startDownload(taskId);
    } catch (e) {
      debugPrint('下载素材失败: $e');
      rethrow;
    }
  }

  /// 显示下载进度对话框
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
            // 获取下载的文件
            final task = _downloadManager.tasks[taskId];
            if (task != null && task.status == DownloadStatus.completed) {
              final fileName = task.fileName;
              debugPrint('📁 处理下载完成的文件: $fileName');

              if (kIsWeb) {
                // Web平台：从localStorage获取文件
                debugPrint('🌐 Web平台：获取下载的文件数据');
                final fileData = await _downloadManager.getDownloadedFile(
                  fileName,
                );
                if (fileData != null) {
                  debugPrint('📊 文件数据获取成功，大小: ${fileData.length} bytes');
                  final fileInfo = PlatformFile(
                    name: fileName,
                    size: fileData.length,
                    path: null, // Web平台没有本地路径
                    bytes: fileData,
                  );

                  // 添加文件到选择列表
                  addFiles([fileInfo]);
                  debugPrint('✅ 文件已添加到选择列表');

                  // 标记素材为已下载
                  await _downloadedAssetsService.markAssetAsDownloaded(
                    task.assetPath,
                  );
                  debugPrint('🏷️ 素材已标记为已下载');

                  // 延迟确保UI更新
                  await Future.delayed(Duration(milliseconds: 200));
                  debugPrint('⏱️ UI更新延迟完成');
                } else {
                  debugPrint('❌ Web平台文件数据获取失败');
                }
              } else {
                // 本地平台：从文件系统获取文件
                debugPrint('📱 本地平台：获取下载的文件');
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
                    debugPrint('📂 文件存在，路径: $filePath');
                    final fileInfo = PlatformFile(
                      name: fileName,
                      size: await file.length(),
                      path: filePath,
                    );

                    // 添加文件到选择列表
                    addFiles([fileInfo]);
                    debugPrint('✅ 文件已添加到选择列表');

                    // 标记素材为已下载
                    await _downloadedAssetsService.markAssetAsDownloaded(
                      task.assetPath,
                    );
                    debugPrint('🏷️ 素材已标记为已下载');

                    // 延迟确保UI更新
                    await Future.delayed(Duration(milliseconds: 200));
                    debugPrint('⏱️ UI更新延迟完成');
                  } else {
                    debugPrint('❌ 本地文件不存在: $filePath');
                  }
                } else {
                  debugPrint('❌ 无法获取本地目录');
                }
              }
            } else {
              debugPrint('❌ 下载任务不存在或状态不正确');
            }
          } catch (e) {
            debugPrint('❌ 下载完成处理出错: $e');
          } finally {
            // 清理任务
            _assetToTaskMap.remove(taskId);
            debugPrint('🧹 任务清理完成');

            // 确保关闭对话框 - 检查widget是否还活跃
            if (!_isDisposed && context.mounted) {
              try {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                  debugPrint('🔒 对话框已关闭');
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

  /// 添加文件
  void addFiles(List<PlatformFile> files) {
    _selectedFiles.addAll(files);
    notifyListeners();
  }

  /// 移除文件
  void removeFile(PlatformFile file) {
    _selectedFiles.remove(file);
    notifyListeners();
  }

  /// 清空文件
  void clearFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }

  /// 获取文件类型
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

  /// 获取文件大小字符串
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

  // 地球轨迹回调（支持国家名称标签）
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

  /// 开始全球传输 - 使用真实的全球发送服务
  Future<void> startGlobalTransfer() async {
    if (_isTransferring || _selectedFiles.isEmpty) return;

    _isTransferring = true;
    _status = TransferStatus.transferring;
    await _persistTransferState();
    notifyListeners();

    try {
      debugPrint('🚀 开始真实全球传输 - 文件数量: ${_selectedFiles.length}');

      // 初始化真实的全球发送服务
      await _initializeRealGlobalSendService();

      // 开始真实的全球发送
      await _realGlobalSendService?.startSending(
        files: _selectedFiles,
        isLoop: _isLooping,
      );

      // 传输完成，尝试上传本地累积的数据
      await _uploadPendingData();
      debugPrint('✅ 传输完成，数据已上传');
    } catch (e) {
      debugPrint('❌ 传输失败: $e');
      _status = TransferStatus.error;
      _isTransferring = false;
      await _persistTransferState();
      notifyListeners();
    }
  }

  /// 简化的传输模拟（已废弃，使用真实全球发送服务）
  Future<void> _simulateSimpleTransfer() async {
    // 此方法已废弃，真实发送由 RealGlobalSendService 处理
  }

  /// 停止传输 - 停止真实的全球发送服务
  void stopTransfer() {
    if (!_isTransferring) return;

    _isTransferring = false;
    _status = TransferStatus.idle;

    // 停止真实的全球发送服务
    _realGlobalSendService?.stopSending();

    _persistTransferState();
    debugPrint('🛑 传输已停止');
    notifyListeners();
  }

  /// 内部方法：传输完成时调用（不是用户主动停止）
  void _onTransferCompleted() {
    _isTransferring = false;
    _status = TransferStatus.completed;
    _persistTransferState();
    notifyListeners();
  }

  /// 初始化真实的全球发送服务
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
        debugPrint('🌍 全球发送: $message');
        updateLog(message);
        _parseLogAndUpdateCountryStatus(message);
      },
      onTransferBeam: _onTransferBeam,
      onCountrySent: (bytes) async {
        // 每次成功发送到一个国家后，立即保存到本地
        await _saveToLocal(bytes);
      },
      userLatitude: userLat,
      userLongitude: userLng,
    );

    await _realGlobalSendService?.initialize();
    debugPrint('📋 真实全球发送服务初始化完成');
  }

  /// 解析日志并更新国家状态
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
    } else if (logMessage.contains('正在发送到')) {
      final regex = RegExp(r'正在发送到\s+([^()]+)\s+\([^()]+\)');
      final match = regex.firstMatch(logMessage);
      if (match != null) {
        final countryName = match.group(1)?.trim();
        updateCountryStatus(countryName, SendStatus.sending);
      }
    }
  }

  /// 更新传输进度
  void updateProgress(int count) {
    _globalSentCount = count;
    _persistTransferState();
    notifyListeners();
  }

  /// 更新已发送数据量
  void updateDataSent(double dataMB) {
    _globalDataSentMB = dataMB;
    _persistTransferState();
    notifyListeners();
  }

  /// 上传本地累积的数据
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

  /// 保存到本地
  Future<void> _saveToLocal(int bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getInt('pending_transfer_bytes') ?? 0;
    await prefs.setInt('pending_transfer_bytes', pending + bytes);
  }

  /// 清除本地缓存
  Future<void> _clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_transfer_bytes');
  }

  /// 重试上传本地缓存的数据
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

  /// 更新传输状态
  void updateStatus(TransferStatus status) {
    _status = status;
    notifyListeners();
  }

  /// 重置统计数据
  void _resetStats() {
    _globalSentCount = 0;
    _globalDataSentMB = 0.0;
    _currentLog = '';
  }

  /// 初始化国家状态
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
    notifyListeners();
  }

  /// 更新国家状态
  void updateCountryStatus(String? countryName, SendStatus status) {
    if (countryName == null) return;

    final index = _countryStatuses.indexWhere(
      (status) => status.countryName == countryName,
    );
    if (index != -1) {
      _countryStatuses[index] = _countryStatuses[index].copyWith(
        status: status,
      );
      _persistCountryStatuses();
      notifyListeners();
    }
  }

  /// 更新日志
  void updateLog(String log) {
    _currentLog = log;
    _persistTransferState();
    notifyListeners();
  }

  /// 获取成功发送的国家数量
  int getSuccessCount() {
    return _countryStatuses
        .where((status) => status.status == SendStatus.success)
        .length;
  }

  /// 加载持久化状态
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isTransferring = prefs.getBool('is_transferring') ?? false;
      _globalSentCount = prefs.getInt('global_sent_count') ?? 0;
      _globalDataSentMB = prefs.getDouble('global_data_sent_mb') ?? 0.0;
      _currentLog = prefs.getString('current_log') ?? '';

      // 加载国家状态
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

      notifyListeners();
    } catch (e) {
      debugPrint('加载持久化状态失败: $e');
    }
  }

  /// 持久化传输状态
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

  /// 持久化国家状态
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

  /// 清除持久化状态
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
    _realGlobalSendService?.stopSending();
    stopTransfer();
    super.dispose();
  }
}

/// 国家发送状态枚举
enum SendStatus {
  pending, // 等待中
  sending, // 发送中
  success, // 成功
  failed, // 失败
}

/// 国家发送状态数据类
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
