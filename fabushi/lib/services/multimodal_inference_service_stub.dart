// Web 平台的 stub 实现
// llama_cpp_dart 不支持 Web，此文件提供空实现

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'llm_model_config.dart';

/// Web 平台的多模态推理服务 (禁用状态)
class MultimodalInferenceService {
  static MultimodalInferenceService? _instance;
  static MultimodalInferenceService get instance =>
      _instance ??= MultimodalInferenceService._();
  MultimodalInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;
  String? _mmprojPath;
  LLMModelType? _loadedModelType;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 当前加载的模型类型
  LLMModelType? get loadedModelType => _loadedModelType;

  /// 初始化多模态模型 (Web 不支持)
  Future<void> initialize(
    String modelPath,
    String mmprojPath, {
    int nCtx = 4096,
  }) async {
    debugPrint('MultimodalInferenceService: Web 平台不支持本地多模态推理');
    throw UnsupportedError('Web 平台不支持本地多模态推理');
  }

  /// 使用模型类型初始化 (Web 不支持)
  Future<void> initializeWithType(LLMModelType type) async {
    throw UnsupportedError('Web 平台不支持本地多模态推理');
  }

  /// 图像理解 (Web 不支持)
  Future<String> describeImage(
    Uint8List imageBytes, {
    String? prompt,
    void Function(String token)? onToken,
  }) async {
    throw UnsupportedError('Web 平台不支持本地多模态推理');
  }

  /// 多模态对话 (Web 不支持)
  Future<String> chat(
    String textPrompt, {
    List<Uint8List>? images,
    void Function(String token)? onToken,
  }) async {
    throw UnsupportedError('Web 平台不支持本地多模态推理');
  }

  /// 流式多模态对话 (Web 不支持)
  Stream<String> chatStream(String textPrompt, {List<Uint8List>? images}) {
    throw UnsupportedError('Web 平台不支持本地多模态推理');
  }

  /// 停止当前生成
  Future<void> stopGeneration() async {}

  /// 视觉问答 (Web 不支持)
  Future<String> visualQA(
    Uint8List imageBytes,
    String question, {
    void Function(String token)? onToken,
  }) async {
    throw UnsupportedError('Web 平台不支持本地多模态推理');
  }

  /// 图像文字识别 (Web 不支持)
  Future<String> extractText(
    Uint8List imageBytes, {
    void Function(String token)? onToken,
  }) async {
    throw UnsupportedError('Web 平台不支持本地多模态推理');
  }

  /// 释放资源
  Future<void> dispose() async {
    _isInitialized = false;
    _modelPath = null;
    _mmprojPath = null;
    _loadedModelType = null;
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
      type: caption != null
          ? MultimodalMessageType.mixed
          : MultimodalMessageType.image,
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
