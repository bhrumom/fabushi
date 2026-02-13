import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Llama.cpp 推理服务（macOS 专用）
/// 
/// 基于 llama_cpp_dart 封装 llama.cpp 推理能力。
/// 使用 Isolate 隔离执行，不阻塞 UI 线程。
class LlamaInferenceService {
  static LlamaInferenceService? _instance;
  static LlamaInferenceService get instance => _instance ??= LlamaInferenceService._();
  LlamaInferenceService._();

  bool _isInitialized = false;
  String? _modelPath;
  LlamaParent? _llamaParent;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前模型路径
  String? get modelPath => _modelPath;

  /// 初始化模型
  Future<void> initialize(String modelPath, {int? nCtx}) async {
    final effectiveNCtx = nCtx ?? 2048;
    
    if (_isInitialized && _modelPath == modelPath) {
      debugPrint('LlamaInferenceService: 模型已加载，跳过重复初始化');
      return;
    }

    if (_llamaParent != null) {
      await _disposeParent();
    }

    debugPrint('LlamaInferenceService: 开始加载模型 $modelPath');
    
    // macOS 平台设置库路径
    if (Platform.isMacOS && Llama.libraryPath == null) {
      final executablePath = Platform.resolvedExecutable;
      final macOSDir = executablePath.substring(0, executablePath.lastIndexOf('/'));
      final contentsDir = macOSDir.substring(0, macOSDir.lastIndexOf('/'));
      final libPath = '$contentsDir/Frameworks/libllama.dylib';
      debugPrint('LlamaInferenceService: macOS 库路径: $libPath');
      Llama.libraryPath = libPath;
    }
    
    // 验证文件
    final file = File(modelPath);
    if (!await file.exists()) {
      throw FileSystemException('模型文件不存在', modelPath);
    }
    
    // 验证 GGUF 格式
    final raf = await file.open();
    final header = await raf.read(4);
    await raf.close();
    final isGGUF = header.length == 4 && 
                   header[0] == 0x47 && header[1] == 0x47 && 
                   header[2] == 0x55 && header[3] == 0x46;
    if (!isGGUF) {
      throw Exception('模型文件格式无效，不是有效的 GGUF 文件');
    }
    
    try {
      final modelParams = ModelParams();
      final contextParams = ContextParams()..nCtx = effectiveNCtx;
      final samplingParams = SamplerParams();
      
      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplingParams,
        verbose: false,
      );
      
      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();
      
      _modelPath = modelPath;
      _isInitialized = true;
      debugPrint('LlamaInferenceService: 模型加载成功');
    } catch (e) {
      debugPrint('LlamaInferenceService: 模型加载失败: $e');
      _isInitialized = false;
      _llamaParent = null;
      rethrow;
    }
  }

  /// 生成文本
  Future<String> generate(String prompt, {void Function(String token)? onToken}) async {
    _ensureInitialized();
    
    StreamSubscription<String>? subscription;
    if (onToken != null) {
      subscription = _llamaParent!.stream.listen(onToken);
    }
    
    try {
      final result = await _llamaParent!.sendPrompt(prompt);
      return result ?? '';
    } finally {
      subscription?.cancel();
    }
  }
  
  /// 流式生成
  Stream<String> generateStream(String prompt) {
    _ensureInitialized();
    _llamaParent!.sendPrompt(prompt);
    return _llamaParent!.stream;
  }
  
  /// 停止生成
  Future<void> stopGeneration() async {
    if (_llamaParent != null) {
      await _llamaParent!.stop();
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _disposeParent();
    _isInitialized = false;
    _modelPath = null;
  }
  
  Future<void> _disposeParent() async {
    if (_llamaParent != null) {
      await _llamaParent!.dispose();
      _llamaParent = null;
    }
  }
  
  void _ensureInitialized() {
    if (!_isInitialized || _llamaParent == null) {
      throw StateError('LlamaInferenceService 未初始化');
    }
  }
}
