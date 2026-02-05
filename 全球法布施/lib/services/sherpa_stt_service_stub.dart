// Web 平台的 stub 实现
// sherpa_onnx 不支持 Web，此文件提供空实现

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Web 平台的语音识别服务 (禁用状态)
class SherpaSTTService {
  static SherpaSTTService? _instance;
  static SherpaSTTService get instance => _instance ??= SherpaSTTService._();
  
  SherpaSTTService._();
  
  bool _isInitialized = false;
  bool _isRecognizing = false;
  
  /// 识别结果回调
  void Function(String text, bool isFinal)? onResult;
  
  /// 错误回调
  void Function(String error)? onError;
  
  /// 初始化进度回调
  void Function(String message)? onProgress;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 是否正在识别
  bool get isRecognizing => _isRecognizing;
  
  /// 初始化语音识别引擎 (Web 不支持)
  Future<bool> initialize() async {
    debugPrint('[SherpaSTT] Web 平台不支持语音识别');
    onError?.call('Web 平台暂不支持语音识别功能');
    return false;
  }
  
  /// 开始识别 (Web 不支持)
  Future<void> startRecognizing() async {
    debugPrint('[SherpaSTT] Web 平台不支持语音识别');
    onError?.call('Web 平台暂不支持语音识别功能');
  }
  
  /// 处理音频数据 (Web 不支持)
  void processAudio(Uint8List audioData) {
    // Web 平台不支持
  }
  
  /// 停止识别 (Web 不支持)
  Future<String> stopRecognizing() async {
    _isRecognizing = false;
    return '';
  }
  
  /// 重置识别器
  void reset() {
    // Web 平台不支持
  }
  
  /// 释放资源
  void dispose() {
    _isRecognizing = false;
    _isInitialized = false;
  }
}
