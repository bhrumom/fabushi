import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'llm_model_config.dart';

/// LLM 模型管理器
/// 
/// 职责：
/// - 管理多个 LLM 模型的下载、存储
/// - 检测本地已下载的模型
/// - 支持模型切换
/// - 支持多模态模型的双文件管理（主模型 + mmproj）
/// - 提供下载进度回调
class LLMModelManager {
  static LLMModelManager? _instance;
  static LLMModelManager get instance => _instance ??= LLMModelManager._();
  LLMModelManager._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  CancelToken? _cancelToken;
  bool _isDownloading = false;
  LLMModelType? _currentDownloadingModel;
  String _currentDownloadStage = ''; // 当前下载阶段
  double _currentDownloadProgress = 0.0; // 当前下载进度
  
  // 下载进度广播流（用于 UI 订阅）
  final _downloadProgressController = StreamController<DownloadProgressEvent>.broadcast();
  
  /// 下载进度事件流（UI 可订阅此流获取实时进度）
  Stream<DownloadProgressEvent> get downloadProgressStream => _downloadProgressController.stream;
  
  /// 当前下载进度（0.0 ~ 1.0）
  double get currentDownloadProgress => _currentDownloadProgress;
  
  // 下载源检测缓存
  HFDownloadSource? _cachedSource;
  DateTime? _sourceCheckTime;
  static const Duration _sourceCacheDuration = Duration(hours: 1);
  
  // 当前选择的模型（从设置加载）
  LLMModelType? _selectedModel;
  
  /// 当前选择的模型
  LLMModelType? get selectedModel => _selectedModel;

  /// 设置当前选择的模型
  set selectedModel(LLMModelType? type) {
    _selectedModel = type;
  }
  
  /// 获取当前使用的下载源
  HFDownloadSource? get currentSource => _cachedSource;

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 正在下载的模型类型
  LLMModelType? get currentDownloadingModel => _currentDownloadingModel;
  
  /// 当前下载阶段描述
  String get currentDownloadStage => _currentDownloadStage;
  
  /// 检测并选择最佳下载源
  /// 
  /// 并发测试官方源和镜像源的连通性，选择响应最快的源
  Future<HFDownloadSource> detectBestSource({bool forceRefresh = false}) async {
    // 使用缓存
    if (!forceRefresh && 
        _cachedSource != null && 
        _sourceCheckTime != null &&
        DateTime.now().difference(_sourceCheckTime!) < _sourceCacheDuration) {
      debugPrint('LLMModelManager: 使用缓存的下载源: ${_cachedSource!.name}');
      return _cachedSource!;
    }
    
    debugPrint('LLMModelManager: 开始检测最佳下载源...');
    
    // 测试用的小文件路径（使用一个小模型仓库的 README）
    const testPath = '/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/README.md';
    
    final officialUrl = HFSourceConfig.getFullUrl(testPath, HFDownloadSource.official);
    final mirrorUrl = HFSourceConfig.getFullUrl(testPath, HFDownloadSource.mirror);
    
    // 并发测试两个源
    final testDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    
    final results = await Future.wait([
      _testSourceConnectivity(testDio, officialUrl, HFDownloadSource.official),
      _testSourceConnectivity(testDio, mirrorUrl, HFDownloadSource.mirror),
    ]);
    
    // 选择响应最快的源
    final successfulResults = results.where((r) => r.success).toList();
    
    HFDownloadSource bestSource;
    if (successfulResults.isEmpty) {
      // 都失败了，默认使用镜像源（国内用户更可能）
      debugPrint('LLMModelManager: 两个源都无法连接，默认使用镜像源');
      bestSource = HFDownloadSource.mirror;
    } else {
      // 选择延迟最低的
      successfulResults.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
      bestSource = successfulResults.first.source;
      debugPrint('LLMModelManager: 最佳下载源: ${bestSource.name} (${successfulResults.first.latencyMs}ms)');
    }
    
    // 缓存结果
    _cachedSource = bestSource;
    _sourceCheckTime = DateTime.now();
    
    return bestSource;
  }
  
