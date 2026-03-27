import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'memory_manager.dart';

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
  static const String defaultCdnBaseUrl = 'https://flutter.ombhrum.com/r2?file=';
  
  static String cdnBaseUrl = defaultCdnBaseUrl;
  
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

  /// 加载佛像模型
  /// 
  /// 返回模型数据的 Uint8List,可以传递给 flutter_scene 解析
  static Future<Uint8List> loadBuddhaModel({
    void Function(double progress)? onProgress
  }) async {
    // 确保已注册到 MemoryManager
    initialize();
    
    return await _loadAsset(
      'models/buddha_model.model',
      onProgress: onProgress,
    );
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
      // 注意：这里无法直接合并 onProgress，但后续请求会共享最终结果
      return _loadingFutures[fileName]!;
    }

    // 3. 创建新的加载任务
    final loadFuture = _performLoad(fileName, onProgress: onProgress, forceRefresh: forceRefresh);
    _loadingFutures[fileName] = loadFuture;

    try {
      final result = await loadFuture;
      return result;
    } finally {
      // 任务完成后移除 Future 缓存
      _loadingFutures.remove(fileName);
    }
  }

  /// 实际执行加载逻辑
  static Future<Uint8List> _performLoad(
    String fileName, {
    void Function(double progress)? onProgress,
    bool forceRefresh = false,
  }) async {
    // 2.1 检查本地持久化文件（含完整性校验）
    if (!forceRefresh) {
      final cached = await _loadFromPersistentStorage(fileName);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('✅ [AssetLoader] 从本地存储加载: $fileName (${cached.lengthInBytes} bytes)');
        _memoryCache[fileName] = cached;
        onProgress?.call(1.0);
        return cached;
      }
    }
    
    // 3. 检查是否有未完成的下载（.downloading 文件）
    if (!kIsWeb) {
      final hasPartial = await _hasPartialDownload(fileName);
      if (hasPartial) {
        debugPrint('🔄 [AssetLoader] 检测到未完成下载，将执行断点续传: $fileName');
      }
    }
    
    // 4. 执行断点续传下载
    debugPrint('📥 [AssetLoader] 开始下载: $fileName');
    final data = await _downloadResumable(fileName, onProgress: onProgress);
    
    // 5. 更新内存缓存
    _memoryCache[fileName] = data;
    
    return data;
  }
  
  /// 获取本地存储目录
  static Future<Directory> _getStorageDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform does not support local storage directory');
    }
    // 使用 ApplicationSupportDirectory 而不是 CacheDirectory
    // 这样系统清理或应用更新时不会删除模型文件
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

  /// 通过 HEAD 请求获取服务端文件大小
  static Future<int?> _getRemoteFileSize(String fileName) async {
    try {
      final url = '$cdnBaseUrl$fileName';
      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          return int.tryParse(contentLength);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AssetLoader] HEAD 请求失败: $e');
    }
    return null;
  }

  /// 从本地持久化存储加载
  /// 
  /// 注意：已保存到正式文件路径的资源在下载完成时已通过完整性校验，
  /// 这里不再发 HEAD 请求重复校验，避免不必要的网络延迟。
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
          // 0字节文件，视为无效，删除
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
  }) async {
    // Web 平台不支持文件操作，直接普通下载
    if (kIsWeb) {
      return _downloadSimple(fileName, onProgress: onProgress);
    }

    final url = '$cdnBaseUrl$fileName';
    final dir = await _getStorageDirectory();
    final safeFileName = fileName.replaceAll('/', '_');
    final finalFile = File('${dir.path}/$safeFileName');
    final tempFile = File('${dir.path}/$safeFileName.downloading');

    int downloadedBytes = 0;
    if (await tempFile.exists()) {
      downloadedBytes = await tempFile.length();
      debugPrint('🔄 [AssetLoader] 发现未完成下载，已下载: $downloadedBytes bytes，尝试断点续传');
    }

    try {
      final client = http.Client();
      
      // 先进行 HEAD 请求获取确切的总大小以防 client.send 剥离 Content-Length
      int? expectedContentLength;
      try {
        final headRes = await client.head(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (headRes.statusCode == 200) {
           if (headRes.headers['content-length'] != null) {
              expectedContentLength = int.tryParse(headRes.headers['content-length']!);
           }
        }
      } catch (_) {}

      final request = http.Request('GET', Uri.parse(url));
      
      // 添加 Range 头
      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await client.send(request);
      
      if (response.statusCode == 200 || response.statusCode == 206) {
        final streamContentLength = response.contentLength ?? expectedContentLength ?? 0;
        final totalLength = streamContentLength + downloadedBytes;
        debugPrint('📥 [AssetLoader] 总大小: $totalLength bytes (Stream: ${response.contentLength}, HEAD: $expectedContentLength)');

        // 如果是 200 OK，说明服务器不支持 Range 或返回了全部内容，需要重置
        final isResuming = response.statusCode == 206;
        final fileMode = isResuming ? FileMode.append : FileMode.write;
        
        if (!isResuming && downloadedBytes > 0) {
           debugPrint('⚠️ [AssetLoader] 服务器不支持断点续传 (返回 200)，重新开始下载');
           downloadedBytes = 0;
        }

        final sink = tempFile.openWrite(mode: fileMode);
        
        int received = downloadedBytes;
        
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (totalLength > 0) {
            onProgress?.call(received / totalLength);
          } else {
             // 如果真获取不到总大小，也提供一个伪装的变动进度以表明没有卡死
            onProgress?.call((received % 10000000) / 10000000.0 * 0.99);
          }
        }
        
        await sink.flush();
        await sink.close();
        client.close();

        // 验证下载完整性
        final downloadedSize = await tempFile.length();
        if (totalLength > 0 && downloadedSize != totalLength) {
          debugPrint('⚠️ [AssetLoader] 下载文件大小不匹配 (实际: $downloadedSize, 预期: $totalLength)，保留 .downloading 文件以便续传');
          throw Exception('下载不完整: 已下载 $downloadedSize / $totalLength bytes');
        }

        // 下载完成，重命名为正式文件
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(finalFile.path);
        debugPrint('✅ [AssetLoader] 下载完成并保存: ${finalFile.path} ($downloadedSize bytes)');
        
        return await finalFile.readAsBytes();
      } else if (response.statusCode == 416) {
          // Range Not Satisfiable - 可能已经下载完成了
          debugPrint('⚠️ [AssetLoader] Range 不满足 (416)，可能已下载完成，尝试验证');
          client.close();
          if (await tempFile.exists()) {
             // 尝试直接使用现有临时文件
             await tempFile.rename(finalFile.path);
             return await finalFile.readAsBytes();
          }
          throw Exception('下载失败: HTTP 416');
      } else {
        client.close();
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [AssetLoader] 下载出错: $e');
      // 如果出错，保留 .downloading 文件以便下次续传
      rethrow;
    }
  }

  /// 简单的非断点续传下载 (用于 Web 或作为降级方案)
  static Future<Uint8List> _downloadSimple(
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    final url = '$cdnBaseUrl$fileName';
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      
      if (response.statusCode == 200) {
        final total = response.contentLength ?? 0;
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
        return Uint8List.fromList(bytes);
      } else {
        client.close();
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
       debugPrint('❌ [AssetLoader] 简单下载失败: $e');
       // 降级策略: 尝试从默认 CDN
       if (cdnBaseUrl != defaultCdnBaseUrl) {
         final fallbackUrl = '$defaultCdnBaseUrl$fileName';
         debugPrint('🔄 [AssetLoader] 尝试从默认 CDN 下载: $fallbackUrl');
         final response = await http.get(Uri.parse(fallbackUrl));
         if (response.statusCode == 200) {
            onProgress?.call(1.0);
            return response.bodyBytes;
         }
       }
       rethrow;
    }
  }
  
  /// 强制重新下载并清除旧缓存
  static Future<void> forceRedownload() async {
     debugPrint('↻ [AssetLoader] 强制清除缓存并重新下载');
     await clearCache();
     // 下次调用 loadBuddhaModel 时会自动下载
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
    
    // 内存缓存
    for (final data in _memoryCache.values) {
      size += data.length;
    }
    
    // 文件缓存
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
