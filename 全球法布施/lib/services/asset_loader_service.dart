import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// 大型资源动态加载服务
/// 
/// 用于从 CDN 加载大型 3D 模型等资源,避免打包到应用中
/// 实现缓存机制以提高后续加载速度
class AssetLoaderService {
  static const String defaultCdnBaseUrl = 'https://flutter.ombhrum.com/r2?file=';
  
  static String cdnBaseUrl = defaultCdnBaseUrl;
  
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
  /// [fileName] 文件名
  /// [onProgress] 下载进度回调 (0.0 - 1.0)
  /// [forceRefresh] 强制重新下载,忽略缓存
  static Future<Uint8List> _loadAsset(
    String fileName, {
    void Function(double progress)? onProgress,
    bool forceRefresh = false,
  }) async {
    // 1. 检查内存缓存
    if (!forceRefresh && _memoryCache.containsKey(fileName)) {
      debugPrint('✅ 从内存缓存加载: $fileName');
      return _memoryCache[fileName]!;
    }
    
    // 2. 检查本地文件缓存
    if (!forceRefresh) {
      final cached = await _loadFromFileCache(fileName);
      if (cached != null) {
        debugPrint('✅ 从文件缓存加载: $fileName');
        _memoryCache[fileName] = cached;
        return cached;
      }
    }
    
    // 3. 从 CDN 下载
    debugPrint('📥 从 CDN 下载: $fileName');
    final data = await _downloadFromCdn(fileName, onProgress: onProgress);
    
    // 4. 保存到缓存
    _memoryCache[fileName] = data;
    await _saveToFileCache(fileName, data);
    
    return data;
  }
  
  /// 从 CDN 下载资源
  static Future<Uint8List> _downloadFromCdn(
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
      debugPrint('❌ CDN 下载失败: $e');
      
      // 降级策略: 尝试从备用地址加载
      if (cdnBaseUrl != defaultCdnBaseUrl) {
        debugPrint('🔄 尝试从默认 CDN 加载...');
        final fallbackUrl = '$defaultCdnBaseUrl$fileName';
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          onProgress?.call(1.0);
          return response.bodyBytes;
        }
      }
      
      rethrow;
    }
  }
  
  /// 从本地文件缓存加载
  static Future<Uint8List?> _loadFromFileCache(String fileName) async {
    if (kIsWeb) return null; // Web 不支持文件缓存
    
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final file = File('${cacheDir.path}/models/$fileName');
      
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('⚠️ 读取文件缓存失败: $e');
    }
    
    return null;
  }
  
  /// 保存到本地文件缓存
  static Future<void> _saveToFileCache(String fileName, Uint8List data) async {
    if (kIsWeb) return; // Web 不支持文件缓存
    
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final modelDir = Directory('${cacheDir.path}/models');
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      final file = File('${modelDir.path}/$fileName');
      await file.writeAsBytes(data);
      
      debugPrint('💾 已保存到文件缓存: $fileName');
    } catch (e) {
      debugPrint('⚠️ 保存文件缓存失败: $e');
    }
  }
  
  /// 清除所有缓存
  static Future<void> clearCache() async {
    _memoryCache.clear();
    
    if (!kIsWeb) {
      try {
        final cacheDir = await getApplicationCacheDirectory();
        final modelDir = Directory('${cacheDir.path}/models');
        
        if (await modelDir.exists()) {
          await modelDir.delete(recursive: true);
        }
        
        debugPrint('🗑️ 已清除资源缓存');
      } catch (e) {
        debugPrint('⚠️ 清除缓存失败: $e');
      }
    }
  }
  
  /// 预加载资源
  /// 
  /// 在空闲时预先下载资源到缓存
  static Future<void> preloadAssets(List<String> fileNames) async {
    for (final fileName in fileNames) {
      try {
        await _loadAsset(fileName);
        debugPrint('✅ 预加载完成: $fileName');
      } catch (e) {
        debugPrint('⚠️ 预加载失败: $fileName - $e');
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
        final cacheDir = await getApplicationCacheDirectory();
        final modelDir = Directory('${cacheDir.path}/models');
        
        if (await modelDir.exists()) {
          await for (final entity in modelDir.list(recursive: true)) {
            if (entity is File) {
              size += await entity.length();
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ 获取缓存大小失败: $e');
      }
    }
    
    return size;
  }
}
