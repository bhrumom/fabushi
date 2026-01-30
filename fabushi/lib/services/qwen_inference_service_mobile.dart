import 'dart:async';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// 初始化模型（移动端）
Future<LlamaParent> initializeModel(String modelPath, int nCtx) async {
  final modelParams = ModelParams();
  
  final contextParams = ContextParams()
    ..nCtx = nCtx;
  
  final samplingParams = SamplerParams();
  
  final loadCommand = LlamaLoad(
    path: modelPath,
    modelParams: modelParams,
    contextParams: contextParams,
    samplingParams: samplingParams,
  );
  
  final llamaParent = LlamaParent(loadCommand);
  await llamaParent.init();
  
  return llamaParent;
}

/// 生成文本
Future<String> generate(dynamic inference, String prompt, void Function(String token)? onToken) async {
  final llamaParent = inference as LlamaParent;
  
  StreamSubscription<String>? subscription;
  if (onToken != null) {
    subscription = llamaParent.stream.listen(onToken);
  }
  
  try {
    final result = await llamaParent.sendPrompt(prompt);
    return result ?? '';
  } finally {
    subscription?.cancel();
  }
}

/// 流式生成
Stream<String> generateStream(dynamic inference, String prompt) {
  final llamaParent = inference as LlamaParent;
  llamaParent.sendPrompt(prompt);
  return llamaParent.stream;
}

/// 停止生成
Future<void> stopGeneration(dynamic inference) async {
  final llamaParent = inference as LlamaParent;
  await llamaParent.stop();
}

/// 释放资源
Future<void> disposeInference(dynamic inference) async {
  final llamaParent = inference as LlamaParent;
  await llamaParent.dispose();
}
