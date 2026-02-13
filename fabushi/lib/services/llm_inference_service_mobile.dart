import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Flutter Gemma 推理服务（Android/iOS 专用）
/// 
/// 基于 flutter_gemma 封装 Gemma 3n 推理能力。
/// 支持 .task 和 .litertlm 格式模型文件。
class GemmaInferenceService {
  static GemmaInferenceService? _instance;
  static GemmaInferenceService get instance => _instance ??= GemmaInferenceService._();
  GemmaInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;
  InferenceModel? _model;
  InferenceChat? _chat;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前模型路径
  String? get modelPath => _modelPath;

  /// 初始化模型
  /// 
  /// [modelPath] Gemma 模型文件路径 (.task 或 .litertlm 格式)
  /// [maxTokens] 最大生成 token 数
  Future<void> initialize(
    String modelPath, {
    int maxTokens = 1024,
  }) async {
    if (_isInitialized && _modelPath == modelPath) {
      debugPrint('GemmaInferenceService: 模型已加载，跳过重复初始化');
      return;
    }

    // 如果之前有模型，先释放
    await _cleanup();

    debugPrint('GemmaInferenceService: 开始加载模型 $modelPath');
    
    try {
      // 使用 FileSource 从本地文件安装模型
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(modelPath).install();
      
      // 获取活跃模型实例
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
      
      _modelPath = modelPath;
      _isInitialized = true;
      debugPrint('GemmaInferenceService: 模型加载成功');
    } catch (e) {
      debugPrint('GemmaInferenceService: 模型加载失败: $e');
      _isInitialized = false;
      await _cleanup();
      rethrow;
    }
  }

  /// 同步生成
  Future<String> generate(String prompt) async {
    _ensureInitialized();
    
    debugPrint('GemmaInferenceService: 生成文本，prompt长度: ${prompt.length}');
    
    // 每次对话创建新的 chat
    final chat = await _model!.createChat();
    try {
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      final response = await chat.generateChatResponse();
      if (response is TextResponse) {
        return response.token;
      }
      return '';
    } finally {
      await chat.session.close();
    }
  }
  
  /// 流式生成
  Stream<String> generateStream(String prompt) {
    _ensureInitialized();
    
    debugPrint('GemmaInferenceService: 流式生成，prompt长度: ${prompt.length}');
    
    // 使用 StreamController 包装异步生成过程
    final controller = StreamController<String>();
    
    () async {
      InferenceChat? chat;
      try {
        chat = await _model!.createChat();
        await chat.addQueryChunk(Message.text(
          text: prompt,
          isUser: true,
        ));
        
        final stream = chat.generateChatResponseAsync();
        await for (final response in stream) {
          if (response is TextResponse) {
            controller.add(response.token);
          }
        }
        await controller.close();
      } catch (e) {
        controller.addError(e);
        await controller.close();
      } finally {
        await chat?.session.close();
      }
    }();
    
    return controller.stream;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _cleanup();
    debugPrint('GemmaInferenceService: 资源已释放');
  }

  Future<void> _cleanup() async {
    await _chat?.session.close();
    _chat = null;
    await _model?.close();
    _model = null;
    _isInitialized = false;
    _modelPath = null;
  }
  
  void _ensureInitialized() {
    if (!_isInitialized || _model == null) {
      throw StateError('GemmaInferenceService 未初始化');
    }
  }
}
