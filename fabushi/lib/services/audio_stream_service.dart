import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// 平台特定导入
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;

// 条件编译：移动端使用 flutter_sound，桌面端使用 just_audio
import 'audio_stream_service_mobile.dart'
    if (dart.library.html) 'audio_stream_service_stub.dart'
    as platform;

/// 音频流服务
/// 
/// 跨平台音频录制和播放服务：
/// - iOS/Android: 使用 flutter_sound
/// - macOS/Windows/Linux: 使用 record 包或禁用录音
class AudioStreamService {
  static AudioStreamService? _instance;
  static AudioStreamService get instance => _instance ??= AudioStreamService._();
  
  AudioStreamService._();
  
  // just_audio 播放器 (所有平台)
  ja.AudioPlayer? _justAudioPlayer;
  
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _recordingSubscription;
  
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  IOSink? _fileSink;
  
  /// 平台特定的录音器
  dynamic _platformRecorder;
  
  /// 是否是移动平台（支持完整功能）
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  /// 是否是 macOS 平台
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  
  /// 是否是 Windows 平台
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  
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
      
      // 初始化 just_audio 播放器（所有平台）
      _justAudioPlayer = ja.AudioPlayer();
      
      if (_isMobile) {
        // iOS/Android: 配置音频会话
        if (Platform.isIOS) {
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
            avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          ));
        }
        
        // 初始化平台特定的录音器
        _platformRecorder = await platform.initializeRecorder();
        debugPrint('[AudioStream] 移动端模式初始化成功');
      } else if (_isMacOS) {
        // macOS: 使用 record 包
        _platformRecorder = await platform.initializeRecorder();
        debugPrint('[AudioStream] macOS 模式初始化成功');
      } else {
        // Windows/Linux: 仅支持播放，不支持录音
        debugPrint('[AudioStream] 桌面端模式初始化成功（仅播放）');
      }
      
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
    
    // Windows 不支持录音
    if (_isWindows) {
      debugPrint('[AudioStream] Windows 平台不支持录音');
      return null;
    }
    
    if (_isRecording) {
      debugPrint('[AudioStream] 已经在录音中');
      return _audioStreamController?.stream;
    }
    
    try {
      _audioStreamController = StreamController<Uint8List>.broadcast();
      
      // 创建录音文件路径
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      if (_isMacOS) {
        // macOS: 使用 record 包
        _currentRecordingPath = '${directory.path}/reading_$timestamp.wav';
      } else {
        // iOS/Android: 使用 flutter_sound
        _currentRecordingPath = '${directory.path}/reading_$timestamp.pcm';
      }
      
      if (saveToFile) {
        final file = File(_currentRecordingPath!);
        _fileSink = file.openWrite();
      }
      
      // 使用平台特定的录音方法
      _recordingSubscription = await platform.startRecording(
        _platformRecorder,
        _currentRecordingPath!,
        _audioStreamController!,
        _fileSink,
      );
      
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
      await platform.stopRecording(_platformRecorder);
      
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
      
      // 使用 just_audio 播放（所有平台）
      if (path.startsWith('http')) {
        await _justAudioPlayer!.setUrl(path);
      } else {
        await _justAudioPlayer!.setFilePath(path);
      }
      await _justAudioPlayer!.play();
    } catch (e) {
      debugPrint('[AudioStream] 播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stopPlayer() async {
    try {
      await _justAudioPlayer?.stop();
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
    
    if (_platformRecorder != null) {
      await platform.disposeRecorder(_platformRecorder);
      _platformRecorder = null;
    }
    
    await _justAudioPlayer?.dispose();
    _justAudioPlayer = null;
    
    _isInitialized = false;
  }
}
