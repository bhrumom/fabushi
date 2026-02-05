import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Web平台特定的导入
import 'package:universal_html/html.dart' as html;

/// 已下载素材管理服务
///
/// 负责跟踪和管理已下载的素材，避免重复下载
class DownloadedAssetsService {
  static final DownloadedAssetsService _instance = DownloadedAssetsService._internal();
  factory DownloadedAssetsService() => _instance;
  DownloadedAssetsService._internal();

  // 已下载素材列表
  Set<String> _downloadedAssets = {};
  bool _isInitialized = false;

  /// 初始化服务，加载已下载素材列表
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        await _loadDownloadedAssetsFromWeb();
      } else {
        await _loadDownloadedAssetsFromLocal();
        // 缓存下载目录路径，用于同步检查文件是否存在
        await _cacheDownloadDirectory();
      }
      _isInitialized = true;
      debugPrint('已加载 ${_downloadedAssets.length} 个已下载素材');
    } catch (e) {
      debugPrint('加载已下载素材失败: $e');
      _downloadedAssets = {};
    }
  }

  /// 缓存下载目录路径
  Future<void> _cacheDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        _cachedDownloadDir = await getExternalStorageDirectory();
      } else {
        _cachedDownloadDir = await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint('缓存下载目录失败: $e');
    }
  }

  /// Web平台：从localStorage加载已下载素材
  Future<void> _loadDownloadedAssetsFromWeb() async {
    try {
      final savedFilesStr = html.window.localStorage['downloaded_assets'] ?? '[]';
      final List<dynamic> savedAssets = json.decode(savedFilesStr);
      _downloadedAssets = savedAssets.map((asset) => asset.toString()).toSet();
    } catch (e) {
      debugPrint('Web平台加载已下载素材失败: $e');
      _downloadedAssets = {};
    }
  }

  /// 本地平台：从本地文件加载已下载素材
  Future<void> _loadDownloadedAssetsFromLocal() async {
    try {
      final Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) return;

      final assetsFile = File('${dir.path}/downloaded_assets.json');
      if (await assetsFile.exists()) {
        final content = await assetsFile.readAsString();
        final List<dynamic> savedAssets = json.decode(content);
        _downloadedAssets = savedAssets.map((asset) => asset.toString()).toSet();
      }
    } catch (e) {
      debugPrint('本地平台加载已下载素材失败: $e');
      _downloadedAssets = {};
    }
  }

  /// 检查素材是否已下载（同时验证文件确实存在）
  bool isAssetDownloaded(String assetPath) {
    // 首先检查记录
    if (!_downloadedAssets.contains(assetPath)) {
      return false;
    }
    // 从根源解决：同步检查文件是否存在
    // 注意：这里使用同步检查，对于本地平台使用缓存
    final fileName = assetPath.split('/').last;
    return _verifyFileExistsSync(fileName);
  }

  /// 同步验证文件是否存在（用于UI显示）
  bool _verifyFileExistsSync(String fileName) {
    if (kIsWeb) {
      return _isFileExistsOnWeb(fileName);
    }
    // 本地平台：使用同步检查
    return _isFileExistsOnLocalSync(fileName);
  }

  /// 本地平台：同步检查文件是否存在
  bool _isFileExistsOnLocalSync(String fileName) {
    try {
      // 使用缓存的目录路径（在初始化时获取）
      if (_cachedDownloadDir == null) return false;
      final file = File('${_cachedDownloadDir!.path}/$fileName');
      return file.existsSync();
    } catch (e) {
      return false;
    }
  }

  // 缓存的下载目录路径
  Directory? _cachedDownloadDir;

  /// 标记素材为已下载
  Future<void> markAssetAsDownloaded(String assetPath) async {
    _downloadedAssets.add(assetPath);
    await _saveDownloadedAssets();
  }

  /// 获取所有已下载素材
  Set<String> getDownloadedAssets() {
    return Set.from(_downloadedAssets);
  }

  /// 移除单个素材的下载记录（当文件实际不存在时使用）
  Future<void> removeAsset(String assetPath) async {
    _downloadedAssets.remove(assetPath);
    await _saveDownloadedAssets();
    debugPrint('🗑️ 已移除无效下载记录: $assetPath');
  }

  /// 清除所有已下载素材记录
  Future<void> clearDownloadedAssets() async {
    _downloadedAssets.clear();
    await _saveDownloadedAssets();
  }

  /// 保存已下载素材列表
  Future<void> _saveDownloadedAssets() async {
    try {
      if (kIsWeb) {
        await _saveToWeb();
      } else {
        await _saveToLocal();
      }
    } catch (e) {
      debugPrint('保存已下载素材失败: $e');
    }
  }

  /// Web平台：保存到localStorage
  Future<void> _saveToWeb() async {
    final assetsList = _downloadedAssets.toList();
    html.window.localStorage['downloaded_assets'] = json.encode(assetsList);
  }

  /// 本地平台：保存到本地文件
  Future<void> _saveToLocal() async {
    final Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (dir == null) return;

    final assetsFile = File('${dir.path}/downloaded_assets.json');
    final assetsList = _downloadedAssets.toList();
    await assetsFile.writeAsString(json.encode(assetsList));
  }

  /// 检查文件是否存在（用于验证已下载的文件是否还存在）
  Future<bool> isFileExists(String fileName) async {
    if (kIsWeb) {
      return _isFileExistsOnWeb(fileName);
    } else {
      return _isFileExistsOnLocal(fileName);
    }
  }

  /// Web平台：检查文件是否存在
  bool _isFileExistsOnWeb(String fileName) {
    try {
      return html.window.localStorage['file_$fileName'] != null;
    } catch (e) {
      return false;
    }
  }

  /// 本地平台：检查文件是否存在
  Future<bool> _isFileExistsOnLocal(String fileName) async {
    try {
      final Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) return false;

      final file = File('${dir.path}/$fileName');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
