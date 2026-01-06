import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 音频流服务
/// 
/// 使用 flutter_sound 捕获麦克风音频流，同时支持：
/// 1. 写入本地文件进行录音
/// 2. 流式发送到语音识别服务
/// 3. 音频播放功能
class AudioStreamService {
  static AudioStreamService? _instance;
  static AudioStreamService get instance => _instance ??= AudioStreamService._();
  
  AudioStreamService._();
  
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _recordingSubscription;
  
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  IOSink? _fileSink;
  
  /// 获取音频流（16kHz, 16-bit, mono PCM）
  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  
  /// 是否正在录音
  bool get isRecording => _isRecording;
  
  /// 当前录音文件路径
  String? get currentRecordingPath => _currentRecordingPath;
  
  /// 初始化音频服务
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // 请求麦克风权限
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('[AudioStream] 麦克风权限被拒绝');
        return false;
      }
      
      // 配置音频会话（iOS 需要）
      if (!kIsWeb && Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        ));
      }
      
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      
      // 设置采样率为 16kHz（Vosk 推荐）
      await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 100));
      
      _isInitialized = true;
      debugPrint('[AudioStream] 初始化成功');
      return true;
    } catch (e) {
      debugPrint('[AudioStream] 初始化失败: $e');
      return false;
    }
  }
  
  /// 开始录音并返回音频流
  /// 
  /// [saveToFile] 是否同时保存到文件
  Future<Stream<Uint8List>?> startRecording({bool saveToFile = true}) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return null;
    }
    
    if (_isRecording) {
      debugPrint('[AudioStream] 已经在录音中');
      return _audioStreamController?.stream;
    }
    
    try {
      _audioStreamController = StreamController<Uint8List>.broadcast();
      
      // 创建录音文件
      if (saveToFile) {
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentRecordingPath = '${directory.path}/reading_$timestamp.pcm';
        
        final file = File(_currentRecordingPath!);
        _fileSink = file.openWrite();
      }
      
      // 开始录音到流
      // 使用 16kHz, 16-bit, mono 格式（Vosk 推荐）
      await _recorder!.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );
      
      // 同时写入文件
      if (_fileSink != null) {
        _recordingSubscription = _audioStreamController!.stream.listen((data) {
          _fileSink?.add(data);
        });
      }
      
      _isRecording = true;
      debugPrint('[AudioStream] 开始录音: $_currentRecordingPath');
      return _audioStreamController!.stream;
    } catch (e) {
      debugPrint('[AudioStream] 开始录音失败: $e');
      await _cleanup();
      return null;
    }
  }
  
  /// 停止录音
  /// 
  /// 返回录音文件路径（如果有保存）
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    
    try {
      await _recorder?.stopRecorder();
      
      await _recordingSubscription?.cancel();
      _recordingSubscription = null;
      
      await _fileSink?.flush();
      await _fileSink?.close();
      _fileSink = null;
      
      await _audioStreamController?.close();
      _audioStreamController = null;
      
      _isRecording = false;
      
      final path = _currentRecordingPath;
      debugPrint('[AudioStream] 录音完成: $path');
      
      // 如果需要，可以将 PCM 转换为其他格式（如 WAV）
      // 这里暂时返回 PCM 文件
      return path;
    } catch (e) {
      debugPrint('[AudioStream] 停止录音失败: $e');
      await _cleanup();
      return null;
    }
  }

  /// 播放音频
  Future<void> playAudio(String path) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      await stopPlayer(); // 停止当前可能正在播放的音频
      
      // 检查文件是否存在
      if (!File(path).existsSync()) {
        // 如果不是本地文件，尝试作为 URL 播放
        if (path.startsWith('http')) {
          await _player!.startPlayer(
            fromURI: path,
            codec: Codec.mp3, // 假设网络音频是 MP3，或者根据后缀判断
            whenFinished: () {
              debugPrint('[AudioStream] 播放完成');
            },
          );
          return;
        }
        debugPrint('[AudioStream] 音频文件不存在: $path');
        return;
      }

      await _player!.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS, // 默认假设是 m4a/aac，如果不是可能需要根据后缀判断
        whenFinished: () {
          debugPrint('[AudioStream] 播放完成');
        },
      );
    } catch (e) {
      debugPrint('[AudioStream] 播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stopPlayer() async {
    try {
      if (_player != null && _player!.isPlaying) {
        await _player!.stopPlayer();
      }
    } catch (e) {
      debugPrint('[AudioStream] 停止播放失败: $e');
    }
  }
  
  /// 清理资源
  Future<void> _cleanup() async {
    _isRecording = false;
    
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    
    await _fileSink?.close();
    _fileSink = null;
    
    await _audioStreamController?.close();
    _audioStreamController = null;
  }
  
  /// 释放服务
  Future<void> dispose() async {
    await _cleanup();
    await stopPlayer();
    
    await _recorder?.closeRecorder();
    _recorder = null;
    
    await _player?.closePlayer();
    _player = null;
    
    _isInitialized = false;
  }
}
