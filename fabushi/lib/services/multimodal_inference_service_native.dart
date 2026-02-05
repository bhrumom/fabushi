import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'llm_model_config.dart';
import 'llm_model_manager.dart';

/// 多模态推理服务
/// 
/// 支持图像+文本的混合输入推理，专为 Qwen3-VL 等视觉语言模型设计。
/// 使用 llama_cpp_dart 的 LlamaImage 和 sendPromptWithImages 实现图像处理。
/// 
/// 功能：
/// - 加载多模态模型（主模型 + mmproj）
/// - 图像理解与描述
/// - 多模态对话（支持图文混合输入）
/// - 流式文本生成
class MultimodalInferenceService {
  static MultimodalInferenceService? _instance;
  static MultimodalInferenceService get instance =>
      _instance ??= MultimodalInferenceService._();
  MultimodalInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;
  String? _mmprojPath;
  LLMModelType? _loadedModelType;
  
  // llama_cpp_dart 组件
  LlamaParent? _llamaParent;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前加载的模型类型
  LLMModelType? get loadedModelType => _loadedModelType;

  /// 初始化多模态模型
  /// 
  /// [modelPath] 主模型文件路径（GGUF）
  /// [mmprojPath] 视觉编码器文件路径（mmproj GGUF）
  /// [nCtx] 上下文大小（多模态需要较大上下文）
  Future<void> initialize(
    String modelPath, 
    String mmprojPath, {
    int nCtx = 4096,
  }) async {
    if (_isInitialized && 
        _modelPath == modelPath && 
        _mmprojPath == mmprojPath) {
      debugPrint('MultimodalInferenceService: 模型已加载，跳过重复初始化');
      return;
    }

    // 如果之前有模型，先释放
    if (_llamaParent != null) {
      await _disposeParent();
    }

    debugPrint('MultimodalInferenceService: 开始加载多模态模型');
    debugPrint('  主模型: $modelPath');
    debugPrint('  mmproj: $mmprojPath');

    // 检查文件是否存在
    final modelFile = File(modelPath);
    final mmprojFile = File(mmprojPath);
    if (!await modelFile.exists()) {
      throw FileSystemException('主模型文件不存在', modelPath);
    }
    if (!await mmprojFile.exists()) {
      throw FileSystemException('mmproj 文件不存在', mmprojPath);
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
      // mmprojPath 用于视觉编码器（启用多模态）
      final loadCommand = LlamaLoad(
        path: modelPath,
        mmprojPath: mmprojPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplingParams,
      );
      
      // 创建 LlamaParent（在 Isolate 中运行）
      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();

      _modelPath = modelPath;
      _mmprojPath = mmprojPath;
      _isInitialized = true;
      debugPrint('MultimodalInferenceService: 多模态模型加载成功');
    } catch (e) {
      debugPrint('MultimodalInferenceService: 模型加载失败: $e');
      _isInitialized = false;
      _llamaParent = null;
      rethrow;
    }
  }
  
  /// 使用模型类型初始化（自动获取文件路径）
  Future<void> initializeWithType(LLMModelType type) async {
    final config = LLMModelConfig.getConfig(type);
    
    if (!config.isMultimodal) {
      throw ArgumentError('模型 ${type.name} 不是多模态模型');
    }
    
    if (!config.requiresMmproj) {
      throw StateError('模型 ${type.name} 缺少 mmproj 配置');
    }
    
    final manager = LLMModelManager.instance;
    
    // 确保模型已下载
    if (!await manager.isModelAvailable(type)) {
      throw StateError('模型 ${type.name} 未下载，请先下载');
    }
    
    final modelPath = await manager.getModelPath(type);
    final mmprojPath = await manager.getMmprojPath(type);
    
    if (mmprojPath == null) {
      throw StateError('无法获取 mmproj 路径');
    }
    
    await initialize(modelPath, mmprojPath);
    _loadedModelType = type;
  }

  /// 图像理解 - 生成图像描述
  /// 
  /// [imageBytes] 图像的字节数据（支持 JPEG、PNG、WebP）
  /// [prompt] 可选的引导提示，如 "描述这张图片" 或 "这张图片中有什么动物？"
  /// [onToken] Token 流式回调
  Future<String> describeImage(
    Uint8List imageBytes, {
    String? prompt,
    void Function(String token)? onToken,
  }) async {
    _ensureInitialized();

    final effectivePrompt = prompt ?? '请详细描述这张图片的内容。';
    debugPrint('MultimodalInferenceService: 图像理解，prompt: $effectivePrompt');

    // 创建 LlamaImage
    final image = LlamaImage.fromBytes(imageBytes);
    
    // 如果需要流式回调，监听 stream
    StreamSubscription<String>? subscription;
    if (onToken != null) {
      subscription = _llamaParent!.stream.listen(onToken);
    }
    
    try {
      // 发送带图像的提示并等待完成
      final result = await _llamaParent!.sendPromptWithImages(
        effectivePrompt,
        [image],
      );
      return result ?? '';
    } finally {
      subscription?.cancel();
    }
  }