  /// 测试单个源的连通性
  Future<_SourceTestResult> _testSourceConnectivity(
    Dio dio, 
    String url, 
    HFDownloadSource source,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      await dio.head(url);
      stopwatch.stop();
      debugPrint('LLMModelManager: ${source.name} 连通，延迟 ${stopwatch.elapsedMilliseconds}ms');
      return _SourceTestResult(
        source: source,
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('LLMModelManager: ${source.name} 连接失败: $e');
      return _SourceTestResult(
        source: source,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// 获取模型存储目录
  Future<Directory> get _modelDirectory async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDocDir.path}/models/llm');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// 获取主模型文件路径
  Future<String> getModelPath(LLMModelType type) async {
    final dir = await _modelDirectory;
    final config = LLMModelConfig.getConfig(type);
    return '${dir.path}/${config.fileName}';
  }
  
  /// 获取 mmproj 文件路径（仅多模态模型）
  Future<String?> getMmprojPath(LLMModelType type) async {
    final config = LLMModelConfig.getConfig(type);
    if (!config.requiresMmproj) return null;
    
    final dir = await _modelDirectory;
    return '${dir.path}/${config.mmprojFileName}';
  }

  /// 检查主模型文件是否已下载且完整
  Future<bool> _isMainModelAvailable(LLMModelType type) async {
    try {
      final path = await getModelPath(type);
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }
      // 检查文件大小是否接近预期（允许5%误差）
      final config = LLMModelConfig.getConfig(type);
      final size = await file.length();
      final minSize = (config.expectedSizeBytes * 0.95).toInt();
      return size >= minSize;
    } catch (e) {
      debugPrint('LLMModelManager: 检查主模型可用性失败: $e');
      return false;
    }
  }
  
  /// 检查 mmproj 文件是否已下载且完整
  Future<bool> _isMmprojAvailable(LLMModelType type) async {
    final config = LLMModelConfig.getConfig(type);
    if (!config.requiresMmproj) return true; // 不需要 mmproj 的模型直接返回 true
    
    try {
      final path = await getMmprojPath(type);
      if (path == null) return true;
      
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }
      // 检查文件大小是否接近预期（允许5%误差）
      final size = await file.length();
      final minSize = ((config.mmprojSizeBytes ?? 0) * 0.95).toInt();
      return size >= minSize;
    } catch (e) {
      debugPrint('LLMModelManager: 检查mmproj可用性失败: $e');
      return false;
    }
  }

  /// 检查模型是否完全可用（主模型 + mmproj 如需要）
  Future<bool> isModelAvailable(LLMModelType type) async {
    final mainAvailable = await _isMainModelAvailable(type);
    if (!mainAvailable) return false;
    
    final mmprojAvailable = await _isMmprojAvailable(type);
    return mmprojAvailable;
  }
  
  /// 获取模型下载状态详情
  Future<ModelDownloadStatus> getModelDownloadStatus(LLMModelType type) async {
    final config = LLMModelConfig.getConfig(type);
    final mainAvailable = await _isMainModelAvailable(type);
    final mmprojAvailable = await _isMmprojAvailable(type);
    
    if (_isDownloading && _currentDownloadingModel == type) {
      return ModelDownloadStatus.downloading;
    }
    
    if (!config.requiresMmproj) {
      return mainAvailable 
          ? ModelDownloadStatus.complete 
          : ModelDownloadStatus.notDownloaded;
    }
    
    // 多模态模型需要检查两个文件
    if (mainAvailable && mmprojAvailable) {
      return ModelDownloadStatus.complete;
    } else if (mainAvailable && !mmprojAvailable) {
      return ModelDownloadStatus.partialMmprojMissing;
    } else {
      return ModelDownloadStatus.notDownloaded;
    }
  }

  /// 获取所有已下载的模型
  Future<List<LLMModelType>> getDownloadedModels() async {
    final downloaded = <LLMModelType>[];
    for (final type in LLMModelType.values) {
      if (await isModelAvailable(type)) {
        downloaded.add(type);
      }
    }
    return downloaded;
  }

  /// 获取所有模型的状态
  Future<Map<LLMModelType, ModelStatus>> getAllModelStatus() async {
    final status = <LLMModelType, ModelStatus>{};
    for (final type in LLMModelType.values) {
      if (_isDownloading && _currentDownloadingModel == type) {
        status[type] = ModelStatus.downloading;
      } else if (await isModelAvailable(type)) {
        status[type] = ModelStatus.downloaded;
      } else {
        status[type] = ModelStatus.notDownloaded;
      }
    }
    return status;
  }

  /// 确保模型可用（检测或下载）
  /// 
  /// [onProgress] 下载进度回调，参数为 (progress: 0.0-1.0, stage: 阶段描述)
  /// 返回模型文件的本地路径
  Future<String> ensureModelAvailable(
    LLMModelType type, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    final path = await getModelPath(type);
    
    // 检查是否已下载
    if (await isModelAvailable(type)) {
      debugPrint('LLMModelManager: 模型已存在: $path');
      onProgress?.call(1.0, '已就绪');
      return path;
    }

    // 需要下载
    debugPrint('LLMModelManager: 开始下载模型 ${type.name}...');
    await downloadModel(type, onProgress: onProgress);
    return path;
  }

