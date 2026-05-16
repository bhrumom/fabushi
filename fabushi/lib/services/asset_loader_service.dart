import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'memory_manager.dart';
import '../core/config/app_config.dart';

/// 3D 模型资源缓存包装器
/// 实现 ClearableCache 接口以便 MemoryManager 在内存警告时清理
class _AssetCacheWrapper implements ClearableCache {
  final Map<String, Uint8List> _cache;

  _AssetCacheWrapper(this._cache);

  @override
  String get cacheName => 'AssetLoaderService';

  @override
  int get priority => 3; // 较低优先级，容易被清理

  @override
  int get currentSizeBytes {
    int total = 0;
    for (final data in _cache.values) {
      total += data.length;
    }
    return total;
  }

  @override
  Future<void> trimToSize(int targetBytes) async {
    while (currentSizeBytes > targetBytes && _cache.isNotEmpty) {
      final key = _cache.keys.first;
      _cache.remove(key);
    }
  }

  @override
  Future<void> clearAll() async {
    _cache.clear();
    debugPrint('🗑️ [AssetLoader] 已清空内存缓存');
  }
}

/// 大型资源动态加载服务
///
/// 用于从 CDN 加载大型 3D 模型等资源,避免打包到应用中
/// 实现断点续传和持久化缓存机制
class AssetLoaderService {
  static String get defaultCdnBaseUrl =>
      '${AppConfig.currentBackendUrl}/r2?file=';

  static String get cdnBaseUrl => defaultCdnBaseUrl;

  static const List<int> _flutterSceneModelFileIdentifier = [
    0x49,
    0x50,
    0x53,
    0x43,
  ]; // IPSC

  static bool get _canPrewarmLargeBuddhaModelBytes =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.android;

  // 内存缓存 (仅用于当前会话)
  static final Map<String, Uint8List> _memoryCache = {};

  // 缓存包装器（用于 MemoryManager）
  static _AssetCacheWrapper? _cacheWrapper;

  /// 初始化并注册到 MemoryManager
  static void initialize() {
    if (_cacheWrapper == null) {
      _cacheWrapper = _AssetCacheWrapper(_memoryCache);
      MemoryManager.instance.registerCache(_cacheWrapper!);
      debugPrint('✅ [AssetLoader] 已注册到 MemoryManager');
    }
  }

  /// 如果本机已经存在佛像模型，就提前把它放进内存缓存，避免首次进入禅室再阻塞等待。
  ///
  /// Android 上该模型太大，启动预热会显著抬高内存峰值，因此只在进入禅室时按需读取。
  /// 这里不会触发网络请求，也不会在本地不存在时主动下载大文件。
  static Future<void> prewarmBuddhaModelFromPersistentCache() async {
    initialize();
    const fileName = AppConfig.buddhaModelAssetPath;

    if (_memoryCache.containsKey(fileName)) {
      return;
    }

    if (!_canPrewarmLargeBuddhaModelBytes) {
      debugPrint('ℹ️ [AssetLoader] Android 跳过启动预热佛像大模型字节');
      return;
    }

    try {
      final cached = await _loadFromPersistentStorage(fileName);
      if (cached == null || cached.isEmpty) {
        return;
      }

      _assertAssetSizeIsValid(
        fileName,
        cached.lengthInBytes,
        minExpectedBytes: AppConfig.minBuddhaModelSizeBytes,
        source: 'persistent-prewarm',
      );
      _assertAssetSignatureIsValid(
        fileName,
        cached,
        source: 'persistent-prewarm',
      );

      _memoryCache[fileName] = cached;
      debugPrint(
        '⚡ [AssetLoader] 已预热本地佛像模型缓存: '
        '$fileName (${cached.lengthInBytes} bytes)',
      );
    } catch (e) {
      debugPrint('⚠️ [AssetLoader] 预热本地佛像模型失败: $e');
    }
  }

