import 'package:flutter/foundation.dart';

import '../models/practice_book_model.dart';

enum ZenRecitationStatus {
  disabled,
  missingBook,
  missingModel,
  ready,
  starting,
  listening,
  stopped,
  error,
}

class ZenRecitationCounterService extends ChangeNotifier {
  ZenRecitationStatus get status => ZenRecitationStatus.disabled;
  String get statusMessage => 'Web 暂不支持离线语音识别';
  String get recognizedText => '';
  double get matchProgress => 0;
  bool get autoEnabled => false;
  bool get canUndo => false;

  void setAutoEnabled(bool value) {}
  Future<void> prepare(PracticeBook? book) async {}
  Future<void> start({
    required PracticeBook? book,
    required VoidCallback onCount,
    required VoidCallback onUndoCount,
  }) async {}
  Future<void> stop() async {}
  void undoLastAutoCount() {}
}
