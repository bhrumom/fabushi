import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;

/// 音频流服务
/// 
/// 跨平台音频录制和播放服务：
/// - iOS/Android: 录音和播放功能（需要原生代码支持）
/// - Windows/macOS/Linux: 仅播放功能
class AudioStreamService {
  static AudioStreamService? _instance;
  static AudioStreamService get instance => _instance ??= AudioStreamService._();
  
  AudioStreamService._();
  
  ja.AudioPlayer? _justAudioPlayer;
  StreamController<Uint8List>? _audioStreamController;
  
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  
  /// 是否是移动平台
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  /// 是否是 Windows 平台
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  
  /// 获取音频流
  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  
  /// 是否正在录音
  bool get isRecording => _isRecording;
  
  /// 当前录音文件路径
  String? get currentRecordingPath => _currentRecordingPath;
  
  /// 初始化音频服务
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // 请求麦克风权限（移动端需要）
      if (_isMobile) {
        final micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          debugPrint('[AudioStream] 麦克风权限被拒绝');
          return false;
        }
        
        // iOS: 配置音频会话
        if (Platform.isIOS) {
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
            avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          ));
        }
      }
      
      // 初始化 just_audio 播放器（所有平台）
      _justAudioPlayer = ja.AudioPlayer();
      
      _isInitialized = true;
      debugPrint('[AudioStream] 初始化成功');
      return true;
    } catch (e) {
      debugPrint('[AudioStream] 初始化失败: $e');
      return false;
    }
  }
  
  /// 开始录音
  Future<Stream<Uint8List>?> startRecording({bool saveToFile = true}) async {
    // Windows 不支持录音
    if (_isWindows) {
      debugPrint('[AudioStream] Windows 平台不支持录音');
      return null;
    }
    
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return null;
    }
    
    if (_isRecording) {
      return _audioStreamController?.stream;
    }
    
    // 移动端录音需要原生代码支持
    debugPrint('[AudioStream] 录音功能需要移动端原生代码支持');
    
    _audioStreamController = StreamController<Uint8List>.broadcast();
    
    if (saveToFile) {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/reading_$timestamp.pcm';
    }
    
    _isRecording = true;
    return _audioStreamController!.stream;
  }
  
  /// 停止录音
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    
    _isRecording = false;
    await _audioStreamController?.close();
    _audioStreamController = null;
    
    final path = _currentRecordingPath;
    debugPrint('[AudioStream] 录音完成: $path');
    return path;
  }

  /// 播放音频
  Future<void> playAudio(String path) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      await stopPlayer();
      
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
  
  /// 释放服务
  Future<void> dispose() async {
    _isRecording = false;
    await _audioStreamController?.close();
    _audioStreamController = null;
    await _justAudioPlayer?.dispose();
    _justAudioPlayer = null;
    _isInitialized = false;
  }
}
