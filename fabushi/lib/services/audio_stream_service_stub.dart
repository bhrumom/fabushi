import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Stub implementation for platforms that don't support audio recording (Windows, Linux, Web)

Future<dynamic> initializeRecorder() async {
  return null;
}

Future<StreamSubscription?> startRecording(
  dynamic recorder,
  String filePath,
  StreamController<Uint8List> streamController,
  IOSink? fileSink,
) async {
  debugPrint('[AudioStream] 录音功能在当前平台不支持');
  return null;
}

Future<void> stopRecording(dynamic recorder) async {
  // No-op
}

Future<void> disposeRecorder(dynamic recorder) async {
  // No-op
}
