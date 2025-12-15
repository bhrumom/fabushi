import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 文字视频内容组件 - 强调型卡点字幕效果
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
  FlutterTts? _tts;
  bool _ttsReady = false;
  
  List<String> _sentences = [];
  int _index = 0;
  int _speakingIndex = -1;  // 当前正在朗读的句子索引，用于防止重复处理
  double _scale = 1.0;
  Timer? _timer;
  bool _playing = false;
  bool _disposed = false;

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
      _tts = FlutterTts();
      await _tts?.setLanguage('zh-CN');
      await _tts?.setSpeechRate(0.7);
      await _tts?.setVolume(1.0);
      
      // 设置为 false 让 speak() 立即返回，回调驱动下一句
      await _tts?.awaitSpeakCompletion(false);
      
      _tts?.setCompletionHandler(() {
        debugPrint('TTS: [Callback] Completion, speakingIndex=$_speakingIndex, index=$_index');
        _onSpeakComplete();
      });
      
      _tts?.setErrorHandler((msg) {
        debugPrint('TTS: [Callback] Error: $msg');
        _onSpeakComplete();
      });
      
      _ttsReady = true;
      debugPrint('TTS: Initialized, isVisible=${widget.isVisible}');
      
      if (widget.isVisible && _sentences.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), _tryStart);
      }
    } catch (e) {
      debugPrint('TTS: Init error: $e');
    }
  }

  void _tryStart() {
    if (_disposed || !mounted) return;
    if (!widget.isVisible || _playing || _sentences.isEmpty) return;
    
    debugPrint('TTS: Starting playback');
    _playing = true;
    _index = 0;
    _speakingIndex = -1;
    _playNext();
  }

  // 软停止：只设置标志，不调用 TTS stop（避免影响其他页面）
  void _softStop() {
    if (!_playing) return;
    debugPrint('TTS: Soft stopping (flag only)');
    _playing = false;
    _speakingIndex = -1;
    _timer?.cancel();
  }
  
  // 硬停止：在 dispose 时使用，会调用 TTS stop
  void _hardStop() {
    debugPrint('TTS: Hard stopping');
    _playing = false;
    _speakingIndex = -1;
    _timer?.cancel();
    try {
      _tts?.stop();
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
      _index = 0;
    }
    
    final text = _sentences[_index];
    _speakingIndex = _index;  // 记录当前正在朗读的句子索引
    
    debugPrint('TTS: Playing [$_index/${_sentences.length}]: ${text.length > 30 ? text.substring(0, 30) + "..." : text}');
    
    // 更新UI
    if (mounted && !_disposed) {
      setState(() => _scale = 0.8);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_disposed) {
          setState(() => _scale = 1.0);
        }
      });
    }
    
    widget.onCurrentParagraphChanged?.call(text);
    
    if (_ttsReady && _playing) {
      _tts?.speak(text);
    } else {
      // TTS不可用时使用计时器模拟
      final ms = 500 + text.length * 80;
      _timer = Timer(Duration(milliseconds: ms), _onSpeakComplete);
    }
  }

  void _onSpeakComplete() {
    // 检查是否是当前句子的完成回调（防止旧回调干扰）
    if (_speakingIndex != _index) {
      debugPrint('TTS: Ignoring stale callback (speakingIndex=$_speakingIndex, index=$_index)');
      return;
    }
    
    debugPrint('TTS: onSpeakComplete, playing=$_playing, index=$_index');
    
    if (_disposed || !mounted || !_playing) return;
    
    _timer?.cancel();
    
    // 立即播放下一句
    _index++;
    debugPrint('TTS: Moving to index $_index');
    
    if (mounted && !_disposed) {
      setState(() {});
    }
    
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
          _softStop();  // 使用软停止
        }
      });
    }
    
    if (old.textContent != widget.textContent) {
      debugPrint('TTS: Content changed');
      _softStop();  // 使用软停止
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
    _hardStop();  // dispose 时使用硬停止
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
