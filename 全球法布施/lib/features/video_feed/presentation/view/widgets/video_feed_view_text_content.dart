import 'dart:async';
import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/services/tts_manager.dart';

/// 文字视频内容组件 - MV卡拉OK风格逐字高亮
/// 
/// 特点：
/// - 逐字/逐词高亮，类似MV字幕效果
/// - 当前朗读的字会放大、变色、发光
/// - 平滑的动画过渡效果
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
  String _fullText = '';
  
  // 位置追踪
  List<int> _sentenceStartPositions = [];
  List<int> _sentenceEndPositions = [];
  List<int> _wordStartPositions = [];
  List<int> _wordEndPositions = [];
  
  int _currentSentenceIndex = 0;
  int _currentWordIndex = -1;
  
  // 状态
  bool _playing = false;
  bool _disposed = false;
  bool _ttsInitialized = false;
  
  // 错误重试计数
  int _errorRetryCount = 0;
  static const int _maxErrorRetries = 3;
  
  // Fallback 机制
  Timer? _fallbackTimer;
  bool _progressCallbackReceived = false;
  
  // 时间追踪
  Stopwatch? _playbackStopwatch;
  int _sentenceStartTime = 0;
  
  // 可调参数
  static const int _msPerChar = 130;
  static const int _sentencePauseMs = 300;
  
  // 动画控制器
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  
  // TTS管理器
  final TtsManager _ttsManager = TtsManager();

  @override
  void initState() {
    super.initState();
    _ownerId = 'text_content_${hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('📱 TTS TextContent: Created with ownerId=$_ownerId');
    
    _initAnimations();
    _parseContent();
    _initTts();
  }
  
  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
  }

  /// 解析内容：分句 + 记录位置
  void _parseContent() {
    _sentences = [];
    _sentenceStartPositions = [];
    _sentenceEndPositions = [];
    _fullText = '';
    
    if (widget.textContent.isEmpty) return;
    
    final parts = widget.textContent.split(RegExp(r'[，。！？、；：\n]+'));
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty) _sentences.add(t);
    }
    
    if (_sentences.isEmpty) return;
    
    final buffer = StringBuffer();
    for (int i = 0; i < _sentences.length; i++) {
      _sentenceStartPositions.add(buffer.length);
      buffer.write(_sentences[i]);
      if (i < _sentences.length - 1) {
        buffer.write('，');
      }
      _sentenceEndPositions.add(buffer.length);
    }
    _fullText = buffer.toString();
    
    debugPrint('TTS MV: Parsed ${_sentences.length} sentences, ${_fullText.length} chars total');
    _parseWordsForSentence(0);
  }
  
  void _parseWordsForSentence(int sentenceIndex) {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) return;
    
    final sentence = _sentences[sentenceIndex];
    _words = [];
    _wordStartPositions = [];
    _wordEndPositions = [];
    
    final sentenceStart = _sentenceStartPositions[sentenceIndex];
    
    for (int i = 0; i < sentence.length; i++) {
      final char = sentence[i];
      if (char.trim().isNotEmpty) {
        _words.add(char);
        _wordStartPositions.add(sentenceStart + i);
        _wordEndPositions.add(sentenceStart + i + 1);
      }
    }
    
    debugPrint('TTS MV: Sentence $sentenceIndex has ${_words.length} words');
  }

  Future<void> _initTts() async {
    if (_disposed) return;
    
    try {
      // 初始化全局TTS管理器
      await _ttsManager.initialize();
      _ttsInitialized = true;
      
      debugPrint('📱 TTS TextContent: TTS ready | Visible=${widget.isVisible} | ownerId=$_ownerId');
      
      // 如果当前可见，准备启动
      if (widget.isVisible && _sentences.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_disposed && widget.isVisible && !_playing) {
            debugPrint('📱 TTS TextContent: Post-init starting playback');
            _tryStart();
          }
        });
      }
    } catch (e) {
      debugPrint('📱 TTS TextContent: Init error: $e');
    }
  }
  
  void _registerTtsCallbacks() {
    _ttsManager.registerCallbacks(
      ownerId: _ownerId,
      onProgress: (text, start, end, word) {
        if (_disposed || !mounted || !_playing) return;
        
        final elapsed = _playbackStopwatch?.elapsedMilliseconds ?? 0;
        
        if (!_progressCallbackReceived) {
          _progressCallbackReceived = true;
          _cancelFallbackTimer();
          debugPrint('📱 TTS [${elapsed}ms] ✅ Progress callback WORKING!');
        }
        
        debugPrint('📱 TTS [${elapsed}ms] Progress: pos=$end, word="$word"');
        _updateHighlightFromPosition(end);
      },
      onCompletion: () {
        if (_disposed || !mounted || !_playing) return;
        _onPlaybackComplete();
      },
      onError: (msg) {
        final elapsed = _playbackStopwatch?.elapsedMilliseconds ?? 0;
        debugPrint('📱 TTS [${elapsed}ms] ❌ Error: $msg');
        if (_disposed || !mounted || !_playing) return;
        
        // 检查是否是 -8 错误（TTS引擎忙）
        if (msg.contains('-8')) {
          _errorRetryCount++;
          if (_errorRetryCount >= _maxErrorRetries) {
            debugPrint('📱 TTS: Max retries reached, stopping');
            // 达到最大重试次数，只运行fallback动画，不再尝试TTS
            return;
          }
          // 等待更长时间后重试
          debugPrint('📱 TTS: Retry $_errorRetryCount/$_maxErrorRetries after 2s');
          Future.delayed(const Duration(seconds: 2), () {
            if (_disposed || !mounted || !_playing) return;
            _ttsManager.speak(_fullText, _ownerId);
          });
          return;
        }
        
        // 其他错误正常处理
        _onPlaybackComplete();
      },
    );
  }
  
  void _updateHighlightFromPosition(int position) {
    if (_sentences.isEmpty) return;
    
    int newSentenceIndex = _currentSentenceIndex;
    for (int i = 0; i < _sentenceEndPositions.length; i++) {
      if (position < _sentenceEndPositions[i]) {
        newSentenceIndex = i;
        break;
      }
      if (i == _sentenceEndPositions.length - 1) {
        newSentenceIndex = i;
      }
    }
    
    if (newSentenceIndex != _currentSentenceIndex) {
      debugPrint('TTS MV: Switching to sentence $newSentenceIndex');
      _currentSentenceIndex = newSentenceIndex;
      _parseWordsForSentence(newSentenceIndex);
      _currentWordIndex = -1;
      widget.onCurrentParagraphChanged?.call(_sentences[newSentenceIndex]);
    }
    
    if (_wordEndPositions.isNotEmpty) {
      int newWordIndex = _currentWordIndex;
      for (int i = 0; i < _wordEndPositions.length; i++) {
        if (position <= _wordEndPositions[i] && position >= _wordStartPositions[i]) {
          newWordIndex = i;
          break;
        }
        if (position > _wordEndPositions[i] && i == _wordEndPositions.length - 1) {
          newWordIndex = i;
        }
      }
      
      if (newWordIndex != _currentWordIndex && newWordIndex >= 0) {
        _currentWordIndex = newWordIndex;
        _pulseController?.forward(from: 0);
        debugPrint('TTS MV: Highlighting word $_currentWordIndex: ${_words[_currentWordIndex]}');
      }
    }
    
    if (mounted && !_disposed) {
      setState(() {});
    }
  }
  
  void _startFallbackTimer() {
    _cancelFallbackTimer();
    
    if (!_ttsManager.useFallbackOnly) {
      _progressCallbackReceived = false;
    }
    
    if (_words.isEmpty) return;
    
    final elapsed = _playbackStopwatch?.elapsedMilliseconds ?? 0;
    _sentenceStartTime = elapsed;
    
    final sentenceDuration = _words.length * _msPerChar;
    
    debugPrint('📱 TTS [${elapsed}ms] 📖 SENTENCE $_currentSentenceIndex START | '
        'chars=${_words.length} | expected=${sentenceDuration}ms | '
        'text="${_sentences[_currentSentenceIndex].substring(0, _sentences[_currentSentenceIndex].length.clamp(0, 10))}..."');
    
    _currentWordIndex = 0;
    _pulseController?.forward(from: 0);
    if (mounted) setState(() {});
    
    debugPrint('📱 TTS [${elapsed}ms] 🔤 Word 0/${_words.length}: "${_words[0]}"');
    
    _scheduleFallbackForWord(0);
  }
  
  void _scheduleFallbackForWord(int wordIndex) {
    if (!_ttsManager.useFallbackOnly && _progressCallbackReceived) return;
    if (!_playing || _disposed) return;
    
    _fallbackTimer = Timer(Duration(milliseconds: _msPerChar), () {
      if (_disposed || !mounted || !_playing) return;
      if (!_ttsManager.useFallbackOnly && _progressCallbackReceived) return;
      
      final elapsed = _playbackStopwatch?.elapsedMilliseconds ?? 0;
      final nextWordIndex = wordIndex + 1;
      
      if (nextWordIndex < _words.length) {
        _currentWordIndex = nextWordIndex;
        _pulseController?.forward(from: 0);
        if (mounted) setState(() {});
        
        if (nextWordIndex % 5 == 0 || nextWordIndex == _words.length - 1) {
          debugPrint('📱 TTS [${elapsed}ms] 🔤 Word $nextWordIndex/${_words.length}: "${_words[nextWordIndex]}"');
        }
        
        _scheduleFallbackForWord(nextWordIndex);
      } else {
        final sentenceElapsed = elapsed - _sentenceStartTime;
        debugPrint('📱 TTS [${elapsed}ms] 📖 SENTENCE $_currentSentenceIndex END | '
            'actual=${sentenceElapsed}ms | expected=${_words.length * _msPerChar}ms');
        
        final nextSentence = _currentSentenceIndex + 1;
        if (nextSentence < _sentences.length) {
          debugPrint('📱 TTS [${elapsed}ms] ⏸️ Pause ${_sentencePauseMs}ms before next sentence');
          
          Future.delayed(Duration(milliseconds: _sentencePauseMs), () {
            if (_disposed || !mounted || !_playing) return;
            if (!_ttsManager.useFallbackOnly && _progressCallbackReceived) return;
            
            final pauseElapsed = _playbackStopwatch?.elapsedMilliseconds ?? 0;
            _currentSentenceIndex = nextSentence;
            _parseWordsForSentence(nextSentence);
            _sentenceStartTime = pauseElapsed;
            
            final nextSentenceDuration = _words.length * _msPerChar;
            debugPrint('📱 TTS [${pauseElapsed}ms] 📖 SENTENCE $nextSentence START | '
                'chars=${_words.length} | expected=${nextSentenceDuration}ms | '
                'text="${_sentences[nextSentence].substring(0, _sentences[nextSentence].length.clamp(0, 10))}..."');
            
            _currentWordIndex = 0;
            widget.onCurrentParagraphChanged?.call(_sentences[nextSentence]);
            _pulseController?.forward(from: 0);
            if (mounted) setState(() {});
            
            debugPrint('📱 TTS [${pauseElapsed}ms] 🔤 Word 0/${_words.length}: "${_words[0]}"');
            
            _scheduleFallbackForWord(0);
          });
        } else {
          debugPrint('📱 TTS [${elapsed}ms] 🔚 Last sentence finished, waiting for TTS completion callback');
        }
      }
    });
  }
  
  void _cancelFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _tryStart() {
    if (_disposed || !mounted) return;
    if (!widget.isVisible || _playing || _sentences.isEmpty) return;
    if (!_ttsInitialized) {
      debugPrint('📱 TTS TextContent: TTS not ready yet, will retry');
      Future.delayed(const Duration(milliseconds: 300), _tryStart);
      return;
    }
    
    debugPrint('📱 TTS TextContent: _tryStart called for $_ownerId');
    
    // 初始化计时器
    _playbackStopwatch = Stopwatch()..start();
    
    debugPrint('📱 TTS [0ms] ▶️ PLAYBACK START | '
        'sentences=${_sentences.length} | totalChars=${_fullText.length} | '
        'msPerChar=$_msPerChar | pauseMs=$_sentencePauseMs');
    
    _playing = true;
    _errorRetryCount = 0;  // 重置错误计数
    _currentSentenceIndex = 0;
    _currentWordIndex = -1;
    _parseWordsForSentence(0);
    
    if (mounted && !_disposed) {
      setState(() {});
    }
    
    if (_sentences.isNotEmpty) {
      widget.onCurrentParagraphChanged?.call(_sentences[0]);
    }
    
    // 注册回调
    _registerTtsCallbacks();
    
    // 启动 fallback
    _startFallbackTimer();
    
    // 使用TTS管理器朗读
    _ttsManager.speak(_fullText, _ownerId);
  }
  
  void _onPlaybackComplete() {
    if (_disposed || !mounted || !_playing) return;
    
    final elapsed = _playbackStopwatch?.elapsedMilliseconds ?? 0;
    debugPrint('📱 TTS [${elapsed}ms] 🔁 LOOP RESTART | waiting 800ms');
    
    _cancelFallbackTimer();
    
    _currentSentenceIndex = 0;
    _currentWordIndex = -1;
    _parseWordsForSentence(0);
    
    if (mounted && !_disposed) {
      setState(() {});
    }
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted || !_playing) return;
      
      _playbackStopwatch?.reset();
      _playbackStopwatch?.start();
      _errorRetryCount = 0;  // 重置错误计数
      
      debugPrint('📱 TTS [0ms] ▶️ LOOP PLAYBACK START');
      
      if (_sentences.isNotEmpty) {
        widget.onCurrentParagraphChanged?.call(_sentences[0]);
      }
      
      _startFallbackTimer();
      _ttsManager.speak(_fullText, _ownerId);
    });
  }

  void _stopPlayback() {
    if (!_playing) return;
    debugPrint('📱 TTS TextContent: Stopping playback for $_ownerId');
    _playing = false;
    _cancelFallbackTimer();
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
    _cancelFallbackTimer();
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
              animation: _pulseAnimation!,
              builder: (context, child) {
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
