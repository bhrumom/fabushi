import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:record/record.dart';

/// 初始化录音器（移动端使用 flutter_sound，macOS 使用 record）
Future<dynamic> initializeRecorder() async {
  if (!kIsWeb && Platform.isMacOS) {
    // macOS: 使用 record 包
    return AudioRecorder();
  } else {
    // iOS/Android: 使用 flutter_sound
    final recorder = FlutterSoundRecorder();
    await recorder.openRecorder();
    await recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    return recorder;
  }
}

/// 开始录音
Future<StreamSubscription?> startRecording(
  dynamic recorder,
  String filePath,
  StreamController<Uint8List> streamController,
  IOSink? fileSink,
) async {
  if (!kIsWeb && Platform.isMacOS) {
    // macOS: 使用 record 包
    final audioRecorder = recorder as AudioRecorder;
    
    final config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );
    
    final stream = await audioRecorder.startStream(config);
    
    return stream.listen((data) {
      if (!streamController.isClosed) {
        streamController.add(Uint8List.fromList(data));
      }
      fileSink?.add(data);
    }, onError: (e) {
      debugPrint('[AudioStream] macOS 录音流错误: $e');
    });
  } else {
    // iOS/Android: 使用 flutter_sound
    final flutterRecorder = recorder as FlutterSoundRecorder;
    
    await flutterRecorder.startRecorder(
      toStream: streamController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
    
    // 同时写入文件
    if (fileSink != null) {
      return streamController.stream.listen((data) {
        fileSink.add(data);
      });
    }
    return null;
  }
}

/// 停止录音
Future<void> stopRecording(dynamic recorder) async {
  if (!kIsWeb && Platform.isMacOS) {
    final audioRecorder = recorder as AudioRecorder;
    await audioRecorder.stop();
  } else {
    final flutterRecorder = recorder as FlutterSoundRecorder;
    await flutterRecorder.stopRecorder();
  }
}

/// 释放录音器
Future<void> disposeRecorder(dynamic recorder) async {
  if (!kIsWeb && Platform.isMacOS) {
    final audioRecorder = recorder as AudioRecorder;
    await audioRecorder.dispose();
  } else {
    final flutterRecorder = recorder as FlutterSoundRecorder;
    await flutterRecorder.closeRecorder();
  }
}
