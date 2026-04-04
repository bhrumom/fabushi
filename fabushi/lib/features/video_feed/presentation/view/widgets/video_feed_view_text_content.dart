import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:global_dharma_sharing/services/tts_manager.dart';
import 'package:global_dharma_sharing/providers/video_feed_visibility_notifier.dart';
import 'package:global_dharma_sharing/providers/tts_mute_notifier.dart';

/// 文字视频内容组件 - MV卡拉OK风格逐字高亮
/// 
/// 第一性原理极致性能优化：
/// 1. 使用 ValueNotifier 替代 setState，精准控制重建范围
/// 2. 预构建 Widget 列表，避免每帧重新创建
/// 3. 使用 RepaintBoundary 隔离重绘区域
/// 4. 处理多字符词的逐字高亮（修复跳字问题）
/// 5. 条件编译移除生产环境日志
class VideoFeedViewTextContent extends StatefulWidget {
  const VideoFeedViewTextContent({
    required this.textContent,
    this.isVisible = false,
    this.onCurrentParagraphChanged,
    super.key,
  });

  final String textContent;
  final bool isVisible;
  final Function(String)? onCurrentParagraphChanged;

  @override
  State<VideoFeedViewTextContent> createState() => _VideoFeedViewTextContentState();
}

class _VideoFeedViewTextContentState extends State<VideoFeedViewTextContent> 
    with TickerProviderStateMixin {
  
  // 唯一标识符，用于TTS管理器识别
  late final String _ownerId;
  
  // 文本结构
  List<String> _sentences = [];
  List<String> _words = [];
  
  int _currentSentenceIndex = 0;
  
  // ========= 第一性原理优化：使用 ValueNotifier 替代 setState =========
  // 只有高亮索引变化才需要重建UI，不需要重建整个Widget树
  final ValueNotifier<int> _highlightIndex = ValueNotifier<int>(-1);
  
  // 状态
  bool _playing = false;
  bool _disposed = false;
  bool _ttsInitialized = false;
  
  // ========= 逐句播放模式 =========
  bool _useSentenceMode = true;
  bool _waitingForCompletion = false;
  
  // ========= 动画控制 =========
  AnimationController? _highlightController;
  Timer? _sentenceTimeoutTimer;
  
  // 句子完成锁定（防止重复触发）
  bool _sentenceCompleteLock = false;
  int _lastCompletedSentenceIndex = -1;
  
  // ========= 播放会话跟踪 =========
  int _playbackSessionId = 0;
  
  // ========= 句子级别ID跟踪（防止旧回调影响新句子）=========
  int _currentSentenceId = 0;
  
  // ========= 第一性原理：预测性高亮核心参数 =========
  // AnimationController始终作为主驱动，Progress回调仅做校准
  double _calibrationOffset = 0.0;  // 累计校准偏移量 (-0.15 ~ 0.15)
  int _progressCallbackCount = 0;    // 回调计数，用于稳定性判断
  
  // 时间追踪
  Stopwatch? _sentenceStopwatch;
  
  // ========= 智能同步算法参数 =========
  late double _baseMsPerChar;
  double _currentMsPerChar = 140.0;
  static const int _sentencePauseMs = 400;
  
  // 自适应学习数据
  final List<double> _historicalMsPerChar = [];
  
  // 脉冲动画
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  
  // Mac平台额外延迟
  static const int _macExtraDelayMs = 300;
  
  // TTS管理器
  final TtsManager _ttsManager = TtsManager();
  
  // 监听器引用
  VoidCallback? _muteListener;
  VoidCallback? _visibilityListener;
  
  // ========= 第一性原理优化：预构建Widget缓存 =========
  // 句子开始时构建一次，而非每帧构建
  List<Widget>? _cachedWordWidgets;


  @override
  void initState() {
    super.initState();
    _ownerId = 'text_content_${hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    _debugLog('📱 TTS TextContent: Created with ownerId=$_ownerId');
    
    _initAnimations();
    _parseContent();
    _initTts();
  }

  /// 条件编译日志：只在Debug模式输出
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupListeners();
  }

  void _setupListeners() {
    if (_muteListener == null) {
      try {
        final muteNotifier = context.read<TtsMuteNotifier>();
        _muteListener = () => _onMuteChanged(muteNotifier.isMuted);
        muteNotifier.addListener(_muteListener!);
      } catch (e) {
        _debugLog('📱 TTS: Could not setup mute listener: $e');
      }
    }
    
    if (_visibilityListener == null) {
      try {
        final visibilityNotifier = context.read<VideoFeedVisibilityNotifier>();
        _visibilityListener = () => _onPageVisibilityChanged(visibilityNotifier.isVideoFeedVisible);
        visibilityNotifier.addListener(_visibilityListener!);
      } catch (e) {
        _debugLog('📱 TTS: Could not setup visibility listener: $e');
      }
    }
  }

  void _removeListeners() {
    if (_muteListener != null) {
      try {
        context.read<TtsMuteNotifier>().removeListener(_muteListener!);
      } catch (e) {
        // context已不可用
      }
      _muteListener = null;
    }
    
    if (_visibilityListener != null) {
      try {
        context.read<VideoFeedVisibilityNotifier>().removeListener(_visibilityListener!);
      } catch (e) {
        // context已不可用
      }
      _visibilityListener = null;
    }
  }

  void _onMuteChanged(bool isMuted) {
    if (_disposed || !mounted) return;
    
    _debugLog('📱 TTS: Mute changed to ${isMuted ? "MUTED" : "UNMUTED"}');
    
    if (isMuted && _playing) {
      _stopPlayback();
    } else if (!isMuted && !_playing && widget.isVisible) {
      _tryStart();
    }
  }

  void _onPageVisibilityChanged(bool isPageVisible) {
    if (_disposed || !mounted) return;
    
    _debugLog('📱 TTS: Page visibility changed to ${isPageVisible ? "VISIBLE" : "HIDDEN"}');
    
    if (!isPageVisible && _playing) {
      _stopPlayback();
    } else if (isPageVisible && !_playing && widget.isVisible) {
      _tryStart();
    }
  }
  
  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    
    // 高亮动画控制器
    _highlightController = AnimationController(vsync: this);
    
    // 监听高亮动画进度，更新高亮索引
    _highlightController!.addListener(_onHighlightAnimationTick);
  }
  
  /// 第一性原理：预测性高亮 - 动画始终作为主驱动源
  /// 核心公式：高亮索引 = (动画进度 + 校准偏移) × 字符数
  void _onHighlightAnimationTick() {
    if (_disposed || !_playing || _words.isEmpty) return;
    
    // 预测性高亮：动画进度 + 实时校准偏移
    final rawProgress = _highlightController!.value;
    final calibratedProgress = (rawProgress + _calibrationOffset).clamp(0.0, 1.0);
    final targetIndex = (calibratedProgress * _words.length).floor().clamp(0, _words.length - 1);
    
    // 只允许前进（防止校准导致回跳）
    if (targetIndex > _highlightIndex.value) {
      _highlightIndex.value = targetIndex;
      _pulseController?.forward(from: 0);
    }
  }

  void _parseContent() {
    _sentences = [];
    
    if (widget.textContent.isEmpty) return;
    
    // 快速路径：先在主线程进行简单的初始分句，以便立即显示（优化首屏体验）
    String initialText = widget.textContent;
    bool isLargeText = initialText.length > 5000;
    
    if (isLargeText) {
      initialText = initialText.substring(0, 5000);
      _debugLog('TTS MV: Large text detected (${widget.textContent.length} chars), showing preview first');
    }
    
    // 分句
    final parts = initialText.split(RegExp(r'[，。！？、；：""‘’「」『』【】《》〈〉\n]+'));
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty && _hasActualContent(t)) _sentences.add(t);
    }
    
    _debugLog('TTS MV: Initial parsed ${_sentences.length} sentences');
    
    if (_sentences.isNotEmpty) {
      _parseWordsForSentence(0);
    }
  }
  


  /// 将文本分割成不超过指定字数的片段（复用旧逻辑）
  /// 优先在标点符号处分割，否则在指定长度处强制分割
  List<String> _splitTextForRecitation(String text, {int maxLength = 21}) {
    if (text.isEmpty) return [];
    
    // 移除空白字符
    text = text.trim();
    
    // 如果文本短于最大长度，直接返回
    if (text.length <= maxLength) {
      return [text];
    }
    
    final sentences = <String>[];
    int start = 0;
    
    while (start < text.length) {
      int end = start + maxLength;
      
      if (end >= text.length) {
        // 剩余部分不足最大长度
        sentences.add(text.substring(start).trim());
        break;
      }
      
      // 在区间内寻找最佳分割点（标点符号）
      int bestSplit = -1;
      for (int i = end; i > start; i--) {
        final char = text[i - 1];
        // 优先在句号、叹号、问号处分割
        if ('。！？；'.contains(char)) {
          bestSplit = i;
          break;
        }
        // 其次在逗号、顿号处分割
        if ('，、：'.contains(char) && bestSplit == -1) {
          bestSplit = i;
          break; // 找到逗号就可以切了，不需要继续找
        }
      }
      
      if (bestSplit > start) {
        sentences.add(text.substring(start, bestSplit).trim());
        start = bestSplit;
      } else {
        // 没找到标点，向后扩展搜索直到找到标点
        int forwardSplit = -1;
        for (int i = end; i < text.length; i++) {
          final char = text[i];
          if ('。！？；，、：'.contains(char)) {
            forwardSplit = i + 1;  // 包含标点
            break;
          }
        }
        
        if (forwardSplit > start) {
          sentences.add(text.substring(start, forwardSplit).trim());
          start = forwardSplit;
        } else {
          // 整个剩余文本都没有标点，作为最后一段
          sentences.add(text.substring(start).trim());
          break;
        }
      }
    }
    
    // 过滤空字符串
    return sentences.where((s) => s.isNotEmpty).toList();
  }

  

  
  bool _hasActualContent(String text) {
    final validContentRegex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbfa-zA-Z0-9]');
    return validContentRegex.hasMatch(text);
  }
  
  void _parseWordsForSentence(int sentenceIndex) {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) return;
    
    final sentence = _sentences[sentenceIndex];
    _words = [];
    // 重置校准参数
    _calibrationOffset = 0.0;
    _progressCallbackCount = 0;
    
    // 第一性原理：只需要按字符拆分，动画驱动高亮
    for (int i = 0; i < sentence.length; i++) {
      final char = sentence[i];
      if (char.trim().isNotEmpty) {
        _words.add(char);
      }
    }
    
    _debugLog('TTS MV: Sentence $sentenceIndex has ${_words.length} chars');
    
    // 第一性原理优化：预构建Widget列表
    _buildCachedWordWidgets();
  }
  
  /// 第一性原理优化：预构建字符Widget列表
  /// 只在句子变化时构建一次，而非每帧构建
  void _buildCachedWordWidgets() {
    _cachedWordWidgets = List.generate(_words.length, (index) {
      return _WordWidget(
        key: ValueKey('word_${_currentSentenceIndex}_$index'),
        word: _words[index],
        index: index,
        highlightIndex: _highlightIndex,
        pulseAnimation: _pulseAnimation!,
      );
    });
  }

  Future<void> _initTts() async {
    if (_disposed) return;
    
    try {
      await _ttsManager.initialize();
      _ttsInitialized = true;
      
      _baseMsPerChar = _ttsManager.calculateMsPerChar();
      _currentMsPerChar = _baseMsPerChar;
      
      // 第一性原理修复：始终使用 SENTENCE 模式
      // FULL 模式在 iOS 上有问题（缺少高亮动画启动，TTS 状态管理不稳定）
      // SENTENCE 模式更可控、更可靠
      _useSentenceMode = true;
      
      _debugLog('📱 TTS TextContent: TTS ready | speechRate=${_ttsManager.speechRate} | '
          'msPerChar=${_baseMsPerChar.toStringAsFixed(1)} | '
          'SentenceMode=$_useSentenceMode | ownerId=$_ownerId');
    } catch (e) {
      _baseMsPerChar = 200.0;
      _currentMsPerChar = _baseMsPerChar;
      _debugLog('📱 TTS TextContent: Init error: $e, using default msPerChar=$_baseMsPerChar');
    }
  }
  
  void _registerTtsCallbacks() {
    _ttsManager.registerCallbacks(
      ownerId: _ownerId,
      onProgress: (text, start, end, word) {
        if (_disposed || !mounted || !_playing) return;
        
        _progressCallbackCount++;
        
        // 第一性原理：Progress回调作为校准源，而非驱动源
        // 动画始终运行，这里只做微调校准
        _calibrateFromProgress(end);
        
        // 首次收到回调时取消超时（证明TTS正在工作）
        if (_progressCallbackCount == 1) {
          _cancelSentenceTimeout();
          _debugLog('📱 TTS ✅ Progress callback working, calibration mode active');
        }
        
        // Mac平台检测句子接近完成
        if (_ttsManager.isMacOS && _useSentenceMode && _playing) {
          final currentText = _sentences[_currentSentenceIndex];
          if (end >= currentText.length - 1) {
            _debugLog('📱 TTS (Mac): Progress near end (end=$end, len=${currentText.length})');
          }
        }
      },
      onCompletion: () {
        if (_disposed || !mounted || !_playing) return;
        
        final currentSessionId = _playbackSessionId;
        final capturedSentenceId = _currentSentenceId;
        final elapsed = _sentenceStopwatch?.elapsedMilliseconds ?? 0;
        _debugLog('📱 TTS 🔔 Completion callback received | '
            'sentence=$_currentSentenceIndex | elapsed=${elapsed}ms | '
            'sessionId=$currentSessionId | sentenceId=$capturedSentenceId');
        
        Future.microtask(() {
          if (_disposed || !mounted || !_playing) return;
          if (_playbackSessionId != currentSessionId) {
            _debugLog('📱 TTS ⚠️ Stale session completion callback, ignoring');
            return;
          }
          // 关键：验证句子ID，防止旧句子的completion影响新句子
          if (_currentSentenceId != capturedSentenceId) {
            _debugLog('📱 TTS ⚠️ Stale sentence completion callback (expected=$_currentSentenceId, got=$capturedSentenceId), ignoring');
            return;
          }
          
          // Mac平台额外验证：确保至少经过了合理的时间
          if (_ttsManager.isMacOS && elapsed < 100) {
            _debugLog('📱 TTS ⚠️ Mac: Suspiciously fast completion (${elapsed}ms), likely from stop(), ignoring');
            return;
          }
          
          if (_useSentenceMode) {
            _onSentenceComplete();
          } else {
            _onPlaybackComplete();
          }
        });
      },
      onError: (msg) {
        _debugLog('📱 TTS ❌ Error: $msg');
        if (_disposed || !mounted || !_playing) return;
        _handleTtsError(msg);
      },
    );
  }
  
  /// 第一性原理：Progress回调作为校准源
  /// 实时计算动画预测与TTS实际位置的偏差，渐进式校准
  void _calibrateFromProgress(int end) {
    if (_words.isEmpty || _highlightController == null) return;
    if (_currentSentenceIndex >= _sentences.length) return;
    
    final sentenceLength = _sentences[_currentSentenceIndex].length;
    if (sentenceLength == 0) return;
    
    // TTS实际位置对应的归一化进度
    final actualProgress = end / sentenceLength;
    // 动画当前进度
    final animationProgress = _highlightController!.value;
    
    // 计算偏差
    final error = actualProgress - animationProgress;
    
    // 渐进式校准（避免剧烈跳动）
    // 使用0.25的平滑因子：快速响应但不会过度抖动
    _calibrationOffset += error * 0.25;
    
    // 限制校准范围，防止异常值导致大幅跳动
    _calibrationOffset = _calibrationOffset.clamp(-0.15, 0.15);
    
    if (_progressCallbackCount % 5 == 0) {
      _debugLog('📱 TTS 🎯 Calibration: error=${error.toStringAsFixed(3)}, offset=${_calibrationOffset.toStringAsFixed(3)}');
    }
  }
  
  void _onSentenceComplete() {
    if (_disposed || !mounted || !_playing) return;
    
    if (_sentenceCompleteLock) return;
    if (_lastCompletedSentenceIndex == _currentSentenceIndex) return;
    
    _sentenceCompleteLock = true;
    _lastCompletedSentenceIndex = _currentSentenceIndex;
    
    final sentenceElapsed = _sentenceStopwatch?.elapsedMilliseconds ?? 0;
    _stopHighlightAnimation();
    _cancelSentenceTimeout();
    _waitingForCompletion = false;
    
    // 学习这句的实际速度
    if (_words.isNotEmpty && sentenceElapsed > 0) {
      final actualMsPerChar = sentenceElapsed / _words.length;
      _recordHistoricalSpeed(actualMsPerChar);
    }
    
    // 确保高亮到最后一个字
    if (_words.isNotEmpty) {
      _highlightIndex.value = _words.length - 1;
    }
    
    // 播放下一句
    final nextSentence = _currentSentenceIndex + 1;
    final sessionId = _playbackSessionId;
    
    if (nextSentence < _sentences.length) {
      final totalPause = _sentencePauseMs + (_ttsManager.isMacOS ? _macExtraDelayMs : 0);
      _debugLog('📱 TTS ⏸️ Pause ${totalPause}ms before sentence $nextSentence');
      
      Future.delayed(Duration(milliseconds: totalPause), () {
        if (_disposed || !mounted || !_playing) return;
        if (_playbackSessionId != sessionId) return;
        _playSentence(nextSentence);
      });
    } else {
      _debugLog('📱 TTS 🔁 All sentences complete, restarting');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_disposed || !mounted || !_playing) return;
        if (_playbackSessionId != sessionId) return;
        _playSentence(0);
      });
    }
  }
  
  Future<void> _playSentence(int sentenceIndex) async {
    if (_disposed || !mounted || !_playing) return;
    if (sentenceIndex >= _sentences.length) return;
    
    _currentSentenceIndex = sentenceIndex;
    _parseWordsForSentence(sentenceIndex);
    
    widget.onCurrentParagraphChanged?.call(_sentences[sentenceIndex]);
    
    _currentMsPerChar = _calculateMsPerChar(_words.length);
    final expectedDuration = _calculateExpectedSentenceDuration(_words.length).round();
    
    _sentenceStopwatch = Stopwatch()..start();
    _highlightIndex.value = 0;
    _waitingForCompletion = true;
    _sentenceCompleteLock = false;
    
    // 重置校准参数
    _calibrationOffset = 0.0;
    _progressCallbackCount = 0;
    
    // 生成新的句子ID，用于验证completion callback
    _currentSentenceId++;
    final sentenceId = _currentSentenceId;
    _debugLog('📱 TTS 📖 New sentenceId=$sentenceId for sentence $sentenceIndex');
    
    final sentence = _sentences[sentenceIndex];
    _debugLog('📱 TTS 📖 Playing sentence $sentenceIndex: "${sentence.substring(0, sentence.length.clamp(0, 20))}..."');
    
    _startSentenceTimeout(expectedDuration);
    
    // 第一性原理：先启动动画（预测性高亮），再开始TTS
    // 动画始终作为主驱动，不等待Progress回调
    _startHighlightAnimation();
    
    await _ttsManager.speak(sentence, _ownerId);
  }
  
  void _startHighlightAnimation() {
    _stopHighlightAnimation();
    
    if (_words.isEmpty) return;
    
    final duration = _calculateExpectedSentenceDuration(_words.length).round();
    
    _highlightController?.duration = Duration(milliseconds: duration);
    _highlightController?.forward(from: 0.0);
    
    _debugLog('📱 TTS 🎬 Started highlight animation: ${duration}ms for ${_words.length} chars');
  }
  
  void _stopHighlightAnimation() {
    _highlightController?.stop();
  }
  
  double _calculateExpectedSentenceDuration(int charCount) {
    double baseDuration = charCount * _currentMsPerChar;
    
    if (_ttsManager.isMacOS) {
      baseDuration *= 1.3;
    }
    
    return baseDuration;
  }
  
  void _startSentenceTimeout(int expectedDuration) {
    _cancelSentenceTimeout();
    
    final timeout = (expectedDuration * 1.5).round() + 1000;
    
    _sentenceTimeoutTimer = Timer(Duration(milliseconds: timeout), () {
      if (_disposed || !mounted || !_playing) return;
      if (!_waitingForCompletion) return;
      
      _debugLog('📱 TTS ⚠️ Sentence timeout, forcing completion');
      _onSentenceComplete();
    });
  }
  
  void _cancelSentenceTimeout() {
    _sentenceTimeoutTimer?.cancel();
    _sentenceTimeoutTimer = null;
  }
  
  void _recordHistoricalSpeed(double msPerChar) {
    if (msPerChar < 50 || msPerChar > 400) return;
    
    _historicalMsPerChar.add(msPerChar);
    if (_historicalMsPerChar.length > 10) {
      _historicalMsPerChar.removeAt(0);
    }
    
    if (_historicalMsPerChar.isNotEmpty) {
      double sum = 0;
      double weightSum = 0;
      for (int i = 0; i < _historicalMsPerChar.length; i++) {
        final weight = (i + 1).toDouble();
        sum += _historicalMsPerChar[i] * weight;
        weightSum += weight;
      }
      _baseMsPerChar = sum / weightSum;
    }
  }
  
  double _calculateMsPerChar(int charCount) {
    double msPerChar = _baseMsPerChar;
    
    if (charCount < 5) {
      msPerChar *= 0.85;
    } else if (charCount > 20) {
      msPerChar *= 1.15;
    }
    
    return msPerChar.clamp(80.0, 250.0);
  }
  
  void _handleTtsError(String msg) {
    if (msg.contains('-8')) {
      _debugLog('📱 TTS: Engine busy, retrying in 500ms');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_disposed || !mounted || !_playing) return;
        _playSentence(_currentSentenceIndex);
      });
    } else {
      _onSentenceComplete();
    }
  }

  bool _shouldPlayTts() {
    if (!mounted || _disposed) return false;
    if (!widget.isVisible) return false;
    
    try {
      final visibilityNotifier = context.read<VideoFeedVisibilityNotifier>();
      if (!visibilityNotifier.isVideoFeedVisible) {
        return false;
      }
    } catch (e) {
      return false;
    }
    
    try {
      final muteNotifier = context.read<TtsMuteNotifier>();
      if (muteNotifier.isMuted) {
        return false;
      }
    } catch (e) {
      return false;
    }
    
    return true;
  }

  void _tryStart() {
    if (_disposed || !mounted) return;
    if (_playing || _sentences.isEmpty) return;
    if (!_ttsInitialized) {
      // 更快的初始化检查循环，减少启动延迟
      Future.delayed(const Duration(milliseconds: 100), _tryStart);
      return;
    }
    
    if (!_shouldPlayTts()) return;
    
    _debugLog('📱 TTS TextContent: _tryStart called for $_ownerId');
    
    _playbackSessionId++;
    _debugLog('📱 TTS 🎬 New playback session: $_playbackSessionId');
    
    _playing = true;
    _calibrationOffset = 0.0;
    _progressCallbackCount = 0;
    _currentSentenceIndex = 0;
    _highlightIndex.value = -1;
    
    _sentenceCompleteLock = false;
    _lastCompletedSentenceIndex = -1;
    _waitingForCompletion = false;
    
    _registerTtsCallbacks();
    
    _debugLog('📱 TTS ▶️ PLAYBACK START | '
        'mode=${_useSentenceMode ? "SENTENCE" : "FULL"} | '
        'sentences=${_sentences.length}');
    
    if (_useSentenceMode) {
      _playSentence(0);
    } else {
      _playFullText();
    }
  }
  
  void _playFullText() {
    if (_sentences.isEmpty) return;
    
    _parseWordsForSentence(0);
    widget.onCurrentParagraphChanged?.call(_sentences[0]);
    
    final fullText = _sentences.join('，');
    _ttsManager.speak(fullText, _ownerId);
  }
  
  void _onPlaybackComplete() {
    if (_disposed || !mounted || !_playing) return;
    
    _debugLog('📱 TTS 🔁 LOOP RESTART');
    
    _stopHighlightAnimation();
    _cancelSentenceTimeout();
    
    _currentSentenceIndex = 0;
    _highlightIndex.value = -1;
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted || !_playing) return;
      
      if (_useSentenceMode) {
        _playSentence(0);
      } else {
        _playFullText();
      }
    });
  }

  void _stopPlayback() {
    if (!_playing) return;
    // 添加调用栈跟踪，帮助定位停止的触发源
    _debugLog('📱 TTS TextContent: Stopping playback for $_ownerId');
    _debugLog('📱 TTS TextContent: Stop triggered - stack: ${StackTrace.current.toString().split('\n').take(5).join(' | ')}');
    _playing = false;
    _waitingForCompletion = false;
    _stopHighlightAnimation();
    _cancelSentenceTimeout();
    _ttsManager.stop();
    _ttsManager.unregisterCallbacks(_ownerId);
  }

  @override
  void didUpdateWidget(VideoFeedViewTextContent old) {
    super.didUpdateWidget(old);
    
    if (old.isVisible != widget.isVisible) {
      _debugLog('📱 TTS TextContent: Visibility ${old.isVisible} -> ${widget.isVisible} for $_ownerId');
      
      Future.microtask(() {
        if (_disposed || !mounted) return;
        
        if (widget.isVisible && !_playing) {
          _debugLog('📱 TTS TextContent: Becoming visible, starting playback');
          _tryStart();
        } else if (!widget.isVisible && _playing) {
          _debugLog('📱 TTS TextContent: Becoming invisible, stopping playback');
          _stopPlayback();
        }
      });
    }
    
    // Dart String 的 != 是值比较，可以直接使用
    if (old.textContent != widget.textContent) {
      _debugLog('TTS MV: Content actually changed, invalidating session $_playbackSessionId');
      _debugLog('TTS MV: Old content length=${old.textContent.length}, New=${widget.textContent.length}');
      
      _playbackSessionId++;
      
      _stopPlayback();
      _parseContent();
      _currentSentenceIndex = 0;
      _highlightIndex.value = -1;
      
      _sentenceCompleteLock = false;
      _lastCompletedSentenceIndex = -1;
      _waitingForCompletion = false;
      
      _historicalMsPerChar.clear();
      _baseMsPerChar = _ttsManager.calculateMsPerChar();
      if (widget.isVisible && _sentences.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_disposed && widget.isVisible) {
            _tryStart();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _debugLog('📱 TTS TextContent: Disposing $_ownerId');
    _disposed = true;
    _removeListeners();
    _stopHighlightAnimation();
    _cancelSentenceTimeout();
    _highlightController?.removeListener(_onHighlightAnimationTick);
    _highlightController?.dispose();
    _pulseController?.dispose();
    _highlightIndex.dispose();
    _stopPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sentences.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('暂无内容', style: TextStyle(color: Colors.white54)),
        ),
      );
    }
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_playing) {
          _stopPlayback();
        } else if (widget.isVisible) {
          _tryStart();
        }
      },
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // 第一性原理优化：使用 RepaintBoundary 隔离重绘
            child: RepaintBoundary(
              child: _buildOptimizedKaraokeText(),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 第一性原理优化：使用预构建的Widget列表
  Widget _buildOptimizedKaraokeText() {
    if (_cachedWordWidgets == null || _cachedWordWidgets!.isEmpty) {
      final safeIndex = _currentSentenceIndex.clamp(0, _sentences.length - 1);
      return Text(
        _sentences[safeIndex],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 8, offset: Offset(2, 2)),
          ],
        ),
      );
    }
    
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: _cachedWordWidgets!,
    );
  }
}

/// 第一性原理优化：独立的字符Widget
/// 使用 ValueListenableBuilder 只在高亮索引变化时重建
class _WordWidget extends StatelessWidget {
  const _WordWidget({
    super.key,
    required this.word,
    required this.index,
    required this.highlightIndex,
    required this.pulseAnimation,
  });
  
  final String word;
  final int index;
  final ValueNotifier<int> highlightIndex;
  final Animation<double> pulseAnimation;
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: highlightIndex,
      builder: (context, currentHighlightIndex, child) {
        final isHighlighted = index == currentHighlightIndex;
        final isPast = index < currentHighlightIndex;
        
        Color color = Colors.white60;
        if (isHighlighted) {
          color = const Color(0xFFFFD700);
        } else if (isPast) {
          color = Colors.white;
        }
        
        // 只有高亮字符需要动画
        if (isHighlighted) {
          return AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: color,
                      shadows: [
                        Shadow(
                          color: Colors.orange.withValues(alpha: 0.8),
                          blurRadius: 20,
                          offset: const Offset(2, 2),
                        ),
                        const Shadow(
                          color: Colors.yellow,
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
        
        // 非高亮字符：静态渲染，无动画开销
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 8,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
