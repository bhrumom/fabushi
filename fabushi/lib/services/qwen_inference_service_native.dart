import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Qwen 推理服务
/// 
/// 基于 llama_cpp_dart 封装 llama.cpp 推理能力。
/// 使用 Isolate 隔离执行，不阻塞 UI 线程。
/// 
/// 提供：
/// - 模型初始化与加载
/// - 文本生成（流式 + 阻塞）
/// - 语义嵌入生成（用于句子相似度计算）
class QwenInferenceService {
  static QwenInferenceService? _instance;
  static QwenInferenceService get instance => _instance ??= QwenInferenceService._();
  QwenInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;
  LlamaParent? _llamaParent;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前模型路径
  String? get modelPath => _modelPath;

  /// 初始化模型
  /// 
  /// [modelPath] GGUF 模型文件的本地路径
  /// [nCtx] 上下文大小（默认 2048）
  Future<void> initialize(
    String modelPath, {
    int nCtx = 2048,
  }) async {
    if (_isInitialized && _modelPath == modelPath) {
      debugPrint('QwenInferenceService: 模型已加载，跳过重复初始化');
      return;
    }

    // 如果之前有模型，先释放
    if (_llamaParent != null) {
      await _disposeParent();
    }

    debugPrint('QwenInferenceService: 开始加载模型: $modelPath');
    
    // macOS 平台需要设置库路径，因为 llama_cpp_dart 默认使用 DynamicLibrary.process()
    // 但 dylib 没有链接到应用程序中，需要显式指定路径
    if (Platform.isMacOS && Llama.libraryPath == null) {
      final executablePath = Platform.resolvedExecutable;
      // 从 .../MacOS/global_dharma_sharing 路径获取 .../Frameworks
      final macOSDir = executablePath.substring(0, executablePath.lastIndexOf('/'));
      final contentsDir = macOSDir.substring(0, macOSDir.lastIndexOf('/'));
      final libPath = '$contentsDir/Frameworks/libllama.dylib';
      debugPrint('QwenInferenceService: 设置 macOS 库路径: $libPath');
      Llama.libraryPath = libPath;
    }
    
    // 检查文件是否存在
    final file = File(modelPath);
    if (!await file.exists()) {
      throw FileSystemException('模型文件不存在', modelPath);
    }

    
    try {
      // 配置模型参数
      final modelParams = ModelParams();
      
      // 配置上下文参数（使用级联操作符设置属性）
      final contextParams = ContextParams()
        ..nCtx = nCtx;
      
      // 配置采样参数（使用默认值）
      final samplingParams = SamplerParams();
      
      // 创建加载命令
      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplingParams,
      );
      
      // 创建 LlamaParent（在 Isolate 中运行）
      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();
      
      _modelPath = modelPath;
      _isInitialized = true;
      debugPrint('QwenInferenceService: 模型加载成功');
    } catch (e) {
      debugPrint('QwenInferenceService: 模型加载失败: $e');
      _isInitialized = false;
      _llamaParent = null;
      rethrow;
    }
  }

  /// 生成文本（阻塞式）
  /// 
  /// [prompt] 输入提示
  /// [onToken] Token 流式回调
  Future<String> generate(
    String prompt, {
    void Function(String token)? onToken,
  }) async {
    _ensureInitialized();
    
    debugPrint('QwenInferenceService: 生成文本，prompt长度: ${prompt.length}');
    
    // 如果需要流式回调，监听 stream
    StreamSubscription<String>? subscription;
    if (onToken != null) {
      subscription = _llamaParent!.stream.listen(onToken);
    }
    
    try {
      // 发送提示并等待完成
      final result = await _llamaParent!.sendPrompt(prompt);
      return result ?? '';
    } finally {
      subscription?.cancel();
    }
  }
  
  /// 流式生成文本
  /// 
  /// [prompt] 输入提示
  Stream<String> generateStream(String prompt) {
    _ensureInitialized();
    
    debugPrint('QwenInferenceService: 流式生成，prompt长度: ${prompt.length}');
    
    // 发送提示
    _llamaParent!.sendPrompt(prompt);
    
    // 返回 token 流
    return _llamaParent!.stream;
  }
  
  /// 停止当前生成
  Future<void> stopGeneration() async {
    if (_llamaParent != null) {
      await _llamaParent!.stop();
    }
  }

  /// 生成语义嵌入向量
  /// 
  /// 将输入文本转换为固定维度的向量表示，用于计算语义相似度。
  /// 注意：需要使用嵌入模型（如 Qwen3-Embedding）才能获得真正的嵌入向量。
  /// 如果使用普通对话模型，将使用占位嵌入。
  /// 
  /// 返回：嵌入向量
  Future<List<double>> getEmbedding(String text) async {
    _ensureInitialized();
    
    try {
      // 尝试使用 llama_cpp_dart 的嵌入功能
      final embeddings = await _llamaParent!.getEmbeddings(text);
      if (embeddings.isNotEmpty) {
        return embeddings;
      }
    } catch (e) {
      debugPrint('QwenInferenceService: 嵌入生成失败，使用占位实现: $e');
    }
    
    // 回退到占位实现
    return _generatePlaceholderEmbedding(text);
  }

  /// 计算两个文本的语义相似度
  /// 
  /// 返回：相似度分数（0.0 - 1.0）
  Future<double> calculateSimilarity(String text1, String text2) async {
    final emb1 = await getEmbedding(text1);
    final emb2 = await getEmbedding(text2);
    return _cosineSimilarity(emb1, emb2);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _disposeParent();
    _isInitialized = false;
    _modelPath = null;
    debugPrint('QwenInferenceService: 资源已释放');
  }
  
  Future<void> _disposeParent() async {
    if (_llamaParent != null) {
      await _llamaParent!.dispose();
      _llamaParent = null;
    }
  }
  
  void _ensureInitialized() {
    if (!_isInitialized || _llamaParent == null) {
      throw StateError('QwenInferenceService 未初始化，请先调用 initialize()');
    }
  }

  // ============== 私有方法 ==============

  /// 余弦相似度计算
  double _cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    
    double dot = 0.0;
    double mag1 = 0.0;
    double mag2 = 0.0;
    
    for (int i = 0; i < v1.length; i++) {
      dot += v1[i] * v2[i];
      mag1 += v1[i] * v1[i];
      mag2 += v2[i] * v2[i];
    }
    
    if (mag1 == 0 || mag2 == 0) return 0.0;
    return dot / (math.sqrt(mag1) * math.sqrt(mag2));
  }

  /// 占位嵌入生成（基于关键词的简单向量）
  /// 
  /// 这是一个临时实现，在使用嵌入模型时会被替换。
  List<double> _generatePlaceholderEmbedding(String text) {
    // 功德福德类关键词
    const meritKeywords = [
      '功德', '福德', '福报', '福慧', '善根', '善业',
      '灭罪', '消业', '除障', '离苦', '解脱', '往生', '成佛',
    ];
    
    // 利益类关键词
    const benefitKeywords = [
      '能除', '能灭', '能消', '能得', '能令', '能使',
      '悉皆', '一切', '无量', '不可思议', '无边',
    ];
    
    // 生成简单的特征向量（64维）
    final embedding = List<double>.filled(64, 0.0);
    
    // 关键词特征
    for (int i = 0; i < meritKeywords.length && i < 32; i++) {
      if (text.contains(meritKeywords[i])) {
        embedding[i] = 1.0;
      }
    }
    
    for (int i = 0; i < benefitKeywords.length && i < 32; i++) {
      if (text.contains(benefitKeywords[i])) {
        embedding[32 + i] = 1.0;
      }
    }
    
    // 归一化
    double mag = 0.0;
    for (final v in embedding) {
      mag += v * v;
    }
    if (mag > 0) {
      mag = math.sqrt(mag);
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= mag;
      }
    }
    
    return embedding;
  }
}
