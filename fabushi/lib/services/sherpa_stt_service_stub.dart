import 'dart:typed_data';

/// Stub implementation for platforms that don't support sherpa_onnx (Windows, Linux, Web)

void initSherpaBindings() {
  // No-op
}

dynamic createRecognizer(String modelDir) {
  return null;
}

dynamic createStream(dynamic recognizer) {
  return null;
}

void processAudio(dynamic recognizer, dynamic stream, Float32List samples, void Function(String text, bool isEndpoint) callback) {
  // No-op
}

void reset(dynamic recognizer, dynamic stream) {
  // No-op
}

String stopRecognizing(dynamic recognizer, dynamic stream) {
  return '';
}

void freeStream(dynamic stream) {
  // No-op
}

void freeRecognizer(dynamic recognizer) {
  // No-op
}