  /// 加载佛像模型
  ///
  /// 返回模型数据的 Uint8List,可以传递给 flutter_scene 解析
  static Future<Uint8List> loadBuddhaModel({
    void Function(double progress)? onProgress,
  }) async {
    // 确保已注册到 MemoryManager
    initialize();

    try {
      return await _loadAsset(
        AppConfig.buddhaModelAssetPath,
        onProgress: onProgress,
        minExpectedBytes: AppConfig.minBuddhaModelSizeBytes,
      );
    } catch (e) {
      debugPrint('⚠️ [AssetLoader] 佛像模型首次加载失败，清理旧缓存后重试 R2: $e');
      await evictBuddhaModelCache();
      return _loadAsset(
        AppConfig.buddhaModelAssetPath,
        onProgress: onProgress,
        forceRefresh: true,
        minExpectedBytes: AppConfig.minBuddhaModelSizeBytes,
      );
    }
  }

  static Future<void> evictBuddhaModelCache() async {
    _memoryCache.remove(AppConfig.buddhaModelAssetPath);
    await _deletePersistentAsset(
      AppConfig.buddhaModelAssetPath,
      includePartial: true,
    );
  }

  static void releaseBuddhaModelMemoryCache() {
    _memoryCache.remove(AppConfig.buddhaModelAssetPath);
  }

  // 正在进行的加载任务，防止并发下载同一资源
  static final Map<String, Future<Uint8List>> _loadingFutures = {};

  /// 通用资源加载方法
  ///
  /// [fileName] 文件名 (相对路径)
  /// [onProgress] 下载进度回调 (0.0 - 1.0)
  /// [forceRefresh] 强制重新下载,忽略缓存
  static Future<Uint8List> _loadAsset(
    String fileName, {
    void Function(double progress)? onProgress,
    bool forceRefresh = false,
    int? minExpectedBytes,
  }) async {
    // 1. 检查内存缓存
    if (!forceRefresh && _memoryCache.containsKey(fileName)) {
      debugPrint('✅ [AssetLoader] 从内存缓存加载: $fileName');
      onProgress?.call(1.0);
      return _memoryCache[fileName]!;
    }

    // 2. 检查是否有正在进行的加载任务
    if (_loadingFutures.containsKey(fileName)) {
      debugPrint('⏳ [AssetLoader] 发现正在进行的加载任务，合并请求: $fileName');
      return _loadingFutures[fileName]!;
    }

    // 3. 创建新的加载任务
    final loadFuture = _performLoad(
      fileName,
      onProgress: onProgress,
      forceRefresh: forceRefresh,
      minExpectedBytes: minExpectedBytes,
    );
    _loadingFutures[fileName] = loadFuture;

    try {
      final result = await loadFuture;
      return result;
    } finally {
      _loadingFutures.remove(fileName);
    }
  }

  /// 实际执行加载逻辑
  static Future<Uint8List> _performLoad(
    String fileName, {
    void Function(double progress)? onProgress,
    bool forceRefresh = false,
    int? minExpectedBytes,
  }) async {
    if (forceRefresh && !kIsWeb) {
      await _deletePersistentAsset(fileName, includePartial: true);
    }

    // 先读本地正式缓存。
    // 这些文件在下载完成时已经做过完整性校验，这里不再为了“再确认一次”去发 HEAD 请求，
    // 否则本机已有佛像时首次进入禅室仍会被网络校验卡住。
    if (!forceRefresh) {
      final cached = await _loadFromPersistentStorage(fileName);
      if (cached != null && cached.isNotEmpty) {
        try {
          _assertAssetSizeIsValid(
            fileName,
            cached.lengthInBytes,
            minExpectedBytes: minExpectedBytes,
            source: 'persistent-cache',
          );
          _assertAssetSignatureIsValid(
            fileName,
            cached,
            source: 'persistent-cache',
          );
          debugPrint(
            '✅ [AssetLoader] 从本地存储加载: $fileName (${cached.lengthInBytes} bytes)',
          );
          _memoryCache[fileName] = cached;
          onProgress?.call(1.0);
          return cached;
        } catch (e) {
          debugPrint(
            '⚠️ [AssetLoader] 本地佛像缓存无效，删除后回退到 R2 重新下载: '
            '$fileName - $e',
          );
          _memoryCache.remove(fileName);
          await _deletePersistentAsset(fileName, includePartial: true);
        }
      }
    }

    // 检查是否有未完成的下载（.downloading 文件）
    if (!kIsWeb) {
      final hasPartial = await _hasPartialDownload(fileName);
      if (hasPartial) {
        debugPrint('🔄 [AssetLoader] 检测到未完成下载，将执行断点续传: $fileName');
      }
    }

    debugPrint('📥 [AssetLoader] 开始下载: $fileName');
    final data = await _downloadResumable(
      fileName,
      onProgress: onProgress,
      minExpectedBytes: minExpectedBytes,
    );

    _assertAssetSizeIsValid(
      fileName,
      data.lengthInBytes,
      minExpectedBytes: minExpectedBytes,
      source: 'download',
    );
    _assertAssetSignatureIsValid(fileName, data, source: 'download');

    _memoryCache[fileName] = data;
    return data;
  }