  /// 下载模型（包括 mmproj 如需要）
  Future<void> downloadModel(
    LLMModelType type, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    if (_isDownloading) {
      throw Exception('已有模型正在下载中，请等待完成后再试');
    }

    _isDownloading = true;
    _currentDownloadingModel = type;
    _cancelToken = CancelToken();

    try {
      final config = LLMModelConfig.getConfig(type);
      
      // 检测最佳下载源
      _currentDownloadStage = '检测网络环境';
      _currentDownloadProgress = 0.0;
      _emitProgress(type, 0.0, _currentDownloadStage);
      onProgress?.call(0.0, _currentDownloadStage);
      final source = await detectBestSource();
      debugPrint('LLMModelManager: 使用下载源: ${source.name}');
      
      // 计算总大小（用于多文件时的整体进度）
      final totalSize = config.totalSizeBytes;
      int downloadedBytes = 0;
      
      // 阶段1：下载主模型
      if (!await _isMainModelAvailable(type)) {
        _currentDownloadStage = '下载主模型';
        _emitProgress(type, 0.0, _currentDownloadStage);
        onProgress?.call(0.0, _currentDownloadStage);
        
        await _downloadFile(
          url: config.downloadUrl,
          fileName: config.fileName,
          expectedSize: config.expectedSizeBytes,
          onReceiveProgress: (received, total) {
            downloadedBytes = received;
            final progress = downloadedBytes / totalSize;
            _currentDownloadProgress = progress;
            _emitProgress(type, progress, _currentDownloadStage);
            onProgress?.call(progress, _currentDownloadStage);
          },
        );
        
        downloadedBytes = config.expectedSizeBytes;
      } else {
        downloadedBytes = config.expectedSizeBytes;
      }
      
      // 阶段2：下载 mmproj（如需要）
      if (config.requiresMmproj && !await _isMmprojAvailable(type)) {
        _currentDownloadStage = '下载视觉编码器';
        _emitProgress(type, downloadedBytes / totalSize, _currentDownloadStage);
        onProgress?.call(downloadedBytes / totalSize, _currentDownloadStage);
        
        await _downloadFile(
          url: config.mmprojDownloadUrl!,
          fileName: config.mmprojFileName!,
          expectedSize: config.mmprojSizeBytes!,
          onReceiveProgress: (received, total) {
            final progress = (downloadedBytes + received) / totalSize;
            _currentDownloadProgress = progress;
            _emitProgress(type, progress, _currentDownloadStage);
            onProgress?.call(progress, _currentDownloadStage);
          },
        );
      }

      _currentDownloadStage = '下载完成';
      _currentDownloadProgress = 1.0;
      _emitProgress(type, 1.0, _currentDownloadStage, isComplete: true);
      onProgress?.call(1.0, _currentDownloadStage);
      
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugPrint('LLMModelManager: 下载已取消');
      } else {
        debugPrint('LLMModelManager: 下载失败: $e');
        rethrow;
      }
    } finally {
      _isDownloading = false;
      _currentDownloadingModel = null;
      _currentDownloadStage = '';
      _currentDownloadProgress = 0.0;
      _cancelToken = null;
    }
  }
  
  /// 内部下载方法
  Future<void> _downloadFile({
    required String url,
    required String fileName,
    required int expectedSize,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final dir = await _modelDirectory;
    final path = '${dir.path}/$fileName';
    final tempPath = '$path.downloading';
    
    // 将 HuggingFace URL 转换为使用检测到的最佳源
    // 注意：非 HuggingFace URL（如 Google Storage）不应转换
    String actualUrl = url;
    final isHuggingFaceUrl = url.contains('huggingface.co') || 
                              url.contains('hf-mirror.com');
    if (_cachedSource != null && isHuggingFaceUrl) {
      final relativePath = HFSourceConfig.extractRelativePath(url);
      actualUrl = HFSourceConfig.getFullUrl(relativePath, _cachedSource!);
    }

    debugPrint('LLMModelManager: 下载文件到 $tempPath');
    debugPrint('LLMModelManager: URL: $actualUrl');

    await _dio.download(
      actualUrl,
      tempPath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        onReceiveProgress?.call(received, total > 0 ? total : expectedSize);
        if (received % (10 * 1024 * 1024) < 1024 * 1024) {
          // 每 10MB 打印一次进度
          final progress = received / (total > 0 ? total : expectedSize);
          debugPrint('LLMModelManager: 下载进度 ${(progress * 100).toStringAsFixed(1)}%');
        }
      },
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(hours: 2), // 大文件需要更长接收超时
      ),
    );

    // 下载完成，重命名文件
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.rename(path);
      debugPrint('LLMModelManager: 文件下载完成: $path');
    }
  }
  
  /// 发送下载进度事件
  void _emitProgress(
    LLMModelType type, 
    double progress, 
    String stage, {
    bool isComplete = false,
    bool isFailed = false,
    String? error,
  }) {
    if (!_downloadProgressController.isClosed) {
      _downloadProgressController.add(DownloadProgressEvent(
        modelType: type,
        progress: progress,
        stage: stage,
        isComplete: isComplete,
        isFailed: isFailed,
        error: error,
      ));
    }
  }

  /// 取消下载
  void cancelDownload() {
    _cancelToken?.cancel('用户取消下载');
  }

  /// 删除指定模型（包括 mmproj）
  Future<void> deleteModel(LLMModelType type) async {
    try {
      // 删除主模型
      final mainPath = await getModelPath(type);
      final mainFile = File(mainPath);
      if (await mainFile.exists()) {
        await mainFile.delete();
        debugPrint('LLMModelManager: 主模型已删除: ${type.name}');
      }
      
      // 删除 mmproj（如有）
      final mmprojPath = await getMmprojPath(type);
      if (mmprojPath != null) {
        final mmprojFile = File(mmprojPath);
        if (await mmprojFile.exists()) {
          await mmprojFile.delete();
          debugPrint('LLMModelManager: mmproj已删除: ${type.name}');
        }
      }
    } catch (e) {
      debugPrint('LLMModelManager: 删除模型失败: $e');
    }
  }

  /// 删除所有模型缓存
  Future<void> clearAllModelCache() async {
    try {
      final dir = await _modelDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('LLMModelManager: 所有模型缓存已清除');
      }
    } catch (e) {
      debugPrint('LLMModelManager: 清除缓存失败: $e');
    }
  }

  /// 获取单个模型的总文件大小描述（主模型 + mmproj）
  Future<String> getModelSizeString(LLMModelType type) async {
    try {
      int totalSize = 0;
      
      // 主模型
      final mainPath = await getModelPath(type);
      final mainFile = File(mainPath);
      if (await mainFile.exists()) {
        totalSize += await mainFile.length();
      }
      
      // mmproj
      final mmprojPath = await getMmprojPath(type);
      if (mmprojPath != null) {
        final mmprojFile = File(mmprojPath);
        if (await mmprojFile.exists()) {
          totalSize += await mmprojFile.length();
        }
      }
      
      if (totalSize == 0) return '未下载';
      
      if (totalSize >= 1024 * 1024 * 1024) {
        return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      } else {
        return '${(totalSize / (1024 * 1024)).toStringAsFixed(0)} MB';
      }
    } catch (_) {}
    return '未下载';
  }

  /// 获取所有模型占用的总空间
  Future<int> getTotalCacheSize() async {
    int total = 0;
    for (final type in LLMModelType.values) {
      try {
        final mainPath = await getModelPath(type);
        final mainFile = File(mainPath);
        if (await mainFile.exists()) {
          total += await mainFile.length();
        }
        
        final mmprojPath = await getMmprojPath(type);
        if (mmprojPath != null) {
          final mmprojFile = File(mmprojPath);
          if (await mmprojFile.exists()) {
            total += await mmprojFile.length();
          }
        }
      } catch (_) {}
    }
    return total;
  }
}

