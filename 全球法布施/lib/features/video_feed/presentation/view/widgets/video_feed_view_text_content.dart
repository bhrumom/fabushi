import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:global_dharma_sharing/services/tts_manager.dart';
import 'package:global_dharma_sharing/providers/video_feed_visibility_notifier.dart';
import 'package:global_dharma_sharing/providers/tts_mute_notifier.dart';

/// 文字视频内容组件 - MV卡拉OK风格逐字高亮
/// 
/// 特点：
/// - 智能同步算法：逐句播放 + completion回调校准
/// - 自适应学习：从每句的实际播放时间学习语速
/// - 实时漂移校正：句内动态调整高亮速度
/// - 无进度回调时也能精确同步：利用句子完成回调
/// - 使用全局单例TTS管理器，避免多实例冲突
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
  int _currentWordIndex = -1;
  
  // 状态
  bool _playing = false;
  bool _disposed = false;
  bool _ttsInitialized = false;
  
  // ========= 逐句播放模式 =========
  bool _useSentenceMode = true;  // 使用逐句播放模式
  bool _waitingForCompletion = false;  // 是否在等待TTS完成
  
  // Fallback 机制
  Timer? _fallbackTimer;
  Timer? _sentenceTimeoutTimer;  // 句子超时计时器
  bool _progressCallbackReceived = false;
  
  // 时间追踪
  Stopwatch? _sentenceStopwatch;  // 当前句子的计时器
  
  // ========= 智能同步算法参数 =========
  // 基础语速参数（毫秒/字符）- 会根据实际TTS回调动态调整
  double _baseMsPerChar = 140.0;  // 默认值略保守
  // 当前句子的动态速度
  double _currentMsPerChar = 140.0;
  // 句子间停顿时间
  static const int _sentencePauseMs = 400;
  
  // 自适应学习数据
  final List<double> _historicalMsPerChar = [];
  
  // 动画控制器
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  
  // 3D 旋转动画控制器
  AnimationController? _rotationController;
  
  // 已读句子列表（用于上方3D旋转显示）
  final List<String> _pastSentences = [];
  
  // TTS管理器
  final TtsManager _ttsManager = TtsManager();
  
  // 监听器引用（用于移除）
  VoidCallback? _muteListener;
  VoidCallback? _visibilityListener;

  @override
  void initState() {
    super.initState();
    _ownerId = 'text_content_${hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('📱 TTS TextContent: Created with ownerId=$_ownerId');
    
    _initAnimations();
    _parseContent();
    _initTts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupListeners();
  }

  /// 设置静音和可见性监听器
  void _setupListeners() {
    // 设置静音监听器
    if (_muteListener == null) {
      try {
        final muteNotifier = context.read<TtsMuteNotifier>();
        _muteListener = () => _onMuteChanged(muteNotifier.isMuted);
        muteNotifier.addListener(_muteListener!);
      } catch (e) {
        debugPrint('📱 TTS: Could not setup mute listener: $e');
      }
    }
    
    // 设置页面可见性监听器
    if (_visibilityListener == null) {
      try {
        final visibilityNotifier = context.read<VideoFeedVisibilityNotifier>();
        _visibilityListener = () => _onPageVisibilityChanged(visibilityNotifier.isVideoFeedVisible);
        visibilityNotifier.addListener(_visibilityListener!);
      } catch (e) {
        debugPrint('📱 TTS: Could not setup visibility listener: $e');
      }
    }
  }

  /// 移除监听器
  void _removeListeners() {
    if (_muteListener != null) {
      try {
        context.read<TtsMuteNotifier>().removeListener(_muteListener!);
      } catch (e) {
        // 忽略，可能context已不可用
      }
      _muteListener = null;
    }
    
    if (_visibilityListener != null) {
      try {
        context.read<VideoFeedVisibilityNotifier>().removeListener(_visibilityListener!);
      } catch (e) {
        // 忽略，可能context已不可用
      }
      _visibilityListener = null;
    }
  }

  /// 静音状态变化回调
  void _onMuteChanged(bool isMuted) {
    if (_disposed || !mounted) return;
    
    debugPrint('📱 TTS: Mute changed to ${isMuted ? "MUTED" : "UNMUTED"}');
    
    if (isMuted && _playing) {
      // 被静音了，停止播放
      _stopPlayback();
    } else if (!isMuted && !_playing && widget.isVisible) {
      // 取消静音，并且item可见，尝试开始播放
      _tryStart();
    }
  }

  /// 页面可见性变化回调
  void _onPageVisibilityChanged(bool isPageVisible) {
    if (_disposed || !mounted) return;
    
    debugPrint('📱 TTS: Page visibility changed to ${isPageVisible ? "VISIBLE" : "HIDDEN"}');
    
    if (!isPageVisible && _playing) {
      // 页面不可见，停止播放
      _stopPlayback();
    } else if (isPageVisible && !_playing && widget.isVisible) {
      // 页面变为可见，且item可见，尝试开始播放
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
    
    // 3D 旋转动画：8秒一圈，持续旋转
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  /// 解析内容：分句
  void _parseContent() {
    _sentences = [];
    
    if (widget.textContent.isEmpty) return;
    
    // 使用标点分句
    final parts = widget.textContent.split(RegExp(r'[，。！？、；：\n]+'));
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty) _sentences.add(t);
    }
    
    debugPrint('TTS MV: Parsed ${_sentences.length} sentences');
    if (_sentences.isNotEmpty) {
      _parseWordsForSentence(0);
    }
  }
  
  void _parseWordsForSentence(int sentenceIndex) {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) return;
    
    final sentence = _sentences[sentenceIndex];
    _words = [];
    
    for (int i = 0; i < sentence.length; i++) {
      final char = sentence[i];
      if (char.trim().isNotEmpty) {
        _words.add(char);
      }
    }
    
    debugPrint('TTS MV: Sentence $sentenceIndex has ${_words.length} chars: "${sentence.substring(0, sentence.length.clamp(0, 15))}..."');
  }

  Future<void> _initTts() async {
    if (_disposed) return;
    
    try {
      await _ttsManager.initialize();
      _ttsInitialized = true;
      
      // 检测是否需要使用逐句模式
      _useSentenceMode = _ttsManager.useFallbackOnly;
      
      debugPrint('📱 TTS TextContent: TTS ready | SentenceMode=$_useSentenceMode | ownerId=$_ownerId');
      
      // 不再在初始化后自动开始播放，等待可见性和静音状态检查
      // TTS播放由 _tryStart 方法控制，该方法会检查页面可见性和静音状态
    } catch (e) {
      debugPrint('📱 TTS TextContent: Init error: $e');
    }
  }
  
  void _registerTtsCallbacks() {
    _ttsManager.registerCallbacks(
      ownerId: _ownerId,
      onProgress: (text, start, end, word) {
        if (_disposed || !mounted || !_playing) return;
        
        if (!_progressCallbackReceived) {
          _progressCallbackReceived = true;
          _cancelFallbackTimer();
          _cancelSentenceTimeout();
          debugPrint('📱 TTS ✅ Progress callback WORKING! Switching to progress mode');
          // 进度回调工作，不再使用逐句模式
          _useSentenceMode = false;
        }
        
        // 使用进度回调更新高亮
        _updateHighlightFromProgress(end, word);
      },
      onCompletion: () {
        if (_disposed || !mounted || !_playing) return;
        
        debugPrint('📱 TTS 🔔 Completion callback received');
        
        if (_useSentenceMode) {
          // 逐句模式：句子播放完成
          _onSentenceComplete();
        } else {
          // 全文模式：全部播放完成
          _onPlaybackComplete();
        }
      },
      onError: (msg) {
        debugPrint('📱 TTS ❌ Error: $msg');
        if (_disposed || !mounted || !_playing) return;
        _handleTtsError(msg);
      },
    );
  }
  
  /// 使用进度回调更新高亮（支持进度回调的设备）
  void _updateHighlightFromProgress(int end, String word) {
    // 在当前句子中找到对应的字
    if (_words.isEmpty) return;
    
    // 简单实现：根据位置估算当前字
    final estimatedIndex = (end / 2).clamp(0, _words.length - 1).toInt();
    
    if (estimatedIndex != _currentWordIndex && estimatedIndex >= 0) {
      _currentWordIndex = estimatedIndex;
      _pulseController?.forward(from: 0);
      if (mounted) setState(() {});
    }
  }
  
  /// 句子播放完成（逐句模式核心逻辑）
  void _onSentenceComplete() {
    if (_disposed || !mounted || !_playing) return;
    
    final sentenceElapsed = _sentenceStopwatch?.elapsedMilliseconds ?? 0;
    _cancelFallbackTimer();
    _cancelSentenceTimeout();
    _waitingForCompletion = false;
    
    // 学习这句的实际速度
    if (_words.isNotEmpty && sentenceElapsed > 0) {
      final actualMsPerChar = sentenceElapsed / _words.length;
      _recordHistoricalSpeed(actualMsPerChar);
      
      debugPrint('📱 TTS 📊 Sentence $_currentSentenceIndex complete | '
          'actual=${sentenceElapsed}ms | '
          'speed=${actualMsPerChar.toStringAsFixed(1)}ms/char | '
          'predicted=${_currentMsPerChar.toStringAsFixed(1)}ms/char');
    }
    
    // 确保高亮到最后一个字
    if (_words.isNotEmpty) {
      _currentWordIndex = _words.length - 1;
      if (mounted) setState(() {});
    }
    
    // 将已读句子添加到 past 列表（用于上方3D旋转显示）
    if (_currentSentenceIndex < _sentences.length) {
      final completedSentence = _sentences[_currentSentenceIndex];
      if (!_pastSentences.contains(completedSentence)) {
        _pastSentences.insert(0, completedSentence);
        // 只保留最近 5 条
        if (_pastSentences.length > 5) {
          _pastSentences.removeLast();
        }
      }
    }
    
    // 播放下一句
    final nextSentence = _currentSentenceIndex + 1;
    if (nextSentence < _sentences.length) {
      debugPrint('📱 TTS ⏸️ Pause ${_sentencePauseMs}ms before sentence $nextSentence');
      
      Future.delayed(Duration(milliseconds: _sentencePauseMs), () {
        if (_disposed || !mounted || !_playing) return;
        _playSentence(nextSentence);
      });
    } else {
      // 全部播放完成，循环
      debugPrint('📱 TTS 🔁 All sentences complete, restarting in 800ms');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_disposed || !mounted || !_playing) return;
        _playSentence(0);
      });
    }
  }
  
  /// 播放单个句子（逐句模式）
  Future<void> _playSentence(int sentenceIndex) async {
    if (_disposed || !mounted || !_playing) return;
    if (sentenceIndex >= _sentences.length) return;
    
    _currentSentenceIndex = sentenceIndex;
    _parseWordsForSentence(sentenceIndex);
    
    // 通知句子变化
    widget.onCurrentParagraphChanged?.call(_sentences[sentenceIndex]);
    
    // 计算这句的预期速度
    _currentMsPerChar = _calculateMsPerChar(_words.length);
    // 使用考虑加速曲线的预期时长
    final expectedDuration = _calculateExpectedSentenceDuration(_words.length).round();
    
    debugPrint('📱 TTS 📖 Playing sentence $sentenceIndex | '
        'chars=${_words.length} | '
        'speed=${_currentMsPerChar.toStringAsFixed(1)}ms/char | '
        'expected=${expectedDuration}ms (with acceleration)');
    
    // 重置句子计时器
    _sentenceStopwatch = Stopwatch()..start();
    _currentWordIndex = 0;
    _waitingForCompletion = true;
    
    if (mounted) setState(() {});
    
    // 启动句内高亮 fallback
    _startSentenceFallback();
    
    // 设置超时保护（预期时间的 1.5 倍）
    _startSentenceTimeout(expectedDuration);
    
    // 播放这个句子
    final sentence = _sentences[sentenceIndex];
    await _ttsManager.speak(sentence, _ownerId);
  }
  
  /// 启动句内高亮 fallback
  void _startSentenceFallback() {
    _cancelFallbackTimer();
    
    if (_words.isEmpty) return;
    
    _currentWordIndex = 0;
    _pulseController?.forward(from: 0);
    
    _scheduleFallbackWord(0);
  }
  
  /// 调度下一个字的高亮（使用非线性速度曲线）
  /// 
  /// TTS 引擎特性：长句子后半部分会自然加速
  /// 速度曲线设计：
  /// - 前 30% 的字：正常速度 (1.0x)
  /// - 中间 40% 的字：逐渐加速 (1.0x -> 1.4x)
  /// - 最后 30% 的字：最快速度 (1.4x -> 1.6x)
  void _scheduleFallbackWord(int wordIndex) {
    if (!_playing || _disposed) return;
    if (_progressCallbackReceived) return;
    
    final wordsRemaining = _words.length - wordIndex - 1;
    
    if (wordsRemaining <= 0) {
      // 最后一个字，等待 completion
      return;
    }
    
    // 计算当前字在句子中的位置比例 (0.0 - 1.0)
    final progress = wordIndex / _words.length;
    
    // 计算速度因子（模拟TTS加速曲线）
    final speedFactor = _calculateSpeedFactor(progress, _words.length);
    
    // 基础延迟时间（考虑速度因子）
    final baseDelay = _currentMsPerChar / speedFactor;
    
    // 应用动态校准（确保能在预期时间内完成）
    final elapsed = _sentenceStopwatch?.elapsedMilliseconds ?? 0;
    final expectedTotal = _calculateExpectedSentenceDuration(_words.length);
    final remainingTime = expectedTotal - elapsed;
    
    int delayMs;
    if (remainingTime > 0 && wordsRemaining > 0) {
      // 计算剩余字需要的平均时间
      final avgRemainingDelay = remainingTime / wordsRemaining;
      // 使用曲线速度和剩余时间的加权平均
      // 前期更信任曲线速度，后期更信任剩余时间
      final trustRemainingFactor = progress.clamp(0.0, 0.8);
      delayMs = (baseDelay * (1 - trustRemainingFactor) + avgRemainingDelay * trustRemainingFactor)
          .clamp(40.0, 300.0).round();
    } else if (remainingTime <= 0) {
      // 已经落后，快速追赶
      delayMs = 40;
    } else {
      delayMs = baseDelay.clamp(40.0, 300.0).round();
    }
    
    _fallbackTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_disposed || !mounted || !_playing) return;
      if (_progressCallbackReceived) return;
      
      final nextWordIndex = wordIndex + 1;
      if (nextWordIndex < _words.length) {
        _currentWordIndex = nextWordIndex;
        _pulseController?.forward(from: 0);
        if (mounted) setState(() {});
        
        _scheduleFallbackWord(nextWordIndex);
      }
    });
  }
  
  /// 计算速度因子（非线性曲线）
  /// 
  /// progress: 0.0 (句子开始) -> 1.0 (句子结束)
  /// charCount: 句子字数，用于调整曲线
  /// 
  /// 返回速度因子：1.0 = 正常速度，>1.0 = 加速
  double _calculateSpeedFactor(double progress, int charCount) {
    // 短句子（<8字）不需要加速
    if (charCount < 8) {
      return 1.0;
    }
    
    // 中等句子（8-15字）轻微加速
    if (charCount <= 15) {
      if (progress < 0.4) {
        return 1.0;
      } else if (progress < 0.7) {
        // 线性加速：1.0 -> 1.2
        return 1.0 + (progress - 0.4) / 0.3 * 0.2;
      } else {
        return 1.2;
      }
    }
    
    // 长句子（>15字）明显加速曲线
    if (progress < 0.25) {
      // 前25%：正常速度
      return 1.0;
    } else if (progress < 0.5) {
      // 25%-50%：开始加速 (1.0 -> 1.3)
      final localProgress = (progress - 0.25) / 0.25;
      return 1.0 + localProgress * 0.3;
    } else if (progress < 0.75) {
      // 50%-75%：继续加速 (1.3 -> 1.5)
      final localProgress = (progress - 0.5) / 0.25;
      return 1.3 + localProgress * 0.2;
    } else {
      // 最后25%：最快速度 (1.5 -> 1.7)
      final localProgress = (progress - 0.75) / 0.25;
      return 1.5 + localProgress * 0.2;
    }
  }
  
  /// 计算预期句子总时长（考虑加速曲线）
  double _calculateExpectedSentenceDuration(int charCount) {
    // 简单估算：由于后期加速，总时间比匀速少约 15-25%
    double reductionFactor;
    if (charCount < 8) {
      reductionFactor = 1.0;  // 短句不加速
    } else if (charCount <= 15) {
      reductionFactor = 0.92;  // 中等句减少 8%
    } else {
      reductionFactor = 0.82;  // 长句减少 18%
    }
    
    return charCount * _currentMsPerChar * reductionFactor;
  }
  
  /// 设置句子超时保护
  void _startSentenceTimeout(int expectedDuration) {
    _cancelSentenceTimeout();
    
    // 超时时间 = 预期时间 * 1.5 + 1秒缓冲
    final timeout = (expectedDuration * 1.5).round() + 1000;
    
    _sentenceTimeoutTimer = Timer(Duration(milliseconds: timeout), () {
      if (_disposed || !mounted || !_playing) return;
      if (!_waitingForCompletion) return;
      
      debugPrint('📱 TTS ⚠️ Sentence timeout after ${timeout}ms, forcing completion');
      _onSentenceComplete();
    });
  }
  
  void _cancelSentenceTimeout() {
    _sentenceTimeoutTimer?.cancel();
    _sentenceTimeoutTimer = null;
  }
  
  /// 记录历史语速数据
  void _recordHistoricalSpeed(double msPerChar) {
    // 只接受合理范围内的值
    if (msPerChar < 50 || msPerChar > 400) return;
    
    _historicalMsPerChar.add(msPerChar);
    if (_historicalMsPerChar.length > 10) {
      _historicalMsPerChar.removeAt(0);
    }
    
    // 更新基础语速（加权平均，新数据权重更高）
    if (_historicalMsPerChar.isNotEmpty) {
      double sum = 0;
      double weightSum = 0;
      for (int i = 0; i < _historicalMsPerChar.length; i++) {
        final weight = (i + 1).toDouble();
        sum += _historicalMsPerChar[i] * weight;
        weightSum += weight;
      }
      _baseMsPerChar = sum / weightSum;
      debugPrint('📱 TTS 📊 Updated base speed: ${_baseMsPerChar.toStringAsFixed(1)}ms/char '
          '(from ${_historicalMsPerChar.length} samples)');
    }
  }
  
  /// 计算当前句子的预估每字毫秒数
  double _calculateMsPerChar(int charCount) {
    double msPerChar = _baseMsPerChar;
    
    // 根据句子长度调整
    if (charCount < 5) {
      msPerChar *= 0.85;  // 短句稍快
    } else if (charCount > 20) {
      msPerChar *= 1.15;  // 长句稍慢
    }
    
    return msPerChar.clamp(80.0, 250.0);
  }
  
  void _handleTtsError(String msg) {
    if (msg.contains('-8')) {
      // TTS引擎忙，等待后重试当前句子
      debugPrint('📱 TTS: Engine busy, retrying in 500ms');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_disposed || !mounted || !_playing) return;
        _playSentence(_currentSentenceIndex);
      });
    } else {
      // 其他错误，跳到下一句
      _onSentenceComplete();
    }
  }
  
  void _cancelFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  /// 检查是否应该播放TTS
  /// 需要同时满足：item可见 + 页面激活 + 未静音
  bool _shouldPlayTts() {
    if (!mounted || _disposed) return false;
    if (!widget.isVisible) return false;
    
    // 检查页面可见性
    try {
      final visibilityNotifier = context.read<VideoFeedVisibilityNotifier>();
      if (!visibilityNotifier.isVideoFeedVisible) {
        debugPrint('📱 TTS: Page not visible, skipping playback');
        return false;
      }
    } catch (e) {
      debugPrint('📱 TTS: Could not read visibility notifier: $e');
      return false;
    }
    
    // 检查静音状态
    try {
      final muteNotifier = context.read<TtsMuteNotifier>();
      if (muteNotifier.isMuted) {
        debugPrint('📱 TTS: Muted, skipping playback');
        return false;
      }
    } catch (e) {
      debugPrint('📱 TTS: Could not read mute notifier: $e');
      return false;
    }
    
    return true;
  }

  void _tryStart() {
    if (_disposed || !mounted) return;
    if (_playing || _sentences.isEmpty) return;
    if (!_ttsInitialized) {
      debugPrint('📱 TTS TextContent: TTS not ready yet, will retry');
      Future.delayed(const Duration(milliseconds: 300), _tryStart);
      return;
    }
    
    // 检查是否应该播放（item可见 + 页面激活 + 未静音）
    if (!_shouldPlayTts()) {
      return;
    }
    
    debugPrint('📱 TTS TextContent: _tryStart called for $_ownerId');
    
    _playing = true;
    _progressCallbackReceived = false;
    _currentSentenceIndex = 0;
    _currentWordIndex = -1;
    
    if (mounted) setState(() {});
    
    // 注册回调
    _registerTtsCallbacks();
    
    debugPrint('📱 TTS ▶️ PLAYBACK START | '
        'mode=${_useSentenceMode ? "SENTENCE" : "FULL"} | '
        'sentences=${_sentences.length} | '
        'baseMsPerChar=${_baseMsPerChar.toStringAsFixed(1)}');
    
    if (_useSentenceMode) {
      // 逐句播放模式
      _playSentence(0);
    } else {
      // 全文播放模式（有进度回调的设备）
      _playFullText();
    }
  }
  
  /// 全文播放模式
  void _playFullText() {
    if (_sentences.isEmpty) return;
    
    _parseWordsForSentence(0);
    widget.onCurrentParagraphChanged?.call(_sentences[0]);
    
    final fullText = _sentences.join('，');
    _ttsManager.speak(fullText, _ownerId);
  }
  
  void _onPlaybackComplete() {
    if (_disposed || !mounted || !_playing) return;
    
    debugPrint('📱 TTS 🔁 LOOP RESTART | waiting 800ms');
    
    _cancelFallbackTimer();
    _cancelSentenceTimeout();
    
    _currentSentenceIndex = 0;
    _currentWordIndex = -1;
    
    if (mounted) setState(() {});
    
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
    debugPrint('📱 TTS TextContent: Stopping playback for $_ownerId');
    _playing = false;
    _waitingForCompletion = false;
    _cancelFallbackTimer();
    _cancelSentenceTimeout();
    _ttsManager.stop();
    _ttsManager.unregisterCallbacks(_ownerId);
  }

  @override
  void didUpdateWidget(VideoFeedViewTextContent old) {
    super.didUpdateWidget(old);
    
    if (old.isVisible != widget.isVisible) {
      debugPrint('📱 TTS TextContent: Visibility ${old.isVisible} -> ${widget.isVisible} for $_ownerId');
      
      Future.microtask(() {
        if (_disposed || !mounted) return;
        
        if (widget.isVisible && !_playing) {
          debugPrint('📱 TTS TextContent: Becoming visible, starting playback');
          _tryStart();
        } else if (!widget.isVisible && _playing) {
          debugPrint('📱 TTS TextContent: Becoming invisible, stopping playback');
          _stopPlayback();
        }
      });
    }
    
    if (old.textContent != widget.textContent) {
      debugPrint('TTS MV: Content changed');
      _stopPlayback();
      _parseContent();
      _currentSentenceIndex = 0;
      _currentWordIndex = -1;
      _historicalMsPerChar.clear();  // 新内容，重置学习数据
      _baseMsPerChar = 140.0;
      if (widget.isVisible && _sentences.isNotEmpty) {
        Future.microtask(() {
          if (mounted && !_disposed && widget.isVisible) {
            _tryStart();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('📱 TTS TextContent: Disposing $_ownerId');
    _disposed = true;
    _removeListeners();
    _cancelFallbackTimer();
    _cancelSentenceTimeout();
    _pulseController?.dispose();
    _rotationController?.dispose();
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
          setState(() {});
        } else if (widget.isVisible) {
          _tryStart();
        }
      },
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation!, _rotationController!]),
          builder: (context, child) {
            return _buildLyricsStyleLayout();
          },
        ),
      ),
    );
  }
  
  /// 构建歌词风格布局 - 垂直滚动，像音乐软件歌词
  Widget _buildLyricsStyleLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上方：已读句子（每句独立3D旋转）
          ..._buildPastSentencesLyrics(),
          
          // 中间：当前正在读的句子（最大，高亮）
          _buildCurrentSentenceLyrics(),
          
          // 下方：未读句子
          ..._buildUpcomingSentencesLyrics(),
        ],
      ),
    );
  }
  
  /// 构建已读句子列表 - 每句独立3D旋转
  List<Widget> _buildPastSentencesLyrics() {
    if (_pastSentences.isEmpty) {
      return [];
    }
    
    final rotationValue = _rotationController?.value ?? 0.0;
    
    return _pastSentences.reversed.map((sentence) {
      final index = _pastSentences.indexOf(sentence);
      // 每个句子有不同的旋转相位
      final phase = index * 0.5;
      final angle = (rotationValue * 2 * math.pi) + phase;
      
      // 3D旋转效果 - 每个句子单独绕Y轴旋转
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)  // 透视
            ..rotateY(math.sin(angle) * 0.3),  // Y轴来回旋转
          child: Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withValues(alpha: 0.2),
                    Colors.blue.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sentence,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white54,
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
  
  /// 构建当前句子 - 最大，金色高亮，卡拉OK效果
  Widget _buildCurrentSentenceLyrics() {
    if (_words.isEmpty) {
      final safeIndex = _currentSentenceIndex.clamp(0, _sentences.length - 1);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          _sentences.isNotEmpty ? _sentences[safeIndex] : '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(2, 2)),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List.generate(_words.length, (index) {
          final isHighlighted = index == _currentWordIndex;
          final isPast = index < _currentWordIndex;
          final word = _words[index];
          
          double scale = 1.0;
          Color color = Colors.white60;
          
          if (isHighlighted) {
            scale = _pulseAnimation?.value ?? 1.15;
            color = const Color(0xFFFFD700);  // 金色高亮
          } else if (isPast) {
            color = Colors.white;
          }
          
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
              child: Text(
                word,
                style: TextStyle(
                  fontSize: isHighlighted ? 30 : 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                  shadows: [
                    Shadow(
                      color: isHighlighted ? Colors.orange.withValues(alpha: 0.8) : Colors.black,
                      blurRadius: isHighlighted ? 15 : 6,
                      offset: const Offset(1, 1),
                    ),
                    if (isHighlighted)
                      const Shadow(
                        color: Colors.yellow,
                        blurRadius: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
  
  /// 构建未读句子列表
  List<Widget> _buildUpcomingSentencesLyrics() {
    final upcoming = <String>[];
    
    // 获取接下来的 3 个句子
    for (int i = _currentSentenceIndex + 1; 
         i < _sentences.length && upcoming.length < 3; 
         i++) {
      upcoming.add(_sentences[i]);
    }
    
    if (upcoming.isEmpty) {
      return [];
    }
    
    return upcoming.asMap().entries.map((entry) {
      final index = entry.key;
      final sentence = entry.value;
      final opacity = 0.4 - (index * 0.1);
      final fontSize = 18.0 - (index * 2);
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          sentence,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: opacity.clamp(0.15, 0.4)),
            shadows: const [
              Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 1)),
            ],
          ),
        ),
      );
    }).toList();
  }
}

