import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// 大型资源动态加载服务
/// 
/// 用于从 CDN 加载大型 3D 模型等资源,避免打包到应用中
/// 实现断点续传和持久化缓存机制
class AssetLoaderService {
  static const String defaultCdnBaseUrl = 'https://flutter.ombhrum.com/r2?file=';
  
  static String cdnBaseUrl = defaultCdnBaseUrl;
  
  // 内存缓存 (仅用于当前会话)
  static final Map<String, Uint8List> _memoryCache = {};
  
  /// 加载佛像模型
  /// 
  /// 返回模型数据的 Uint8List,可以传递给 three_js 的 GLTFLoader
  static Future<Uint8List> loadBuddhaModel({
    void Function(double progress)? onProgress
  }) async {
    return await _loadAsset(
      'models/buddha_model.glb',
      onProgress: onProgress,
    );
  }
  
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
    
    // 2. 检查本地持久化文件
    if (!forceRefresh) {
      final cached = await _loadFromPersistentStorage(fileName);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('✅ [AssetLoader] 从本地存储加载: $fileName (${cached.lengthInBytes} bytes)');
        _memoryCache[fileName] = cached;
        onProgress?.call(1.0);
        return cached;
      }
    }
    
    // 3. 执行断点续传下载
    debugPrint('📥 [AssetLoader] 开始下载: $fileName');
    final data = await _downloadResumable(fileName, onProgress: onProgress);
    
    // 4. 更新内存缓存
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

  /// 从本地持久化存储加载
  static Future<Uint8List?> _loadFromPersistentStorage(String fileName) async {
    if (kIsWeb) return null;
    
    try {
      final dir = await _getStorageDirectory();
      // 处理文件名中的路径分隔符
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
      final request = http.Request('GET', Uri.parse(url));
      
      // 添加 Range 头
      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await client.send(request);
      
      if (response.statusCode == 200 || response.statusCode == 206) {
        final totalLength = (response.contentLength ?? 0) + downloadedBytes;
        debugPrint('📥 [AssetLoader] 总大小: $totalLength bytes, 响应状态: ${response.statusCode}');

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
          }
        }
        
        await sink.flush();
        await sink.close();
        client.close();

        // 下载完成，重命名为正式文件
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(finalFile.path);
        debugPrint('✅ [AssetLoader] 下载完成并保存: ${finalFile.path}');
        
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
