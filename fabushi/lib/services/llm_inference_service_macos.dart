import 'dart:async';
import 'dart:io';
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
    final effectiveNCtx = nCtx ?? 1024;
    
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
      final contextParams = ContextParams()
        ..nCtx = effectiveNCtx
        ..nBatch = effectiveNCtx
        ..autoTrimContext = true
        ..trimKeepTokens = 0
        ..nPredict = 512;
      final samplingParams = SamplerParams()
        ..temp = 0.7
        ..penaltyRepeat = 1.1;
      
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
  /// 
  /// 注意：LlamaParent.stream 是 broadcast stream，不缓存事件。
  /// 必须先订阅再发送 prompt，否则早期 token 或 isDone 事件会丢失，
  /// 导致页面永远停在"生成中"状态。
  Stream<String> generateStream(String prompt) {
    _ensureInitialized();
    
    debugPrint('LlamaInferenceService: generateStream 开始');
    debugPrint('LlamaInferenceService: prompt 长度=${prompt.length} 字符');
    
    // 创建一个非-broadcast controller，确保事件不丢失
    final controller = StreamController<String>();
    
    // 先订阅 broadcast stream
    StreamSubscription<String>? sub;
    StreamSubscription? completionSub;
    String? promptId;
    final pendingCompletions = <CompletionEvent>[];
    bool isClosed = false;
    
    void closeAll() {
      if (isClosed) return;
      isClosed = true;
      debugPrint('LlamaInferenceService: 关闭流');
      if (!controller.isClosed) controller.close();
      sub?.cancel();
      completionSub?.cancel();
    }
    
    void checkCompletion(CompletionEvent event) {
      if (promptId != null && event.promptId == promptId) {
        debugPrint('LlamaInferenceService: 推理完成 (promptId=$promptId, success=${event.success}, error=${event.errorDetails})');
        if (!event.success && !controller.isClosed) {
          controller.addError(Exception(event.errorDetails ?? '推理失败（未知原因）'));
        }
        closeAll();
      }
    }
    
    int tokenCount = 0;
    sub = _llamaParent!.stream.listen(
      (token) {
        tokenCount++;
        if (tokenCount <= 3 || tokenCount % 50 == 0) {
          debugPrint('LlamaInferenceService: 收到token #$tokenCount: ${token.length > 20 ? token.substring(0, 20) + "..." : token}');
        }
        if (!controller.isClosed) {
          controller.add(token);
        }
      },
      onError: (error) {
        debugPrint('LlamaInferenceService: stream 错误: $error');
        if (!controller.isClosed) {
          controller.addError(error);
        }
        closeAll();
      },
    );
    
    // 监听完成事件
    completionSub = _llamaParent!.completions.listen((event) {
      debugPrint('LlamaInferenceService: 收到 completion event (eventPromptId=${event.promptId}, myPromptId=$promptId, success=${event.success})');
      if (promptId != null) {
        checkCompletion(event);
      } else {
        // promptId 还未设置，缓存事件
        pendingCompletions.add(event);
      }
    });
    
    // 然后发送 prompt（此时订阅已就绪，不会丢失事件）
    _llamaParent!.sendPrompt(prompt).then((id) {
      promptId = id;
      debugPrint('LlamaInferenceService: sendPrompt 完成, promptId=$id');
      // 检查在 promptId 设置前已收到的 completion 事件
      for (final event in pendingCompletions) {
        checkCompletion(event);
      }
      pendingCompletions.clear();
    }).catchError((error) {
      debugPrint('LlamaInferenceService: sendPrompt 失败: $error');
      if (!controller.isClosed) {
        controller.addError(error);
      }
      closeAll();
    });
    
    // 取消时的清理
    controller.onCancel = () {
      debugPrint('LlamaInferenceService: stream 被取消');
      closeAll();
    };
    
    return controller.stream;
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