  /// 获取本地存储目录
  static Future<Directory> _getStorageDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web platform does not support local storage directory',
      );
    }
    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${appDir.path}/assets_cache/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// 检查是否存在未完成的下载
  static Future<bool> _hasPartialDownload(String fileName) async {
    if (kIsWeb) return false;
    try {
      final dir = await _getStorageDirectory();
      final safeFileName = fileName.replaceAll('/', '_');
      final tempFile = File('${dir.path}/$safeFileName.downloading');
      return await tempFile.exists() && await tempFile.length() > 0;
    } catch (e) {
      return false;
    }
  }

  /// 从本地持久化存储加载
  static Future<Uint8List?> _loadFromPersistentStorage(String fileName) async {
    if (kIsWeb) return null;

    try {
      final dir = await _getStorageDirectory();
      final safeFileName = fileName.replaceAll('/', '_');
      final file = File('${dir.path}/$safeFileName');

      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          return await file.readAsBytes();
        } else {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AssetLoader] 读取本地存储失败: $e');
    }

    return null;
  }

  /// 断点续传下载
  static Future<Uint8List> _downloadResumable(
    String fileName, {
    void Function(double progress)? onProgress,
    int? minExpectedBytes,
  }) async {
    if (kIsWeb) {
      return _downloadSimple(
        fileName,
        onProgress: onProgress,
        minExpectedBytes: minExpectedBytes,
      );
    }

    final url = '$cdnBaseUrl${Uri.encodeComponent(fileName)}';
    final dir = await _getStorageDirectory();
    final safeFileName = fileName.replaceAll('/', '_');
    final finalFile = File('${dir.path}/$safeFileName');
    final tempFile = File('${dir.path}/$safeFileName.downloading');

    int downloadedBytes = 0;
    if (await tempFile.exists()) {
      downloadedBytes = await tempFile.length();
      debugPrint('🔄 [AssetLoader] 发现未完成下载，已下载: $downloadedBytes bytes，尝试断点续传');
    }

    final client = http.Client();
    try {
      int? expectedContentLength;
      try {
        final headRes = await client
            .head(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        if (headRes.statusCode == 200) {
          if (headRes.headers['content-length'] != null) {
            expectedContentLength = int.tryParse(
              headRes.headers['content-length']!,
            );
          }
        }
      } catch (_) {}

      if (expectedContentLength != null && downloadedBytes > 0) {
        if (downloadedBytes == expectedContentLength) {
          _assertAssetSizeIsValid(
            fileName,
            downloadedBytes,
            minExpectedBytes: minExpectedBytes,
            source: 'complete-partial-file',
          );
          if (await finalFile.exists()) {
            await finalFile.delete();
          }
          await tempFile.rename(finalFile.path);
          debugPrint(
            '✅ [AssetLoader] 未完成文件已完整，直接转为正式缓存: '
            '${finalFile.path} ($downloadedBytes bytes)',
          );
          onProgress?.call(1.0);
          return await finalFile.readAsBytes();
        }

        if (downloadedBytes > expectedContentLength) {
          debugPrint(
            '⚠️ [AssetLoader] 未完成文件大于远端对象，删除后重新下载: '
            '$downloadedBytes > $expectedContentLength',
          );
          await tempFile.delete();
          downloadedBytes = 0;
        }
      }

      final request = http.Request('GET', Uri.parse(url));
      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await client.send(request);

      if (response.statusCode == 200 || response.statusCode == 206) {
        final isResuming = response.statusCode == 206;
        if (!isResuming && downloadedBytes > 0) {
          debugPrint('⚠️ [AssetLoader] 服务器未续传 (返回 200)，重新开始下载');
          downloadedBytes = 0;
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }

        final totalLength = isResuming
            ? _parseTotalLengthFromContentRange(
                    response.headers['content-range'],
                  ) ??
                  ((response.contentLength ?? 0) + downloadedBytes)
            : response.contentLength ?? expectedContentLength ?? 0;
        _assertAssetSizeIsValid(
          fileName,
          totalLength,
          minExpectedBytes: minExpectedBytes,
          source: 'response-length',
        );
        debugPrint(
          '📥 [AssetLoader] 总大小: $totalLength bytes (Stream: ${response.contentLength}, HEAD: $expectedContentLength)',
        );

        final fileMode = isResuming ? FileMode.append : FileMode.write;
        final sink = tempFile.openWrite(mode: fileMode);
        int received = downloadedBytes;

        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (totalLength > 0) {
            onProgress?.call((received / totalLength).clamp(0.0, 1.0));
          } else {
            onProgress?.call((received % 10000000) / 10000000.0 * 0.99);
          }
        }

        await sink.flush();
        await sink.close();

        final downloadedSize = await tempFile.length();
        if (totalLength > 0 && downloadedSize != totalLength) {
          debugPrint(
            '⚠️ [AssetLoader] 下载文件大小不匹配 (实际: $downloadedSize, 预期: $totalLength)，保留 .downloading 文件以便续传',
          );
          throw Exception('下载不完整: 已下载 $downloadedSize / $totalLength bytes');
        }

        _assertAssetSizeIsValid(
          fileName,
          downloadedSize,
          minExpectedBytes: minExpectedBytes,
          source: 'downloaded-file',
        );

        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(finalFile.path);
        debugPrint(
          '✅ [AssetLoader] 下载完成并保存: ${finalFile.path} ($downloadedSize bytes)',
        );

        return await finalFile.readAsBytes();
      } else if (response.statusCode == 416) {
        debugPrint('⚠️ [AssetLoader] Range 不满足 (416)，验证未完成文件');
        final downloadedSize = await tempFile.exists()
            ? await tempFile.length()
            : 0;
        if (expectedContentLength != null &&
            downloadedSize == expectedContentLength) {
          _assertAssetSizeIsValid(
            fileName,
            downloadedSize,
            minExpectedBytes: minExpectedBytes,
            source: 'range-416-complete-file',
          );
          if (await finalFile.exists()) {
            await finalFile.delete();
          }
          await tempFile.rename(finalFile.path);
          onProgress?.call(1.0);
          return await finalFile.readAsBytes();
        }
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        throw Exception('下载失败: HTTP 416');
      } else {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [AssetLoader] 下载出错: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// 简单的非断点续传下载 (用于 Web 或作为降级方案)
  static Future<Uint8List> _downloadSimple(
    String fileName, {
    void Function(double progress)? onProgress,
    int? minExpectedBytes,
  }) async {
    final url = '$cdnBaseUrl${Uri.encodeComponent(fileName)}';
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final total = response.contentLength ?? 0;
        _assertAssetSizeIsValid(
          fileName,
          total,
          minExpectedBytes: minExpectedBytes,
          source: 'response-length',
        );
        int received = 0;
        final bytes = <int>[];

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress?.call(received / total);
          }
        }

        client.close();
        final data = Uint8List.fromList(bytes);
        _assertAssetSizeIsValid(
          fileName,
          data.lengthInBytes,
          minExpectedBytes: minExpectedBytes,
          source: 'download',
        );
        return data;
      } else {
        client.close();
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [AssetLoader] 简单下载失败: $e');
      if (cdnBaseUrl != defaultCdnBaseUrl) {
        final fallbackUrl =
            '$defaultCdnBaseUrl${Uri.encodeComponent(fileName)}';
        debugPrint('🔄 [AssetLoader] 尝试从默认 CDN 下载: $fallbackUrl');
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          onProgress?.call(1.0);
          _assertAssetSizeIsValid(
            fileName,
            response.bodyBytes.length,
            minExpectedBytes: minExpectedBytes,
            source: 'fallback-download',
          );
          return response.bodyBytes;
        }
      }
      rethrow;
    }
  }

  static int? _parseTotalLengthFromContentRange(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static Future<void> _deletePersistentAsset(
    String fileName, {
    required bool includePartial,
  }) async {
    if (kIsWeb) return;

    try {
      final dir = await _getStorageDirectory();
      final safeFileName = fileName.replaceAll('/', '_');
      final files = [
        File('${dir.path}/$safeFileName'),
        if (includePartial) File('${dir.path}/$safeFileName.downloading'),
      ];

      for (final file in files) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AssetLoader] 删除本地资源缓存失败: $e');
    }
  }

  static void _assertAssetSizeIsValid(
    String fileName,
    int sizeBytes, {
    int? minExpectedBytes,
    required String source,
  }) {
    if (minExpectedBytes == null || sizeBytes <= 0) return;
    if (sizeBytes < minExpectedBytes) {
      throw Exception(
        '资源大小异常($source): $fileName '
        '当前 ${_formatBytes(sizeBytes)}，'
        '小于预期最小值 ${_formatBytes(minExpectedBytes)}。'
        'R2 可能上传了错误文件。',
      );
    }
  }

  static void _assertAssetSignatureIsValid(
    String fileName,
    Uint8List data, {
    required String source,
  }) {
    if (fileName != AppConfig.buddhaModelAssetPath) return;
    if (isFlutterSceneModelData(data)) return;

    throw Exception(
      '资源格式异常($source): $fileName 不是有效的 flutter_scene .model 文件。',
    );
  }

  @visibleForTesting
  static bool isFlutterSceneModelData(Uint8List data) {
    if (data.lengthInBytes < 8) return false;
    for (var i = 0; i < _flutterSceneModelFileIdentifier.length; i++) {
      if (data[4 + i] != _flutterSceneModelFileIdentifier[i]) {
        return false;
      }
    }
    return true;
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  /// 强制重新下载并清除旧缓存
  static Future<void> forceRedownload() async {
    debugPrint('↻ [AssetLoader] 强制清除缓存并重新下载');
    await clearCache();
  }

  /// 清除所有缓存
  static Future<void> clearCache() async {
    _memoryCache.clear();

    if (!kIsWeb) {
      try {
        final dir = await _getStorageDirectory();
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        debugPrint('🗑️ [AssetLoader] 已清除本地资源缓存');
      } catch (e) {
        debugPrint('⚠️ [AssetLoader] 清除缓存失败: $e');
      }
    }
  }

  /// 获取缓存大小 (字节)
  static Future<int> getCacheSize() async {
    int size = 0;

    for (final data in _memoryCache.values) {
      size += data.length;
    }

    if (!kIsWeb) {
      try {
        final dir = await _getStorageDirectory();
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              size += await entity.length();
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [AssetLoader] 获取缓存大小失败: $e');
      }
    }

    return size;
  }

  /// 预加载资源 (兼容旧接口)
  static Future<void> preloadAssets(List<String> fileNames) async {
    for (final fileName in fileNames) {
      try {
        await _loadAsset(fileName);
        debugPrint('✅ [AssetLoader] 预加载完成: $fileName');
      } catch (e) {
        debugPrint('⚠️ [AssetLoader] 预加载失败: $fileName - $e');
      }
    }
  }
}
