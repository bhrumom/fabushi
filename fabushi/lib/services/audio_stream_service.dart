import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// 平台特定导入
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;

// 条件编译：移动端使用 flutter_sound，macOS 使用 record
import 'package:flutter_sound/flutter_sound.dart';
import 'package:record/record.dart';

/// 音频流服务
///
/// 跨平台音频录制和播放服务：
/// - iOS/Android: 使用 flutter_sound
/// - macOS: 使用 record 包
class AudioStreamService {
  static AudioStreamService? _instance;
  static AudioStreamService get instance =>
      _instance ??= AudioStreamService._();

  AudioStreamService._();

  // flutter_sound (iOS/Android)
  FlutterSoundRecorder? _flutterSoundRecorder;
  FlutterSoundPlayer? _flutterSoundPlayer;

  // record 包 (macOS)
  AudioRecorder? _audioRecorder;

  // just_audio 播放器 (macOS)
  ja.AudioPlayer? _justAudioPlayer;

  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _recordingSubscription;

  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  IOSink? _fileSink;

  /// 是否是 macOS 平台
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;

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

      if (_isMacOS) {
        // macOS: 使用 record 包
        _audioRecorder = AudioRecorder();
        _justAudioPlayer = ja.AudioPlayer();
        debugPrint('[AudioStream] macOS 模式初始化成功');
      } else {
        // iOS/Android: 使用 flutter_sound
        // 配置音频会话（iOS 需要）
        if (!kIsWeb && Platform.isIOS) {
          final session = await AudioSession.instance;
          await session.configure(
            const AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
              avAudioSessionCategoryOptions:
                  AVAudioSessionCategoryOptions.defaultToSpeaker,
              avAudioSessionMode: AVAudioSessionMode.spokenAudio,
            ),
          );
        }

        _flutterSoundRecorder = FlutterSoundRecorder();
        await _flutterSoundRecorder!.openRecorder();

        _flutterSoundPlayer = FlutterSoundPlayer();
        await _flutterSoundPlayer!.openPlayer();

        // 设置采样率为 16kHz
        await _flutterSoundRecorder!.setSubscriptionDuration(
          const Duration(milliseconds: 100),
        );

        debugPrint('[AudioStream] 移动端模式初始化成功');
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
        // macOS: 使用 record 包，直接录制到文件
        _currentRecordingPath = '${directory.path}/reading_$timestamp.wav';

        // record 包的配置
        final config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        );

        // 开始录音
        final stream = await _audioRecorder!.startStream(config);

        // 打开文件写入
        if (saveToFile) {
          final file = File(_currentRecordingPath!);
          _fileSink = file.openWrite();
        }

        // 监听音频流
        _recordingSubscription = stream.listen(
          (data) {
            // 将数据添加到流中
            if (!_audioStreamController!.isClosed) {
              _audioStreamController!.add(Uint8List.fromList(data));
            }
            // 同时写入文件
            _fileSink?.add(data);
          },
          onError: (e) {
            debugPrint('[AudioStream] macOS 录音流错误: $e');
          },
        );
      } else {
        // iOS/Android: 使用 flutter_sound
        if (saveToFile) {
          _currentRecordingPath = '${directory.path}/reading_$timestamp.pcm';
          final file = File(_currentRecordingPath!);
          _fileSink = file.openWrite();
        }

        // 开始录音到流
        await _flutterSoundRecorder!.startRecorder(
          toStream: _audioStreamController!.sink,
          codec: Codec.pcm16,
          numChannels: 1,
          sampleRate: 16000,
        );

        // 同时写入文件
        if (_fileSink != null) {
          _recordingSubscription = _audioStreamController!.stream.listen((
            data,
          ) {
            _fileSink?.add(data);
          });
        }
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
      if (_isMacOS) {
        // macOS: 停止 record 包录音
        await _audioRecorder?.stop();
      } else {
        // iOS/Android: 停止 flutter_sound 录音
        await _flutterSoundRecorder?.stopRecorder();
      }

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

      if (_isMacOS) {
        // macOS: 使用 just_audio 播放
        if (path.startsWith('http')) {
          await _justAudioPlayer!.setUrl(path);
        } else {
          await _justAudioPlayer!.setFilePath(path);
        }
        await _justAudioPlayer!.play();
      } else {
        // iOS/Android: 使用 flutter_sound
        // 检查文件是否存在
        if (!File(path).existsSync()) {
          if (path.startsWith('http')) {
            await _flutterSoundPlayer!.startPlayer(
              fromURI: path,
              codec: Codec.mp3,
              whenFinished: () {
                debugPrint('[AudioStream] 播放完成');
              },
            );
            return;
          }
          debugPrint('[AudioStream] 音频文件不存在: $path');
          return;
        }

        await _flutterSoundPlayer!.startPlayer(
          fromURI: path,
          codec: Codec.aacADTS,
          whenFinished: () {
            debugPrint('[AudioStream] 播放完成');
          },
        );
      }
    } catch (e) {
      debugPrint('[AudioStream] 播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stopPlayer() async {
    try {
      if (_isMacOS) {
        await _justAudioPlayer?.stop();
      } else {
        if (_flutterSoundPlayer != null && _flutterSoundPlayer!.isPlaying) {
          await _flutterSoundPlayer!.stopPlayer();
        }
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

    if (_isMacOS) {
      await _audioRecorder?.dispose();
      _audioRecorder = null;
      await _justAudioPlayer?.dispose();
      _justAudioPlayer = null;
    } else {
      await _flutterSoundRecorder?.closeRecorder();
      _flutterSoundRecorder = null;
      await _flutterSoundPlayer?.closePlayer();
      _flutterSoundPlayer = null;
    }

    _isInitialized = false;
  }
}
