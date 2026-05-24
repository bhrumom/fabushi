import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/practice_book_model.dart';
import 'audio_stream_service.dart';
import 'offline_asr_model_service.dart';
import 'recitation_progress_matcher.dart';
import 'sherpa_stt_service.dart';

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
  final AudioStreamService _audioService = AudioStreamService.instance;
  final SherpaSTTService _sttService = SherpaSTTService.instance;
  RecitationProgressMatcher? _matcher;
  StreamSubscription<Uint8List>? _audioSubscription;
  VoidCallback? _onCount;
  VoidCallback? _onUndoCount;

  ZenRecitationStatus _status = ZenRecitationStatus.stopped;
  String _statusMessage = '自动识别未启动';
  String _recognizedText = '';
  double _matchProgress = 0;
  bool _autoEnabled = true;
  int _autoCountStack = 0;

  ZenRecitationStatus get status => _status;
  String get statusMessage => _statusMessage;
  String get recognizedText => _recognizedText;
  double get matchProgress => _matchProgress;
  bool get autoEnabled => _autoEnabled;
  bool get canUndo => _autoCountStack > 0;

  void setAutoEnabled(bool value) {
    if (_autoEnabled == value) return;
    _autoEnabled = value;
    if (!value) {
      stop();
      _status = ZenRecitationStatus.disabled;
      _statusMessage = '自动识别已关闭';
    } else {
      _status = ZenRecitationStatus.stopped;
      _statusMessage = '自动识别待启动';
    }
    notifyListeners();
  }

  Future<void> prepare(PracticeBook? book) async {
    if (!_autoEnabled) {
      _status = ZenRecitationStatus.disabled;
      _statusMessage = '自动识别已关闭';
      notifyListeners();
      return;
    }
    if (book == null || book.normalizedText.isEmpty) {
      _status = ZenRecitationStatus.missingBook;
      _statusMessage = '请先添加功课本';
      notifyListeners();
      return;
    }
    final modelReady = await OfflineAsrModelService.instance.refreshStatus();
    _status = modelReady
        ? ZenRecitationStatus.ready
        : ZenRecitationStatus.missingModel;
    _statusMessage = modelReady ? '离线识别已就绪' : '请先下载离线语音模型';
    notifyListeners();
  }

  Future<void> start({
    required PracticeBook? book,
    required VoidCallback onCount,
    required VoidCallback onUndoCount,
  }) async {
    _onCount = onCount;
    _onUndoCount = onUndoCount;
    _autoCountStack = 0;
    _recognizedText = '';
    _matchProgress = 0;

    if (!_autoEnabled) {
      _status = ZenRecitationStatus.disabled;
      _statusMessage = '自动识别已关闭';
      notifyListeners();
      return;
    }
    if (book == null || book.normalizedText.isEmpty) {
      _status = ZenRecitationStatus.missingBook;
      _statusMessage = '未找到功课本，已保留手动计数';
      notifyListeners();
      return;
    }
    final modelDir = await OfflineAsrModelService.instance
        .getInstalledModelDir();
    if (modelDir == null) {
      _status = ZenRecitationStatus.missingModel;
      _statusMessage = '未安装离线语音模型，已保留手动计数';
      notifyListeners();
      return;
    }

    _status = ZenRecitationStatus.starting;
    _statusMessage = '正在预热离线识别...';
    notifyListeners();

    try {
      _matcher = RecitationProgressMatcher(book.normalizedText);
      _sttService.onResult = _handleSpeechResult;
      _sttService.onError = (error) {
        _status = ZenRecitationStatus.error;
        _statusMessage = error;
        notifyListeners();
      };
      _sttService.onProgress = (message) {
        _statusMessage = message;
        notifyListeners();
      };

      final sttReady = await _sttService.initialize();
      if (!sttReady) {
        _status = ZenRecitationStatus.missingModel;
        _statusMessage = '离线语音模型不可用，已保留手动计数';
        notifyListeners();
        return;
      }

      await _sttService.startRecognizing();
      final stream = await _audioService.startRecording(saveToFile: false);
      if (stream == null) {
        _status = ZenRecitationStatus.error;
        _statusMessage = '麦克风启动失败，已保留手动计数';
        notifyListeners();
        return;
      }

      _audioSubscription = stream.listen(_sttService.processAudio);
      _status = ZenRecitationStatus.listening;
      _statusMessage = '离线识别中';
      notifyListeners();
    } catch (e) {
      _status = ZenRecitationStatus.error;
      _statusMessage = '自动识别启动失败: $e';
      notifyListeners();
      await stop();
    }
  }

  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    if (_sttService.isRecognizing) {
      await _sttService.stopRecognizing();
    }
    if (_audioService.isRecording) {
      await _audioService.stopRecording();
    }
    if (_status == ZenRecitationStatus.listening ||
        _status == ZenRecitationStatus.starting) {
      _status = ZenRecitationStatus.stopped;
      _statusMessage = '自动识别已停止';
    }
    notifyListeners();
  }

  void undoLastAutoCount() {
    if (_autoCountStack <= 0) return;
    _autoCountStack -= 1;
    _onUndoCount?.call();
    _statusMessage = '已撤销一次自动计数';
    notifyListeners();
  }

  void _handleSpeechResult(String text, bool isFinal) {
    final matcher = _matcher;
    if (matcher == null || _status != ZenRecitationStatus.listening) return;

    _recognizedText = text;
    final event = matcher.accept(text, isEndpoint: isFinal);
    _matchProgress = event.progress;
    _statusMessage = event.hint;

    if (event.countDelta > 0) {
      for (var i = 0; i < event.countDelta; i++) {
        _onCount?.call();
        _autoCountStack += 1;
      }
    }
    notifyListeners();
  }
}
