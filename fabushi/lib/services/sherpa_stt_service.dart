import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 语音识别服务
/// 
/// 跨平台语音识别：
/// - iOS/Android: 使用 Sherpa-ONNX（需要原生代码支持）
/// - macOS: 使用原生 Speech 框架
/// - Windows: 不支持
class SherpaSTTService {
  static SherpaSTTService? _instance;
  static SherpaSTTService get instance => _instance ??= SherpaSTTService._();
  
  SherpaSTTService._();
  
  static const _macOSChannel = MethodChannel('com.fabushi.app/speech');
  
  bool _isInitialized = false;
  bool _isRecognizing = false;
  String? _modelDir;
  
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  
  String _lastCallbackText = '';
  
  void Function(String text, bool isFinal)? onResult;
  void Function(String error)? onError;
  void Function(String message)? onProgress;
  
  bool get isInitialized => _isInitialized;
  bool get isRecognizing => _isRecognizing;
  
  /// 初始化语音识别引擎
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    if (_isWindows) {
      debugPrint('[SherpaSTT] Windows 平台不支持语音识别');
      onError?.call('Windows 平台暂不支持语音识别');
      return false;
    }
    
    try {
      if (_isMacOS) {
        return await _initializeMacOS();
      } else if (_isMobile) {
        return await _initializeMobile();
      } else {
        debugPrint('[SherpaSTT] 当前平台不支持语音识别');
        return false;
      }
    } catch (e) {
      debugPrint('[SherpaSTT] 初始化失败: $e');
      onError?.call('语音识别初始化失败: $e');
      return false;
    }
  }
  
  Future<bool> _initializeMacOS() async {
    try {
      onProgress?.call('正在初始化 macOS 语音识别...');
      
      _macOSChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onResult':
            final text = call.arguments['text'] as String;
            final isFinal = call.arguments['isFinal'] as bool;
            if (text.isNotEmpty && text != _lastCallbackText) {
              _lastCallbackText = text;
              onResult?.call(text, isFinal);
              if (isFinal) _lastCallbackText = '';
            }
            break;
          case 'onError':
            final error = call.arguments as String;
            onError?.call(error);
            break;
        }
      });
      
      final result = await _macOSChannel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      
      if (_isInitialized) {
        debugPrint('[SherpaSTT] macOS Speech 框架初始化成功');
      }
      
      return _isInitialized;
    } catch (e) {
      debugPrint('[SherpaSTT] macOS 初始化失败: $e');
      _isInitialized = false;
      onError?.call('macOS 语音识别暂不可用: $e');
      return false;
    }
  }
  
  Future<bool> _initializeMobile() async {
    try {
      onProgress?.call('正在准备语音识别引擎...');
      
      // 移动端的 Sherpa-ONNX 初始化需要原生代码支持
      // 这里只做状态管理
      _modelDir = await _prepareModel();
      if (_modelDir == null) {
        onError?.call('无法加载语音识别模型');
        return false;
      }
      
      _isInitialized = true;
      debugPrint('[SherpaSTT] 移动端语音识别已就绪（需要原生代码）');
      return true;
    } catch (e) {
      debugPrint('[SherpaSTT] 移动端初始化失败: $e');
      onError?.call('移动端语音识别初始化失败: $e');
      return false;
    }
  }
  
  Future<String?> _prepareModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/sherpa-onnx-models/streaming-paraformer-zh-en');
      
      if (await modelDir.exists()) {
        final encoderFile = File('${modelDir.path}/encoder.int8.onnx');
        if (await encoderFile.exists()) {
          final fileSize = await encoderFile.length();
          if (fileSize > 1024 * 1024) {
            return modelDir.path;
          }
        }
      }
      
      // 模型需要从 assets 复制
      onProgress?.call('首次使用，正在解压内置语音模型...');
      await modelDir.create(recursive: true);
      return await _copyAssetsToLocal(modelDir.path);
    } catch (e) {
      debugPrint('[SherpaSTT] 准备模型失败: $e');
      return null;
    }
  }

  Future<String?> _copyAssetsToLocal(String modelDir) async {
    try {
      const assetPrefix = 'assets/sherpa_models/streaming-paraformer-zh-en';
      final files = ['encoder.int8.onnx', 'decoder.int8.onnx', 'tokens.txt'];

      for (final fileName in files) {
        final byteData = await rootBundle.load('$assetPrefix/$fileName');
        final file = File('$modelDir/$fileName');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
        );
      }
      
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
      try {
        await _macOSChannel.invokeMethod('startRecognizing');
        _isRecognizing = true;
        _lastCallbackText = '';
      } catch (e) {
        debugPrint('[SherpaSTT] macOS 开始识别失败: $e');
        onError?.call('macOS 语音识别启动失败');
      }
    } else if (_isMobile) {
      // 移动端需要原生代码支持
      _isRecognizing = true;
      _lastCallbackText = '';
      debugPrint('[SherpaSTT] 移动端开始识别（需要原生代码）');
    }
  }
  
  /// 处理音频数据
  void processAudio(Uint8List audioData) {
    if (!_isRecognizing) return;
    
    if (_isMacOS) {
      _macOSChannel.invokeMethod('processAudio', audioData);
    }
    // 移动端需要原生代码处理
  }
  
  /// 停止识别
  Future<String> stopRecognizing() async {
    _isRecognizing = false;
    
    if (_isMacOS) {
      try {
        final result = await _macOSChannel.invokeMethod<String>('stopRecognizing');
        return result ?? '';
      } catch (e) {
        debugPrint('[SherpaSTT] macOS 停止识别失败: $e');
        return '';
      }
    }
    
    return '';
  }
  
  /// 重置识别器
  void reset() {
    if (_isMacOS) {
      _macOSChannel.invokeMethod('reset');
    }
    _lastCallbackText = '';
  }
  
  /// 释放资源
  void dispose() {
    _isRecognizing = false;
    _isInitialized = false;
    
    if (_isMacOS) {
      _macOSChannel.invokeMethod('dispose');
    }
  }
}
