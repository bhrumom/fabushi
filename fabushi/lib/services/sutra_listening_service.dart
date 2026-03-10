import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 听经服务 - 管理 TTS 经文朗读与后台播放
///
/// 使用 flutter_tts 实现经文逐句朗读。
/// 在 iOS 上，TTS 创建原生 AVAudioSession，被系统视为合法音频播放，
/// 支持后台继续播放和锁屏控制，满足 App Store Guideline 2.5.4。
class SutraListeningService extends ChangeNotifier {
  static final SutraListeningService _instance =
      SutraListeningService._internal();
  factory SutraListeningService() => _instance;
  SutraListeningService._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;

  // 播放状态
  bool _isPlaying = false;
  bool _isPaused = false;
  int _currentSentenceIndex = 0;
  List<String> _sentences = [];
  String _sutraName = '';
  double _speechRate = 0.55;

  // 公开状态
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get currentSentenceIndex => _currentSentenceIndex;
  int get totalSentences => _sentences.length;
  String get currentSentence =>
      _sentences.isNotEmpty && _currentSentenceIndex < _sentences.length
          ? _sentences[_currentSentenceIndex]
          : '';
  String get sutraName => _sutraName;
  List<String> get sentences => _sentences;
  double get speechRate => _speechRate;
  double get progress => _sentences.isEmpty
      ? 0.0
      : _currentSentenceIndex / _sentences.length;

  /// 初始化 TTS 引擎
  Future<void> initialize() async {
    if (_isInitialized) return;

    _tts = FlutterTts();
    await _tts!.setLanguage('zh-CN');

    if (!kIsWeb && Platform.isAndroid) {
      _speechRate = 0.9;
    } else {
      _speechRate = 0.55;
    }
    await _tts!.setSpeechRate(_speechRate);
    await _tts!.setVolume(1.0);
    await _tts!.awaitSpeakCompletion(true);

    // iOS 后台播放配置
    if (!kIsWeb && Platform.isIOS) {
      await _tts!.setSharedInstance(true);
      await _tts!.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    }

    _tts!.setCompletionHandler(() {
      _onSentenceComplete();
    });

    _tts!.setErrorHandler((msg) {
      debugPrint('🎧 听经TTS错误: $msg');
    });

    _isInitialized = true;
    debugPrint('🎧 听经服务已初始化');
  }

  /// 加载经文并开始播放
  Future<void> startListening({
    required String name,
    required String textContent,
  }) async {
    if (!_isInitialized) await initialize();

    // 停止当前播放
    if (_isPlaying || _isPaused) await stop();

    _sutraName = name;
    _sentences = _splitIntoSentences(textContent);
    _currentSentenceIndex = 0;

    if (_sentences.isEmpty) {
      debugPrint('🎧 经文为空，无法播放');
      return;
    }

    _isPlaying = true;
    _isPaused = false;
    notifyListeners();

    await _speakCurrentSentence();
  }

  /// 从 asset 路径加载经文
  Future<void> startListeningFromAsset({
    required String name,
    required String assetPath,
  }) async {
    try {
      final text = await rootBundle.loadString(assetPath);
      await startListening(name: name, textContent: text);
    } catch (e) {
      debugPrint('🎧 加载经文失败: $e');
    }
  }

  /// 播放/恢复
  Future<void> play() async {
    if (!_isInitialized || _sentences.isEmpty) return;

    if (_isPaused) {
      _isPaused = false;
      _isPlaying = true;
      notifyListeners();
      await _speakCurrentSentence();
    }
  }

  /// 暂停
  Future<void> pause() async {
    if (!_isPlaying) return;

    _isPaused = true;
    _isPlaying = false;
    await _tts?.stop();
    notifyListeners();
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// 下一句
  Future<void> nextSentence() async {
    if (_currentSentenceIndex < _sentences.length - 1) {
      await _tts?.stop();
      _currentSentenceIndex++;
      notifyListeners();
      if (_isPlaying) {
        await _speakCurrentSentence();
      }
    }
  }

  /// 上一句
  Future<void> previousSentence() async {
    if (_currentSentenceIndex > 0) {
      await _tts?.stop();
      _currentSentenceIndex--;
      notifyListeners();
      if (_isPlaying) {
        await _speakCurrentSentence();
      }
    }
  }

  /// 跳转到指定句
  Future<void> seekToSentence(int index) async {
    if (index >= 0 && index < _sentences.length) {
      await _tts?.stop();
      _currentSentenceIndex = index;
      notifyListeners();
      if (_isPlaying) {
        await _speakCurrentSentence();
      }
    }
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _tts?.setSpeechRate(rate);
    notifyListeners();
  }

  /// 停止播放
  Future<void> stop() async {
    _isPlaying = false;
    _isPaused = false;
    await _tts?.stop();
    notifyListeners();
  }

  // ========== 私有方法 ==========

  /// 将经文文本分割成句子
  List<String> _splitIntoSentences(String text) {
    if (text.isEmpty) return [];

    text = text.trim();
    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      if ('。！？；\n'.contains(char)) {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty && sentence.length > 1) {
          sentences.add(sentence);
        }
        buffer.clear();
      }
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty && remaining.length > 1) {
      sentences.add(remaining);
    }

    return sentences;
  }

  /// 朗读当前句
  Future<void> _speakCurrentSentence() async {
    if (!_isPlaying || _currentSentenceIndex >= _sentences.length) {
      if (_currentSentenceIndex >= _sentences.length) {
        await stop();
      }
      return;
    }

    final sentence = _sentences[_currentSentenceIndex];
    final preview = sentence.length > 20
        ? '${sentence.substring(0, 20)}...'
        : sentence;
    debugPrint(
        '🎧 朗读第 ${_currentSentenceIndex + 1}/${_sentences.length} 句: $preview');

    await _tts?.speak(sentence);
  }

  /// 单句朗读完成回调
  void _onSentenceComplete() {
    if (!_isPlaying) return;

    _currentSentenceIndex++;
    notifyListeners();

    if (_currentSentenceIndex >= _sentences.length) {
      stop();
      return;
    }

    _speakCurrentSentence();
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }
}
