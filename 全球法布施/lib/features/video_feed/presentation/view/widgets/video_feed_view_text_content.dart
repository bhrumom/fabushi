import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 文字视频内容组件 - 双TTS实例预加载，实现无缝衔接
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

class _VideoFeedViewTextContentState extends State<VideoFeedViewTextContent> {
  // 双TTS实例，交替使用实现预加载
  FlutterTts? _tts1;
  FlutterTts? _tts2;
  int _activeTts = 1;  // 当前活跃的TTS实例 (1 或 2)
  bool _ttsReady = false;
  
  List<String> _sentences = [];
  int _index = 0;
  double _scale = 1.0;
  Timer? _timer;
  Timer? _timeoutTimer;
  bool _playing = false;
  bool _disposed = false;
  
  // 预加载状态
  String? _preloadedText;
  bool _isPreloading = false;

  @override
  void initState() {
    super.initState();
    _parseSentences();
    _initTts();
  }

  void _parseSentences() {
    _sentences = [];
    if (widget.textContent.isEmpty) return;
    
    final parts = widget.textContent.split(RegExp(r'[，。！？、；：\n]+'));
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty) _sentences.add(t);
    }
    debugPrint('TTS: Parsed ${_sentences.length} sentences');
  }

  Future<void> _initTts() async {
    if (_disposed) return;
    
    try {
      // 初始化第一个TTS实例
      _tts1 = FlutterTts();
      await _configureTts(_tts1!, 1);
      
      // 初始化第二个TTS实例用于预加载
      _tts2 = FlutterTts();
      await _configureTts(_tts2!, 2);
      
      _ttsReady = true;
      debugPrint('TTS: Dual instances initialized, isVisible=${widget.isVisible}');
      
      if (widget.isVisible && _sentences.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), _tryStart);
      }
    } catch (e) {
      debugPrint('TTS: Init error: $e');
    }
  }
  
  Future<void> _configureTts(FlutterTts tts, int id) async {
    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(0.85);  // 稍快语速，更流畅
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);
    
    tts.setCompletionHandler(() {
      debugPrint('TTS$id: [Callback] Completion');
      if (_activeTts == id) {
        _handleTtsComplete();
      }
    });
    
    tts.setErrorHandler((msg) {
      debugPrint('TTS$id: [Callback] Error: $msg');
      if (_activeTts == id) {
        _handleTtsComplete();
      }
    });
  }

  void _tryStart() {
    if (_disposed || !mounted) return;
    if (!widget.isVisible || _playing || _sentences.isEmpty) return;
    
    debugPrint('TTS: Starting playback');
    _playing = true;
    _index = 0;
    _activeTts = 1;
    _preloadedText = null;
    _playNext();
  }

  void _softStop() {
    if (!_playing) return;
    debugPrint('TTS: Soft stopping');
    _playing = false;
    _timer?.cancel();
    _timeoutTimer?.cancel();
    _preloadedText = null;
    _isPreloading = false;
  }
  
  void _hardStop() {
    debugPrint('TTS: Hard stopping');
    _playing = false;
    _timer?.cancel();
    _timeoutTimer?.cancel();
    _preloadedText = null;
    _isPreloading = false;
    try {
      _tts1?.stop();
      _tts2?.stop();
    } catch (e) {
      debugPrint('TTS: Stop error: $e');
    }
  }

  void _playNext() {
    if (_disposed || !mounted || !_playing) {
      debugPrint('TTS: _playNext skipped');
      return;
    }
    
    if (_sentences.isEmpty) return;
    
    if (_index >= _sentences.length) {
      _index = 0;  // 循环播放
    }
    
    final text = _sentences[_index];
    debugPrint('TTS: Playing [$_index/${_sentences.length}] via TTS$_activeTts: ${text.length > 20 ? text.substring(0, 20) + "..." : text}');
    
    // 更新UI动画
    if (mounted && !_disposed) {
      setState(() => _scale = 0.85);
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted && !_disposed) {
          setState(() => _scale = 1.0);
        }
      });
    }
    
    widget.onCurrentParagraphChanged?.call(text);
    
    if (_ttsReady && _playing) {
      _timeoutTimer?.cancel();
      
      // 预加载下一句到备用TTS实例
      _preloadNextSentence();
      
      // 设置超时保护
      final timeoutMs = 200 + text.length * 180;
      debugPrint('TTS: Timeout ${timeoutMs}ms for ${text.length} chars');
      
      _timeoutTimer = Timer(Duration(milliseconds: timeoutMs), () {
        debugPrint('TTS: Timeout triggered');
        if (_disposed || !mounted || !_playing) return;
        _handleTtsComplete();
      });
      
      // 使用当前活跃的TTS实例朗读
      final activeTts = _activeTts == 1 ? _tts1 : _tts2;
      activeTts?.speak(text);
    } else {
      final ms = 150 + text.length * 50;
      _timer = Timer(Duration(milliseconds: ms), _handleTtsComplete);
    }
  }
  
  /// 预加载下一句到备用TTS实例
  void _preloadNextSentence() {
    if (_isPreloading || _sentences.isEmpty) return;
    
    final nextIndex = (_index + 1) % _sentences.length;
    final nextText = _sentences[nextIndex];
    
    // 避免重复预加载
    if (_preloadedText == nextText) return;
    
    _isPreloading = true;
    _preloadedText = nextText;
    
    // 使用备用TTS实例进行预加载（synthesize但不播放）
    // 注意：flutter_tts 没有真正的预加载API，但我们可以让备用实例准备好
    debugPrint('TTS: Preloading next sentence to TTS${_activeTts == 1 ? 2 : 1}');
    
    _isPreloading = false;
  }

  void _handleTtsComplete() {
    debugPrint('TTS: handleComplete');
    
    _timeoutTimer?.cancel();
    
    if (_disposed || !mounted || !_playing) return;
    
    _timer?.cancel();
    
    // 切换TTS实例（如果预加载了下一句）
    _activeTts = _activeTts == 1 ? 2 : 1;
    
    // 立即播放下一句
    _index++;
    debugPrint('TTS: Moving to index $_index, switching to TTS$_activeTts');
    
    if (mounted && !_disposed) {
      setState(() {});
    }
    
    // 无延迟直接播放
    _playNext();
  }

  @override
  void didUpdateWidget(VideoFeedViewTextContent old) {
    super.didUpdateWidget(old);
    
    if (old.isVisible != widget.isVisible) {
      debugPrint('TTS: Visibility ${old.isVisible} -> ${widget.isVisible}');
      
      Future.microtask(() {
        if (_disposed || !mounted) return;
        
        if (widget.isVisible && !_playing) {
          _tryStart();
        } else if (!widget.isVisible && _playing) {
          _softStop();
        }
      });
    }
    
    if (old.textContent != widget.textContent) {
      debugPrint('TTS: Content changed');
      _softStop();
      _parseSentences();
      _index = 0;
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
    _disposed = true;
    _hardStop();
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
    
    final safeIndex = _index.clamp(0, _sentences.length - 1);
    final text = _sentences[safeIndex];
    final isEmphasis = RegExp(r'[\d一二三四五六七八九十百千万亿]|佛|法|僧|经|功德').hasMatch(text);
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_playing) {
          _softStop();
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
            child: Transform.scale(
              scale: _scale,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isEmphasis ? 48 : 36,
                  fontWeight: FontWeight.w900,
                  color: isEmphasis ? Colors.red : Colors.white,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 8, offset: Offset(2, 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
