import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Sherpa-ONNX 离线语音识别服务
/// 
/// 使用 Sherpa-ONNX 开源引擎进行本地语音识别，支持中文流式识别
class SherpaSTTService {
  static SherpaSTTService? _instance;
  static SherpaSTTService get instance => _instance ??= SherpaSTTService._();
  
  SherpaSTTService._();
  
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  
  bool _isInitialized = false;
  bool _isRecognizing = false;
  String? _modelDir;
  
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
  
  /// 初始化 Sherpa-ONNX 引擎
  /// 
  /// 首次使用时会下载中文模型（约100MB）
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      onProgress?.call('正在准备语音识别引擎...');
      
      // 获取模型目录
      _modelDir = await _prepareModel();
      if (_modelDir == null) {
        onError?.call('无法加载语音识别模型');
        return false;
      }
      
      onProgress?.call('正在初始化识别器...');
      
      // 创建在线识别器配置
      // 使用 Paraformer 中英双语流式模型
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
      debugPrint('[SherpaSTT] 初始化成功');
      return true;
    } catch (e) {
      debugPrint('[SherpaSTT] 初始化失败: $e');
      onError?.call('Sherpa-ONNX 初始化失败: $e');
      return false;
    }
  }
  
  /// 准备模型文件
  /// 
  /// 下载并解压中文模型到应用目录
  Future<String?> _prepareModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/sherpa-onnx-models/streaming-paraformer-zh-en');
      
      // 检查模型是否已存在
      if (await modelDir.exists()) {
        final encoderFile = File('${modelDir.path}/encoder.int8.onnx');
        if (await encoderFile.exists()) {
          debugPrint('[SherpaSTT] 使用已下载的模型: ${modelDir.path}');
          return modelDir.path;
        }
      }
      
      // 模型不存在，需要下载
      onProgress?.call('首次使用，正在下载中文语音模型...\n（约100MB，请稍候）');
      
      // 创建模型目录
      await modelDir.create(recursive: true);
      
      // 下载模型文件
      // 使用 sherpa-onnx 官方提供的中英双语流式 Paraformer 模型
      const modelUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2';
      
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(modelUrl));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        debugPrint('[SherpaSTT] 模型下载失败: HTTP ${response.statusCode}');
        return null;
      }
      
      // 保存到临时文件
      final tempFile = File('${appDir.path}/model.tar.bz2');
      final sink = tempFile.openWrite();
      await response.pipe(sink);
      await sink.close();
      
      onProgress?.call('正在解压模型...');
      
      // 解压模型
      // 注意：Flutter 没有内置的 tar.bz2 解压，需要使用平台特定方法
      // 这里我们先使用简化方案：直接下载预解压的模型
      
      // 删除临时文件
      await tempFile.delete();
      
      // 由于解压 tar.bz2 比较复杂，我们改用预解压的模型 URL
      return await _downloadPreExtractedModel(modelDir.path);
      
    } catch (e) {
      debugPrint('[SherpaSTT] 准备模型失败: $e');
      return null;
    }
  }
  
  /// 下载预解压的模型文件
  Future<String?> _downloadPreExtractedModel(String modelDir) async {
    try {
      // 使用 GitHub 直接下载各个模型文件
      const baseUrl = 'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-paraformer-bilingual-zh-en/resolve/main';
      
      final files = [
        'encoder.int8.onnx',
        'decoder.int8.onnx', 
        'tokens.txt',
      ];
      
      final httpClient = HttpClient();
      
      for (int i = 0; i < files.length; i++) {
        final fileName = files[i];
        onProgress?.call('正在下载模型文件 (${i + 1}/${files.length})...\n$fileName');
        
        final request = await httpClient.getUrl(Uri.parse('$baseUrl/$fileName'));
        final response = await request.close();
        
        if (response.statusCode != 200) {
          debugPrint('[SherpaSTT] 下载 $fileName 失败: HTTP ${response.statusCode}');
          return null;
        }
        
        final file = File('$modelDir/$fileName');
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.close();
        
        debugPrint('[SherpaSTT] 已下载: $fileName');
      }
      
      return modelDir;
    } catch (e) {
      debugPrint('[SherpaSTT] 下载预解压模型失败: $e');
      return null;
    }
  }
  
  /// 开始识别
  Future<void> startRecognizing() async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }
    
    _stream = _recognizer!.createStream();
    _isRecognizing = true;
    debugPrint('[SherpaSTT] 开始识别');
  }
  
  /// 处理音频数据
  /// 
  /// [audioData] 16kHz, 16-bit, mono PCM 数据
  void processAudio(Uint8List audioData) {
    if (!_isRecognizing || _stream == null || _recognizer == null) return;
    
    try {
      // 将 16-bit PCM 转换为 Float32 样本
      final samples = _convertToFloat32(audioData);
      
      // 发送到识别器
      _stream!.acceptWaveform(samples: samples, sampleRate: 16000);
      
      // 检查是否有结果
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }
      
      // 获取识别结果
      final result = _recognizer!.getResult(_stream!);
      final text = result.text.trim();
      
      if (text.isNotEmpty) {
        // 检查是否是端点（句子结束）
        final isEndpoint = _recognizer!.isEndpoint(_stream!);
        onResult?.call(text, isEndpoint);
        
        if (isEndpoint) {
          _recognizer!.reset(_stream!);
        }
      }
    } catch (e) {
      debugPrint('[SherpaSTT] 音频处理错误: $e');
    }
  }
  
  /// 将 16-bit PCM 转换为 Float32
  Float32List _convertToFloat32(Uint8List pcm16) {
    final int16Data = Int16List.view(pcm16.buffer);
    final float32Data = Float32List(int16Data.length);
    
    for (int i = 0; i < int16Data.length; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    
    return float32Data;
  }
  
  /// 停止识别
  Future<String> stopRecognizing() async {
    _isRecognizing = false;
    
    if (_stream == null || _recognizer == null) return '';
    
    try {
      // 输入空数据以刷新缓冲区
      _stream!.inputFinished();
      
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }
      
      final result = _recognizer!.getResult(_stream!);
      final text = result.text.trim();
      
      _stream!.free();
      _stream = null;
      
      debugPrint('[SherpaSTT] 停止识别，最终结果: $text');
      return text;
    } catch (e) {
      debugPrint('[SherpaSTT] 停止识别错误: $e');
      return '';
    }
  }
  
  /// 重置识别器（准备下一句）
  void reset() {
    if (_stream != null && _recognizer != null) {
      _recognizer!.reset(_stream!);
    }
  }
  
  /// 释放资源
  void dispose() {
    _isRecognizing = false;
    _isInitialized = false;
    
    _stream?.free();
    _stream = null;
    
    _recognizer?.free();
    _recognizer = null;
  }
}
