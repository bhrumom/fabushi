import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'downloaded_assets_service.dart';
import 'download_manager.dart';
import '../core/config/app_config.dart';

/// 共享素材管理器 - 首页和法流页面共用
class SharedAssetManager {
  static final SharedAssetManager _instance = SharedAssetManager._internal();
  factory SharedAssetManager() => _instance;
  SharedAssetManager._internal();

  final DownloadedAssetsService _downloadedAssetsService = DownloadedAssetsService();
  final DownloadManager _downloadManager = DownloadManager();
  final Map<String, String> _assetToTaskMap = {};

  bool _initialized = false;

  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;
    await _downloadedAssetsService.initialize();
    _initialized = true;
  }

  /// 检查素材是否已下载
  bool isAssetDownloaded(String assetPath) {
    return _downloadedAssetsService.isAssetDownloaded(assetPath);
  }

  /// 获取已下载的素材文件
  Future<PlatformFile?> getDownloadedAsset(String assetPath) async {
    if (!isAssetDownloaded(assetPath)) return null;

    final fileName = assetPath.split('/').last;

    if (kIsWeb) {
      final fileData = await _getFileFromWebStorage(fileName);
      if (fileData != null) {
        return PlatformFile(
          name: fileName,
          size: fileData.length,
          path: null,
          bytes: Uint8List.fromList(fileData),
        );
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
          return PlatformFile(
            name: fileName,
            size: await file.length(),
            path: filePath,
          );
        }
      }
    }

    return null;
  }

  /// 批量获取素材（已下载的直接返回，未下载的返回null）
  Future<Map<String, PlatformFile?>> getAssets(List<String> assetPaths) async {
    final Map<String, PlatformFile?> result = {};
    
    for (String assetPath in assetPaths) {
      result[assetPath] = await getDownloadedAsset(assetPath);
    }
    
    return result;
  }

  /// 下载单个素材
  Future<String> downloadAsset(String assetPath) async {
    final bool isStaticFile = assetPath.contains('乾隆大藏经') ||
        assetPath.contains('房山石经陀罗尼') ||
        assetPath.contains('咒语') ||
        assetPath.contains('经文');

    final String url;
    if (isStaticFile) {
      final cleanAssetPath = assetPath.startsWith('web/') ? assetPath.substring(4) : assetPath;

      if (kIsWeb) {
        url = '/$cleanAssetPath';
      } else {
        final String baseUrl = AppConfig.isProduction
            ? AppConfig.cloudflareWorkerProdUrl
            : AppConfig.cloudflareWorkerDevUrl;
        url = '$baseUrl/$cleanAssetPath';
      }
    } else {
      url = '${AppConfig.currentBackendUrl}/r2?file=${Uri.encodeComponent(assetPath)}';
    }

    final fileName = assetPath.split('/').last;

    // 检查是否已有下载任务
    final existingTaskId = _assetToTaskMap[assetPath];
    if (existingTaskId != null) {
      final task = _downloadManager.tasks[existingTaskId];
      if (task != null && task.status == DownloadStatus.paused) {
        await _downloadManager.resumeDownload(existingTaskId);
        return existingTaskId;
      }
      if (task != null && task.status == DownloadStatus.downloading) {
        return existingTaskId;
      }
    }

    // 创建新任务
    final taskId = await _downloadManager.createTask(url, fileName, assetPath);
    _assetToTaskMap[assetPath] = taskId;

    return taskId;
  }

  /// 开始下载任务
  Future<void> startDownload(String taskId) async {
    await _downloadManager.startDownload(taskId);
  }

  /// 标记素材为已下载
  Future<void> markAssetDownloaded(String assetPath) async {
    await _downloadedAssetsService.markAssetAsDownloaded(assetPath);
  }

  /// 获取下载管理器（用于UI显示进度）
  DownloadManager get downloadManager => _downloadManager;

  /// 获取任务ID
  String? getTaskId(String assetPath) => _assetToTaskMap[assetPath];

  /// 清理任务映射
  void clearTaskMapping(String assetPath) {
    _assetToTaskMap.remove(assetPath);
  }

  Future<List<int>?> _getFileFromWebStorage(String fileName) async {
    try {
      if (!kIsWeb) return null;

      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);

      final fileInfo = savedFiles.firstWhere((f) => f['name'] == fileName, orElse: () => null);

      if (fileInfo == null) return null;

      final fileDataStr = html.window.localStorage['file_$fileName'];
      if (fileDataStr == null) return null;

      return base64.decode(fileDataStr);
    } catch (e) {
      debugPrint('从Web存储获取文件失败: $e');
      return null;
    }
  }
}
