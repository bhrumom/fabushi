import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 初始化 TTS
Future<FlutterTts> initializeTts() async {
  final tts = FlutterTts();
  await tts.awaitSpeakCompletion(true);
  return tts;
}

/// 设置语言
Future<void> setLanguage(dynamic tts, String language) async {
  await (tts as FlutterTts).setLanguage(language);
}

/// 设置语速
Future<void> setSpeechRate(dynamic tts, double rate) async {
  await (tts as FlutterTts).setSpeechRate(rate);
}

/// 设置音量
Future<void> setVolume(dynamic tts, double volume) async {
  await (tts as FlutterTts).setVolume(volume);
}

/// 设置进度回调
void setProgressHandler(dynamic tts, Function(String, int, int, String) handler) {
  (tts as FlutterTts).setProgressHandler((text, start, end, word) {
    handler(text, start, end, word);
  });
}

/// 设置完成回调
void setCompletionHandler(dynamic tts, VoidCallback handler) {
  (tts as FlutterTts).setCompletionHandler(handler);
}

/// 设置错误回调
void setErrorHandler(dynamic tts, Function(String) handler) {
  (tts as FlutterTts).setErrorHandler((msg) {
    handler(msg);
  });
}

/// 朗读文本
Future<int> speak(dynamic tts, String text) async {
  final result = await (tts as FlutterTts).speak(text);
  return result as int? ?? 1;
}

/// 停止朗读
Future<void> stop(dynamic tts) async {
  await (tts as FlutterTts).stop();
}