  /// 多模态对话
  /// 
  /// [textPrompt] 文本提示
  /// [images] 可选的图像列表
  /// [onToken] Token 流式回调
  Future<String> chat(
    String textPrompt, {
    List<Uint8List>? images,
    void Function(String token)? onToken,
  }) async {
    _ensureInitialized();

    final hasImages = images != null && images.isNotEmpty;
    debugPrint('MultimodalInferenceService: 多模态对话');
    debugPrint('  文本: ${textPrompt.substring(0, textPrompt.length.clamp(0, 50))}...');
    debugPrint('  图像数量: ${images?.length ?? 0}');

    // 如果需要流式回调，监听 stream
    StreamSubscription<String>? subscription;
    if (onToken != null) {
      subscription = _llamaParent!.stream.listen(onToken);
    }
    
    try {
      String? result;
      
      if (hasImages) {
        // 创建 LlamaImage 列表
        final llamaImages = images!.map((bytes) => LlamaImage.fromBytes(bytes)).toList();
        
        // 发送带图像的提示
        result = await _llamaParent!.sendPromptWithImages(textPrompt, llamaImages);
      } else {
        // 纯文本对话
        result = await _llamaParent!.sendPrompt(textPrompt);
      }
      
      return result ?? '';
    } finally {
      subscription?.cancel();
    }
  }

  /// 流式多模态对话
  /// 
  /// [textPrompt] 文本提示
  /// [images] 可选的图像列表
  Stream<String> chatStream(
    String textPrompt, {
    List<Uint8List>? images,
  }) {
    _ensureInitialized();

    debugPrint('MultimodalInferenceService: 流式多模态对话');

    final hasImages = images != null && images.isNotEmpty;
    
    if (hasImages) {
      // 创建 LlamaImage 列表
      final llamaImages = images!.map((bytes) => LlamaImage.fromBytes(bytes)).toList();
      
      // 发送带图像的提示
      _llamaParent!.sendPromptWithImages(textPrompt, llamaImages);
    } else {
      // 纯文本对话
      _llamaParent!.sendPrompt(textPrompt);
    }
    
    // 返回 token 流
    return _llamaParent!.stream;
  }
  
  /// 停止当前生成
  Future<void> stopGeneration() async {
    if (_llamaParent != null) {
      await _llamaParent!.stop();
    }
  }

  /// 视觉问答 (VQA)
  /// 
  /// [imageBytes] 图像数据
  /// [question] 关于图像的问题
  Future<String> visualQA(
    Uint8List imageBytes, 
    String question, {
    void Function(String token)? onToken,
  }) async {
    return chat(question, images: [imageBytes], onToken: onToken);
  }

  /// 图像文字识别 (OCR)
  /// 
  /// [imageBytes] 包含文字的图像
  Future<String> extractText(
    Uint8List imageBytes, {
    void Function(String token)? onToken,
  }) async {
    return describeImage(
      imageBytes,
      prompt: '请识别并提取这张图片中的所有文字内容。如果是表格，请保持表格格式。',
      onToken: onToken,
    );
  }

  /// 释放资源
  Future<void> dispose() async {
    await _disposeParent();
    _isInitialized = false;
    _modelPath = null;
    _mmprojPath = null;
    _loadedModelType = null;
    debugPrint('MultimodalInferenceService: 资源已释放');
  }
  
  Future<void> _disposeParent() async {
    if (_llamaParent != null) {
      await _llamaParent!.dispose();
      _llamaParent = null;
    }
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized || _llamaParent == null) {
      throw StateError('MultimodalInferenceService 未初始化，请先调用 initialize()');
    }
  }
}

/// 多模态消息类型
enum MultimodalMessageType {
  /// 纯文本
  text,
  
  /// 图像
  image,
  
  /// 文本+图像混合
  mixed,
}

/// 多模态消息
class MultimodalMessage {
  /// 消息类型
  final MultimodalMessageType type;
  
  /// 文本内容
  final String? text;
  
  /// 图像数据列表
  final List<Uint8List>? images;
  
  /// 是否是用户消息
  final bool isUser;
  
  /// 时间戳
  final DateTime timestamp;

  const MultimodalMessage({
    required this.type,
    this.text,
    this.images,
    required this.isUser,
    required this.timestamp,
  });
  
  /// 创建纯文本消息
  factory MultimodalMessage.text(String text, {required bool isUser}) {
    return MultimodalMessage(
      type: MultimodalMessageType.text,
      text: text,
      isUser: isUser,
      timestamp: DateTime.now(),
    );
  }
  
  /// 创建图像消息
  factory MultimodalMessage.image(
    List<Uint8List> images, {
    String? caption,
    required bool isUser,
  }) {
    return MultimodalMessage(
      type: caption != null ? MultimodalMessageType.mixed : MultimodalMessageType.image,
      text: caption,
      images: images,
      isUser: isUser,
      timestamp: DateTime.now(),
    );
  }
  
  /// 创建混合消息
  factory MultimodalMessage.mixed(
    String text,
    List<Uint8List> images, {
    required bool isUser,
  }) {
    return MultimodalMessage(
      type: MultimodalMessageType.mixed,
      text: text,
      images: images,
      isUser: isUser,
      timestamp: DateTime.now(),
    );
  }
}
