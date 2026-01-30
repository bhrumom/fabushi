import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

bool _bindingsInitialized = false;

/// 初始化 Sherpa-ONNX FFI 绑定
void initSherpaBindings() {
  if (!_bindingsInitialized) {
    debugPrint('[SherpaSTT] 初始化 FFI 绑定...');
    sherpa.initBindings();
    _bindingsInitialized = true;
    debugPrint('[SherpaSTT] FFI 绑定初始化成功');
  }
}

/// 创建识别器
dynamic createRecognizer(String modelDir) {
  final config = sherpa.OnlineRecognizerConfig(
    model: sherpa.OnlineModelConfig(
      paraformer: sherpa.OnlineParaformerModelConfig(
        encoder: '$modelDir/encoder.int8.onnx',
        decoder: '$modelDir/decoder.int8.onnx',
      ),
      tokens: '$modelDir/tokens.txt',
      modelType: 'paraformer',
    ),
    enableEndpoint: true,
    rule1MinTrailingSilence: 2.4,
    rule2MinTrailingSilence: 1.2,
    rule3MinUtteranceLength: 20,
  );
  
  return sherpa.OnlineRecognizer(config);
}

/// 创建识别流
dynamic createStream(dynamic recognizer) {
  return (recognizer as sherpa.OnlineRecognizer).createStream();
}

/// 处理音频数据
void processAudio(dynamic recognizer, dynamic stream, Float32List samples, void Function(String text, bool isEndpoint) callback) {
  final rec = recognizer as sherpa.OnlineRecognizer;
  final str = stream as sherpa.OnlineStream;
  
  str.acceptWaveform(samples: samples, sampleRate: 16000);
  
  while (rec.isReady(str)) {
    rec.decode(str);
  }
  
  final result = rec.getResult(str);
  final text = result.text.trim();
  
  if (text.isNotEmpty) {
    final isEndpoint = rec.isEndpoint(str);
    callback(text, isEndpoint);
  }
}

/// 重置识别流
void reset(dynamic recognizer, dynamic stream) {
  final rec = recognizer as sherpa.OnlineRecognizer;
  final str = stream as sherpa.OnlineStream;
  rec.reset(str);
}

/// 停止识别并获取最终结果
String stopRecognizing(dynamic recognizer, dynamic stream) {
  final rec = recognizer as sherpa.OnlineRecognizer;
  final str = stream as sherpa.OnlineStream;
  
  str.inputFinished();
  
  while (rec.isReady(str)) {
    rec.decode(str);
  }
  
  final result = rec.getResult(str);
  return result.text.trim();
}

/// 释放识别流
void freeStream(dynamic stream) {
  (stream as sherpa.OnlineStream).free();
}

/// 释放识别器
void freeRecognizer(dynamic recognizer) {
  (recognizer as sherpa.OnlineRecognizer).free();
}