/// 模型状态枚举
enum ModelStatus {
  /// 未下载
  notDownloaded,
  
  /// 下载中
  downloading,
  
  /// 已下载
  downloaded,
}

/// 模型下载状态（详细）
enum ModelDownloadStatus {
  /// 未下载
  notDownloaded,
  
  /// 下载中
  downloading,
  
  /// 部分下载（主模型已下载，mmproj 缺失）
  partialMmprojMissing,
  
  /// 完全下载
  complete,
}

/// 源连通性测试结果（内部使用）
class _SourceTestResult {
  final HFDownloadSource source;
  final bool success;
  final int latencyMs;
  
  _SourceTestResult({
    required this.source,
    required this.success,
    required this.latencyMs,
  });
}

/// 下载进度事件
class DownloadProgressEvent {
  /// 正在下载的模型类型
  final LLMModelType modelType;
  
  /// 下载进度（0.0 ~ 1.0）
  final double progress;
  
  /// 当前下载阶段描述
  final String stage;
  
  /// 是否下载完成
  final bool isComplete;
  
  /// 是否下载失败
  final bool isFailed;
  
  /// 错误信息（仅 isFailed 时有效）
  final String? error;
  
  const DownloadProgressEvent({
    required this.modelType,
    required this.progress,
    required this.stage,
    this.isComplete = false,
    this.isFailed = false,
    this.error,
  });
}
