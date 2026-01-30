import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// 条件导入：仅在非 macOS 平台使用 sherpa_onnx
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 语音识别服务
/// 
/// 跨平台语音识别：
/// - iOS/Android: 使用 Sherpa-ONNX 离线识别
/// - macOS: 使用原生 Speech 框架（通过 MethodChannel）
class SherpaSTTService {
  static SherpaSTTService? _instance;
  static SherpaSTTService get instance => _instance ??= SherpaSTTService._();
  
  SherpaSTTService._();
  
  // Sherpa-ONNX (iOS/Android)
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  
  // macOS Speech Framework (通过 MethodChannel)
  static const _macOSChannel = MethodChannel('com.fabushi.app/speech');
  
  bool _isInitialized = false;
  static bool _bindingsInitialized = false;
  bool _isRecognizing = false;
  String? _modelDir;
  
  /// 是否是 macOS 平台
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  
  /// 上次回调的文本（用于去重）
  String _lastCallbackText = '';
  
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
  
  /// 初始化语音识别引擎
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      if (_isMacOS) {
        // macOS: 使用原生 Speech 框架
        return await _initializeMacOS();
      } else {
        // iOS/Android: 使用 Sherpa-ONNX
        return await _initializeSherpa();
      }
    } catch (e) {
      debugPrint('[SherpaSTT] 初始化失败: $e');
      onError?.call('语音识别初始化失败: $e');
      return false;
    }
  }
  
  /// macOS 初始化
  Future<bool> _initializeMacOS() async {
    try {
      onProgress?.call('正在初始化 macOS 语音识别...');
      
      // 设置回调监听
      _macOSChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onResult':
            final text = call.arguments['text'] as String;
            final isFinal = call.arguments['isFinal'] as bool;
            if (text.isNotEmpty && text != _lastCallbackText) {
              _lastCallbackText = text;
              onResult?.call(text, isFinal);
              if (isFinal) {
                _lastCallbackText = '';
              }
            }
            break;
          case 'onError':
            final error = call.arguments as String;
            onError?.call(error);
            break;
        }
      });
      
      // 请求语音识别权限
      final result = await _macOSChannel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      
      if (_isInitialized) {
        debugPrint('[SherpaSTT] macOS Speech 框架初始化成功');
      } else {
        debugPrint('[SherpaSTT] macOS Speech 框架初始化失败');
        onError?.call('macOS 语音识别不可用');
      }
      
      return _isInitialized;
    } catch (e) {
      debugPrint('[SherpaSTT] macOS 初始化失败: $e');
      // macOS 上如果原生代码未实现，降级为禁用状态
      _isInitialized = false;
      onError?.call('macOS 语音识别暂不可用: $e');
      return false;
    }
  }
  
  /// Sherpa-ONNX 初始化 (iOS/Android)
  Future<bool> _initializeSherpa() async {
    try {
      // 首先初始化 sherpa-onnx FFI 绑定
      if (!_bindingsInitialized) {
        debugPrint('[SherpaSTT] 初始化 FFI 绑定...');
        sherpa.initBindings();
        _bindingsInitialized = true;
        debugPrint('[SherpaSTT] FFI 绑定初始化成功');
      }
      
      onProgress?.call('正在准备语音识别引擎...');
      
      // 获取模型目录
      _modelDir = await _prepareModel();
      if (_modelDir == null) {
        onError?.call('无法加载语音识别模型');
        return false;
      }
      
      onProgress?.call('正在初始化识别器...');
      
      // 创建在线识别器配置
      final config = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          paraformer: sherpa.OnlineParaformerModelConfig(
            encoder: '$_modelDir/encoder.int8.onnx',
            decoder: '$_modelDir/decoder.int8.onnx',
          ),
          tokens: '$_modelDir/tokens.txt',
          modelType: 'paraformer',
        ),
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 20,
      );
      
      _recognizer = sherpa.OnlineRecognizer(config);
      
      _isInitialized = true;
      debugPrint('[SherpaSTT] Sherpa-ONNX 初始化成功');
      return true;
    } catch (e) {
      debugPrint('[SherpaSTT] Sherpa-ONNX 初始化失败: $e');
      onError?.call('Sherpa-ONNX 初始化失败: $e');
      return false;
    }
  }
  
  /// 准备模型文件
  Future<String?> _prepareModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/sherpa-onnx-models/streaming-paraformer-zh-en');
      
      // 检查模型是否已存在且完整
      if (await modelDir.exists()) {
        final encoderFile = File('${modelDir.path}/encoder.int8.onnx');
        if (await encoderFile.exists()) {
          final fileSize = await encoderFile.length();
          if (fileSize > 1024 * 1024) {
            debugPrint('[SherpaSTT] 使用已存在的模型: ${modelDir.path}');
            return modelDir.path;
          } else {
            debugPrint('[SherpaSTT] 检测到损坏的模型缓存，正在删除...');
            await modelDir.delete(recursive: true);
          }
        }
      }
      
      // 模型不存在，从 assets 复制
      onProgress?.call('首次使用，正在解压内置语音模型...');
      await modelDir.create(recursive: true);
      
      return await _copyAssetsToLocal(modelDir.path);
    } catch (e) {
      debugPrint('[SherpaSTT] 准备模型失败: $e');
      return null;
    }
  }

  /// 从 Assets 复制模型到本地
  Future<String?> _copyAssetsToLocal(String modelDir) async {
    try {
      const assetPrefix = 'assets/sherpa_models/streaming-paraformer-zh-en';
      final files = ['encoder.int8.onnx', 'decoder.int8.onnx', 'tokens.txt'];

      for (int i = 0; i < files.length; i++) {
        final fileName = files[i];
        debugPrint('[SherpaSTT] 复制 $fileName...');
        
        final byteData = await rootBundle.load('$assetPrefix/$fileName');
        final file = File('$modelDir/$fileName');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
        );
      }
      
      debugPrint('[SherpaSTT] 模型复制完成: $modelDir');
      return modelDir;
    } catch (e) {
      debugPrint('[SherpaSTT] 复制模型失败: $e');
      return null;
    }
  }
  
  /// 开始识别
  Future<void> startRecognizing() async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }
    
    if (_isMacOS) {
      // macOS: 通过 MethodChannel 启动识别
      try {
        await _macOSChannel.invokeMethod('startRecognizing');
        _isRecognizing = true;
        _lastCallbackText = '';
        debugPrint('[SherpaSTT] macOS 开始识别');
      } catch (e) {
        debugPrint('[SherpaSTT] macOS 开始识别失败: $e');
        onError?.call('macOS 语音识别启动失败');
      }
    } else {
      // iOS/Android: 使用 Sherpa-ONNX
      _stream = _recognizer!.createStream();
      _isRecognizing = true;
      _lastCallbackText = '';
      debugPrint('[SherpaSTT] Sherpa-ONNX 开始识别');
    }
  }
  
  /// 处理音频数据
  /// 
  /// [audioData] 16kHz, 16-bit, mono PCM 数据
  void processAudio(Uint8List audioData) {
    if (!_isRecognizing) return;
    
    if (_isMacOS) {
      // macOS: 通过 MethodChannel 发送音频数据
      _macOSChannel.invokeMethod('processAudio', audioData);
    } else {
      // iOS/Android: 使用 Sherpa-ONNX
      _processAudioSherpa(audioData);
    }
  }
  
  /// Sherpa-ONNX 处理音频
  void _processAudioSherpa(Uint8List audioData) {
    if (_stream == null || _recognizer == null) return;
    
    try {
      final samples = _convertToFloat32(audioData);
      if (samples.isEmpty) return;
      
      _stream!.acceptWaveform(samples: samples, sampleRate: 16000);
      
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }
      
      final result = _recognizer!.getResult(_stream!);
      final text = result.text.trim();
      
      if (text.isNotEmpty && text != _lastCallbackText) {
        _lastCallbackText = text;
        final isEndpoint = _recognizer!.isEndpoint(_stream!);
        onResult?.call(text, isEndpoint);
        
        if (isEndpoint) {
          _recognizer!.reset(_stream!);
          _lastCallbackText = '';
        }
      }
    } catch (e) {
      debugPrint('[SherpaSTT] 音频处理错误: $e');
    }
  }
  
  /// 将 16-bit PCM 转换为 Float32
  Float32List _convertToFloat32(Uint8List pcm16) {
    final length = pcm16.length;
    if (length < 2) return Float32List(0);
    
    final sampleCount = length ~/ 2;
    final float32Data = Float32List(sampleCount);
    
    for (int i = 0; i < sampleCount; i++) {
      final byteIndex = i * 2;
      final low = pcm16[byteIndex];
      final high = pcm16[byteIndex + 1];
      
      int sample = (high << 8) | low;
      if (sample >= 32768) sample -= 65536;
      
      float32Data[i] = sample / 32768.0;
    }
    
    return float32Data;
  }
  
  /// 停止识别
  Future<String> stopRecognizing() async {
    _isRecognizing = false;
    
    if (_isMacOS) {
      // macOS: 通过 MethodChannel 停止识别
      try {
        final result = await _macOSChannel.invokeMethod<String>('stopRecognizing');
        debugPrint('[SherpaSTT] macOS 停止识别，结果: $result');
        return result ?? '';
      } catch (e) {
        debugPrint('[SherpaSTT] macOS 停止识别失败: $e');
        return '';
      }
    } else {
      // iOS/Android: 使用 Sherpa-ONNX
      return _stopRecognizingSherpa();
    }
  }
  
  /// Sherpa-ONNX 停止识别
  Future<String> _stopRecognizingSherpa() async {
    if (_stream == null || _recognizer == null) return '';
    
    try {
      _stream!.inputFinished();
      
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }
      
      final result = _recognizer!.getResult(_stream!);
      final text = result.text.trim();
      
      _stream!.free();
      _stream = null;
      
      debugPrint('[SherpaSTT] Sherpa-ONNX 停止识别，结果: $text');
      return text;
    } catch (e) {
      debugPrint('[SherpaSTT] 停止识别错误: $e');
      return '';
    }
  }
  
  /// 重置识别器
  void reset() {
    if (_isMacOS) {
      _macOSChannel.invokeMethod('reset');
    } else if (_stream != null && _recognizer != null) {
      _recognizer!.reset(_stream!);
    }
    _lastCallbackText = '';
  }
  
  /// 释放资源
  void dispose() {
    _isRecognizing = false;
    _isInitialized = false;
    
    if (_isMacOS) {
      _macOSChannel.invokeMethod('dispose');
    } else {
      _stream?.free();
      _stream = null;
      _recognizer?.free();
      _recognizer = null;
    }
  }
}
