import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

/// Qwen 模型管理器
/// 
/// 职责：
/// - 检测本地是否已有模型文件
/// - 从 HuggingFace 下载 GGUF 模型（带进度回调）
/// - 模型版本检查与更新
class QwenModelManager {
  static QwenModelManager? _instance;
  static QwenModelManager get instance => _instance ??= QwenModelManager._();
  QwenModelManager._();

  /// Qwen2.5-1.5B-Instruct-Q4_K_M 模型配置
  static const String modelFileName = 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf';
  static const String modelUrl = 
      'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf';
  static const int expectedSizeBytes = 986 * 1024 * 1024; // ~986 MB
  static const String modelVersion = '1.0.0';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  CancelToken? _cancelToken;
  bool _isDownloading = false;

  /// 获取模型存储目录
  Future<Directory> get _modelDirectory async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDocDir.path}/models/qwen');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// 获取模型文件路径
  Future<String> get modelPath async {
    final dir = await _modelDirectory;
    return '${dir.path}/$modelFileName';
  }

  /// 检查模型是否已下载且完整
  Future<bool> isModelAvailable() async {
    try {
      final path = await modelPath;
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }
      // 检查文件大小是否接近预期（允许5%误差）
      final size = await file.length();
      final minSize = (expectedSizeBytes * 0.95).toInt();
      return size >= minSize;
    } catch (e) {
      debugPrint('QwenModelManager: 检查模型可用性失败: $e');
      return false;
    }
  }

  /// 确保模型可用（检测或下载）
  /// 
  /// [onProgress] 下载进度回调，参数为 0.0 - 1.0
  /// 返回模型文件的本地路径
  Future<String> ensureModelAvailable({
    void Function(double progress)? onProgress,
  }) async {
    final path = await modelPath;
    
    // 检查是否已下载
    if (await isModelAvailable()) {
      debugPrint('QwenModelManager: 模型已存在: $path');
      onProgress?.call(1.0);
      return path;
    }

    // 需要下载
    debugPrint('QwenModelManager: 开始下载模型...');
    await downloadModel(onProgress: onProgress);
    return path;
  }

  /// 下载模型
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (_isDownloading) {
      throw Exception('模型正在下载中，请勿重复下载');
    }

    _isDownloading = true;
    _cancelToken = CancelToken();

    try {
      final path = await modelPath;
      final tempPath = '$path.downloading';

      debugPrint('QwenModelManager: 下载模型到 $tempPath');
      debugPrint('QwenModelManager: 模型URL: $modelUrl');

      await _dio.download(
        modelUrl,
        tempPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress?.call(progress);
            if (received % (10 * 1024 * 1024) < 1024 * 1024) {
              // 每 10MB 打印一次进度
              debugPrint('QwenModelManager: 下载进度 ${(progress * 100).toStringAsFixed(1)}%');
            }
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(hours: 2), // 大文件需要更长超时
        ),
      );

      // 下载完成，重命名文件
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(path);
        debugPrint('QwenModelManager: 模型下载完成: $path');
      }

      onProgress?.call(1.0);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugPrint('QwenModelManager: 下载已取消');
      } else {
        debugPrint('QwenModelManager: 下载失败: $e');
        rethrow;
      }
    } finally {
      _isDownloading = false;
      _cancelToken = null;
    }
  }

  /// 取消下载
  void cancelDownload() {
    _cancelToken?.cancel('用户取消下载');
  }

  /// 删除本地模型缓存
  Future<void> clearModelCache() async {
    try {
      final dir = await _modelDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('QwenModelManager: 模型缓存已清除');
      }
    } catch (e) {
      debugPrint('QwenModelManager: 清除缓存失败: $e');
    }
  }

  /// 获取已下载模型的文件大小（用于显示）
  Future<String> getModelSizeString() async {
    try {
      final path = await modelPath;
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        if (size >= 1024 * 1024 * 1024) {
          return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
        } else {
          return '${(size / (1024 * 1024)).toStringAsFixed(0)} MB';
        }
      }
    } catch (_) {}
    return '未下载';
  }

  /// 是否正在下载
  bool get isDownloading => _isDownloading;
}
