import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:global_dharma_sharing/services/tts_manager.dart';
import 'package:global_dharma_sharing/providers/video_feed_visibility_notifier.dart';
import 'package:global_dharma_sharing/providers/tts_mute_notifier.dart';

/// 高亮状态源枚举（第一性原理：单一状态源 + 明确优先级）
/// Progress 回调 > AnimationController > 手动设置
enum HighlightSource {
  animation,  // AnimationController 驱动
  progress,   // TTS Progress 回调驱动  
  manual,     // 手动设置（如句子完成时）
}

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
  
  // ========= 平滑高亮动画（第一性原理重构）=========
  // 使用AnimationController替代Timer，提供60fps平滑动画
  AnimationController? _highlightController;
  Timer? _sentenceTimeoutTimer;  // 句子超时计时器
  bool _progressCallbackReceived = false;
  
  // 句子完成锁定（防止重复触发）
  bool _sentenceCompleteLock = false;
  int _lastCompletedSentenceIndex = -1;
  
  // ========= 状态源锁定（第一性原理：防止多源竞争）=========
  HighlightSource _activeHighlightSource = HighlightSource.animation;
  int _lastProgressWordIndex = -1;  // Progress 回调最后设置的索引
  
  // ========= 播放会话跟踪（第一性原理：防止旧回调影响新内容）=========
  // 每次开始播放生成新ID，所有延迟回调检查ID是否有效
  int _playbackSessionId = 0;
  
  // 时间追踪
  Stopwatch? _sentenceStopwatch;  // 当前句子的计时器
  
  // ========= 智能同步算法参数 =========
  // 基础语速参数（毫秒/字符）- 根据TTS语速动态计算
  // 第一性原理：语速决定朗读速度，高亮应同步
  late double _baseMsPerChar;  // 由TtsManager根据语速计算
  // 当前句子的动态速度
  double _currentMsPerChar = 140.0;
  // 句子间停顿时间
  static const int _sentencePauseMs = 400;
  
  // 自适应学习数据
  final List<double> _historicalMsPerChar = [];
  
  // 动画控制器
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  
  // Mac平台额外延迟（第一性原理：确保TTS完全读完再切换）
  static const int _macExtraDelayMs = 300;
  
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
    
    // 平滑高亮动画控制器 - 驱动整个句子的字符高亮
    // 从0.0到1.0线性变化，用于计算当前高亮位置
    _highlightController = AnimationController(vsync: this);
  }
  
  /// 根据动画进度计算当前高亮字符索引（第一性原理：时间驱动而非回调驱动）
  int _calculateCurrentWordIndex() {
    if (_highlightController == null || _words.isEmpty) return 0;
    
    // 第一性原理：如果 Progress 回调正在工作，信任它的数据
    if (_activeHighlightSource == HighlightSource.progress && _lastProgressWordIndex >= 0) {
      return _lastProgressWordIndex.clamp(0, _words.length - 1);
    }
    
    final progress = _highlightController!.value;
    final index = (progress * _words.length).floor();
    return index.clamp(0, _words.length - 1);
  }

  /// 解析内容：分句
  void _parseContent() {
    _sentences = [];
    
    if (widget.textContent.isEmpty) return;
    
    // 使用标点分句（包含中英文引号、书名号等）
    final parts = widget.textContent.split(RegExp(r'[，。！？、；：""''「」『』【】《》〈〉\n]+'));
    for (final p in parts) {
      final t = p.trim();
      // 过滤掉空白和只包含标点符号的句子
      if (t.isNotEmpty && _hasActualContent(t)) _sentences.add(t);
    }
    
    debugPrint('TTS MV: Parsed ${_sentences.length} sentences');
    if (_sentences.isNotEmpty) {
      _parseWordsForSentence(0);
    }
  }
  
  /// 检查字符串是否包含实际可读内容（第一性原理：正面定义什么是有效内容）
  /// 
  /// 有效内容包括：
  /// - 中文字符（CJK统一表意文字）
  /// - 英文字母
  /// - 数字
  /// 
  /// 这样无论出现什么奇怪的标点都会被过滤，比"排除法"更可靠
  bool _hasActualContent(String text) {
    // 正则匹配有效内容：中文字符 + 字母 + 数字
    // \u4e00-\u9fff: CJK基本统一汉字
    // \u3400-\u4dbf: CJK扩展A
    // a-zA-Z: 英文字母
    // 0-9: 数字
    final validContentRegex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbfa-zA-Z0-9]');
    return validContentRegex.hasMatch(text);
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
      
      // 智能自适应：根据TTS语速计算高亮速度（第一性原理）
      _baseMsPerChar = _ttsManager.calculateMsPerChar();
      _currentMsPerChar = _baseMsPerChar;
      
      // 检测是否需要使用逐句模式
      // Mac平台强制使用逐句模式，因为completion回调不可靠
      if (_ttsManager.isMacOS) {
        _useSentenceMode = true;
      } else {
        _useSentenceMode = _ttsManager.useFallbackOnly;
      }
      
      debugPrint('📱 TTS TextContent: TTS ready | speechRate=${_ttsManager.speechRate} | '
          'msPerChar=${_baseMsPerChar.toStringAsFixed(1)} | '
          'SentenceMode=$_useSentenceMode | ownerId=$_ownerId');
      
      // 不再在初始化后自动开始播放，等待可见性和静音状态检查
      // TTS播放由 _tryStart 方法控制，该方法会检查页面可见性和静音状态
    } catch (e) {
      // 失败时使用保守的默认值
      _baseMsPerChar = 200.0;
      _currentMsPerChar = _baseMsPerChar;
      debugPrint('📱 TTS TextContent: Init error: $e, using default msPerChar=$_baseMsPerChar');
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
          // 进度回调工作，不再使用逐句模式 (Mac除外，Mac强制保留逐句模式以获得停顿)
          if (!_ttsManager.isMacOS) {
            _useSentenceMode = false;
          }
        }
        
        // 使用进度回调更新高亮
        _updateHighlightFromProgress(end, word);
        
        // Mac平台智能检测句子完成：利用Progress回调检测是否读完
        // 注意：依赖原生completion回调，这里只做辅助日志记录
        // 原先这里的智能检测会过早切换下一句，因为：
        // 1. end位置可能在TTS实际读完前就接近文本末尾
        // 2. TTS需要时间完成最后几个字的发音
        // 现在改为等待原生completion回调或超时，不在这里触发切换
        if (_ttsManager.isMacOS && _useSentenceMode && _playing) {
           final currentText = _sentences[_currentSentenceIndex];
           // 仅记录进度，不主动触发完成
           if (end >= currentText.length - 1) {
             debugPrint('📱 TTS (Mac): Progress near end (end=$end, len=${currentText.length}), waiting for completion callback');
           }
        }
      },
      onCompletion: () {
        if (_disposed || !mounted || !_playing) return;
        
        // 捕获当前sessionId用于验证（防止切换视频后旧回调执行）
        final currentSessionId = _playbackSessionId;
        
        final elapsed = _sentenceStopwatch?.elapsedMilliseconds ?? 0;
        debugPrint('📱 TTS 🔔 [${DateTime.now().millisecondsSinceEpoch}] Completion callback received | '
            'sentence=$_currentSentenceIndex | elapsed=${elapsed}ms | '
            'locked=$_sentenceCompleteLock | waiting=$_waitingForCompletion | '
            'sessionId=$currentSessionId');
        
        // 延迟一个微任务执行，获取最新的 sessionId 状态
        Future.microtask(() {
          if (_disposed || !mounted || !_playing) return;
          // 验证 sessionId，防止旧的 completion 回调影响新内容
          if (_playbackSessionId != currentSessionId) {
            debugPrint('📱 TTS ⚠️ Stale completion callback (session $currentSessionId != current $_playbackSessionId), ignoring');
            return;
          }
          
          if (_useSentenceMode) {
            // 逐句模式：句子播放完成
            _onSentenceComplete();
          } else {
            // 全文模式：全部播放完成
            _onPlaybackComplete();
          }
        });
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
      // 锁定到 Progress 模式，停止 AnimationController 驱动
      _activeHighlightSource = HighlightSource.progress;
      _lastProgressWordIndex = estimatedIndex;
      
      // 停止动画控制器以避免竞争
      _highlightController?.stop();
      
      _currentWordIndex = estimatedIndex;
      _pulseController?.forward(from: 0);
      if (mounted) setState(() {});
    }
  }
  
  /// 句子播放完成（逐句模式核心逻辑）
  void _onSentenceComplete() {
    if (_disposed || !mounted || !_playing) return;
    
    // 检查是否已经处理过这句话的完成事件（防止重复触发）
    if (_sentenceCompleteLock) {
      debugPrint('📱 TTS ⚠️ Sentence $_currentSentenceIndex completion already locked, skipping');
      return;
    }
    if (_lastCompletedSentenceIndex == _currentSentenceIndex) {
      debugPrint('📱 TTS ⚠️ Sentence $_currentSentenceIndex already completed, skipping duplicate');
      return;
    }
    
    // 锁定，防止重复触发
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
    
    // 播放下一句
    final nextSentence = _currentSentenceIndex + 1;
    // 捕获当前会话ID，延迟回调中验证（防止切换视频后旧回调执行）
    final sessionId = _playbackSessionId;
    
    if (nextSentence < _sentences.length) {
      // Mac平台额外延迟确保TTS完全读完最后几个字（第一性原理）
      final totalPause = _sentencePauseMs + (_ttsManager.isMacOS ? _macExtraDelayMs : 0);
      debugPrint('📱 TTS ⏸️ Pause ${totalPause}ms before sentence $nextSentence (session=$sessionId)');
      
      Future.delayed(Duration(milliseconds: totalPause), () {
        // 验证会话ID，防止切换视频后旧回调执行
        if (_disposed || !mounted || !_playing) return;
        if (_playbackSessionId != sessionId) {
          debugPrint('📱 TTS ⚠️ Stale callback (session $sessionId != current $_playbackSessionId), ignoring');
          return;
        }
        _playSentence(nextSentence);
      });
    } else {
      // 全部播放完成，循环
      debugPrint('📱 TTS 🔁 All sentences complete, restarting in 800ms (session=$sessionId)');
      Future.delayed(const Duration(milliseconds: 800), () {
        // 验证会话ID，防止切换视频后旧回调执行
        if (_disposed || !mounted || !_playing) return;
        if (_playbackSessionId != sessionId) {
          debugPrint('📱 TTS ⚠️ Stale callback (session $sessionId != current $_playbackSessionId), ignoring');
          return;
        }
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
    
    // 重置句子计时器和锁定状态
    _sentenceStopwatch = Stopwatch()..start();
    _currentWordIndex = 0;
    _waitingForCompletion = true;
    _sentenceCompleteLock = false;  // 新句子开始，解锁完成事件
    
    // 重置状态源（第一性原理：新句子从动画模式开始）
    _activeHighlightSource = HighlightSource.animation;
    _lastProgressWordIndex = -1;
    
    // 播放这个句子
    final sentence = _sentences[sentenceIndex];
    
    debugPrint('📱 TTS 📖 [${DateTime.now().millisecondsSinceEpoch}] Starting sentence $sentenceIndex: "${sentence.substring(0, sentence.length.clamp(0, 20))}..."');
    
    if (mounted) setState(() {});
    
    // 设置超时保护（预期时间的 1.5 倍）
    _startSentenceTimeout(expectedDuration);
    
    // 捕获会话ID用于延迟回调验证
    final sessionId = _playbackSessionId;
    
    // 先调用speak，等待TTS启动后再开始高亮动画
    // Mac TTS启动需要约200-300ms
    await _ttsManager.speak(sentence, _ownerId);
    
    // TTS已开始，延迟一小段时间后启动高亮动画
    // 这确保高亮与实际语音同步
    if (_ttsManager.isMacOS) {
      // Mac平台：等待TTS实际开始后再启动动画
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_disposed || !mounted || !_playing) return;
        if (_playbackSessionId != sessionId) return;
        _startHighlightAnimation();
      });
    } else {
      // 其他平台：立即启动
      _startHighlightAnimation();
    }
  }
  
  /// 启动平滑高亮动画（第一性原理：时间驱动，60fps平滑）
  void _startHighlightAnimation() {
    _stopHighlightAnimation();
    
    if (_words.isEmpty) return;
    
    // 计算动画时长（使用预期句子时长）
    final duration = _calculateExpectedSentenceDuration(_words.length).round();
    
    _highlightController?.duration = Duration(milliseconds: duration);
    _highlightController?.forward(from: 0.0);
    
    debugPrint('📱 TTS 🎬 Started highlight animation: ${duration}ms for ${_words.length} chars');
  }
  
  /// 停止高亮动画（不重置，保持当前位置）
  void _stopHighlightAnimation() {
    _highlightController?.stop();
    // 不调用 reset()，避免高亮跳回第一个字
    // reset 只在 _startHighlightAnimation 中通过 forward(from: 0.0) 隐式完成
  }
  
  // 已删除：_scheduleFallbackWord 方法
  // 已删除：_calculateSpeedFactor 方法
  // 已用 AnimationController 线性动画替代
  // 第一性原理：使用平滑连续动画替代离散Timer调度
  
  /// 计算预期句子总时长
  /// Mac平台：TTS实际时间通常比预估长，需要增加缓冲
  double _calculateExpectedSentenceDuration(int charCount) {
    double baseDuration = charCount * _currentMsPerChar;
    
    // Mac平台：增加1.3x的时长缓冲，确保高亮动画能完整覆盖TTS朗读
    // 第一性原理：宁可高亮稍慢（等待TTS），也不能高亮过快（提前结束）
    if (_ttsManager.isMacOS) {
      baseDuration *= 1.3;
    }
    
    return baseDuration;
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
  
  // _cancelFallbackTimer 已经被 _stopHighlightAnimation 替代
  // 保留空方法以保持向后兼容
  void _cancelFallbackTimer() {
    // 已迁移到 _stopHighlightAnimation()
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
    
    // 生成新的播放会话ID（防止旧回调影响新内容）
    _playbackSessionId++;
    final currentSession = _playbackSessionId;
    debugPrint('📱 TTS 🎬 New playback session: $currentSession');
    
    _playing = true;
    _progressCallbackReceived = false;
    _currentSentenceIndex = 0;
    _currentWordIndex = -1;
    
    // 重置句子完成锁状态（防止旧状态影响新播放）
    _sentenceCompleteLock = false;
    _lastCompletedSentenceIndex = -1;
    _waitingForCompletion = false;
    
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
    _stopHighlightAnimation();
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
      debugPrint('TTS MV: Content changed, invalidating session $_playbackSessionId');
      
      // 先增加 sessionId，使得所有旧的延迟回调失效
      _playbackSessionId++;
      debugPrint('📱 TTS 🔄 Session invalidated, new session: $_playbackSessionId');
      
      _stopPlayback();
      _parseContent();
      _currentSentenceIndex = 0;
      _currentWordIndex = -1;
      
      // 重置所有状态，确保新内容从干净状态开始
      _sentenceCompleteLock = false;
      _lastCompletedSentenceIndex = -1;
      _waitingForCompletion = false;
      
      _historicalMsPerChar.clear();  // 新内容，重置学习数据
      _baseMsPerChar = _ttsManager.calculateMsPerChar();  // 使用语速计算值
      if (widget.isVisible && _sentences.isNotEmpty) {
        // 延迟更长时间，确保旧的 TTS 完全停止
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
    debugPrint('📱 TTS TextContent: Disposing $_ownerId');
    _disposed = true;
    _removeListeners();
    _stopHighlightAnimation();
    _cancelSentenceTimeout();
    _highlightController?.dispose();
    _pulseController?.dispose();
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedBuilder(
              // 第一性原理：合并监听动画，减少重建次数
              animation: Listenable.merge([_pulseAnimation!, _highlightController!]),
              builder: (context, child) {
                // 仅在动画模式时使用动画进度更新高亮（第一性原理：单一状态源）
                if (_activeHighlightSource == HighlightSource.animation) {
                  final newIndex = _calculateCurrentWordIndex();
                  // 只允许前进，不允许后退（防止乱跳）
                  if (newIndex > _currentWordIndex) {
                    _currentWordIndex = newIndex;
                  }
                }
                return _buildKaraokeText();
              },
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildKaraokeText() {
    if (_words.isEmpty) {
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
      children: List.generate(_words.length, (index) {
        final isHighlighted = index == _currentWordIndex;
        final isPast = index < _currentWordIndex;
        final word = _words[index];
        
        double scale = 1.0;
        Color color = Colors.white60;
        
        if (isHighlighted) {
          scale = _pulseAnimation?.value ?? 1.15;
          color = const Color(0xFFFFD700);
        } else if (isPast) {
          color = Colors.white;
        }
        
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              word,
              style: TextStyle(
                fontSize: isHighlighted ? 48 : 42,
                fontWeight: FontWeight.w900,
                color: color,
                shadows: [
                  Shadow(
                    color: isHighlighted ? Colors.orange.withValues(alpha: 0.8) : Colors.black,
                    blurRadius: isHighlighted ? 20 : 8,
                    offset: const Offset(2, 2),
                  ),
                  if (isHighlighted)
                    const Shadow(
                      color: Colors.yellow,
                      blurRadius: 30,
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
