import 'package:flutter/foundation.dart';

/// Stub implementation for platforms that don't support flutter_tts (Windows, Linux, Web)

Future<dynamic> initializeTts() async {
  return null;
}

Future<void> setLanguage(dynamic tts, String language) async {
  // No-op
}

Future<void> setSpeechRate(dynamic tts, double rate) async {
  // No-op
}

Future<void> setVolume(dynamic tts, double volume) async {
  // No-op
}

void setProgressHandler(dynamic tts, Function(String, int, int, String) handler) {
  // No-op
}

void setCompletionHandler(dynamic tts, VoidCallback handler) {
  // No-op
}

void setErrorHandler(dynamic tts, Function(String) handler) {
  // No-op
}

Future<int> speak(dynamic tts, String text) async {
  return 0; // Failure
}

Future<void> stop(dynamic tts) async {
  // No-op
}
