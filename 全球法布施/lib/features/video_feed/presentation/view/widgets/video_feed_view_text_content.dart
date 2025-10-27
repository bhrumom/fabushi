import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class VideoFeedViewTextContent extends StatefulWidget {
  const VideoFeedViewTextContent({
    required this.textContent,
    this.onCurrentParagraphChanged,
    super.key,
  });

  final String textContent;
  final ValueChanged<String>? onCurrentParagraphChanged;

  @override
  State<VideoFeedViewTextContent> createState() => _VideoFeedViewTextContentState();
}

class _VideoFeedViewTextContentState extends State<VideoFeedViewTextContent> {
  int _currentPosition = 0;
  final Map<int, String> _cache = {};
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    if (widget.textContent.isNotEmpty) {
      _currentPosition = Random().nextInt(widget.textContent.length ~/ 2);
      _calculateTotalPages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCurrentParagraphChanged?.call(_getCurrentParagraph());
      });
    }
  }

  void _calculateTotalPages() {
    int pos = 0;
    int count = 0;
    while (pos < widget.textContent.length) {
      final result = _getNextParagraph(pos);
      if (result == null) break;
      count++;
      pos = result.$2;
    }
    _totalPages = count;
  }

  @override
  void dispose() {
    super.dispose();
  }

  (String, int)? _getNextParagraph(int startPos) {
    final text = widget.textContent;
    if (startPos >= text.length) return null;
    
    int pos = startPos;
    while (pos < text.length && (text[pos] == '\n' || text[pos] == ' ')) {
      pos++;
    }
    
    if (pos >= text.length) return null;
    
    String buffer = '';
    int bufferStart = pos;
    
    while (pos < text.length) {
      final sentenceEnd = RegExp(r'[。！？]').firstMatch(text.substring(pos));
      if (sentenceEnd == null) break;
      
      final sentenceEndPos = pos + sentenceEnd.end;
      final sentence = text.substring(pos, sentenceEndPos).trim();
      
      if (sentence.isEmpty || _isMetadataLine(sentence)) {
        pos = sentenceEndPos;
        continue;
      }
      
      if (sentence.length > 21) {
        if (buffer.isEmpty) {
          return (sentence, sentenceEndPos);
        }
        return (buffer, pos);
      }
      
      if (buffer.isEmpty) {
        buffer = sentence;
        bufferStart = pos;
        pos = sentenceEndPos;
      } else if ((buffer + sentence).length <= 21) {
        buffer += sentence;
        pos = sentenceEndPos;
      } else {
        return (buffer, pos);
      }
    }
    
    return buffer.isNotEmpty ? (buffer, pos) : null;
  }

  bool _isMetadataLine(String line) {
    // 1. 部号标题：第XXXX部～...
    if (RegExp(r'^第\d{4}部～').hasMatch(line)) return true;
    
    // 2. 卷数信息：单独一行且包含“卷”且很短（<15字）
    if (line.length < 15 && RegExp(r'(卷[上中下第]|[一二三四五六七八九十百千]+卷$)').hasMatch(line)) return true;
    
    // 3. 译者作者信息：单独一行且包含“造”“译”“撰”“述”且很短（<30字）
    if (line.length < 30 && RegExp(r'[菩萨法师大师尊者].*[造译撰述集注疏释]$').hasMatch(line)) return true;
    
    // 4. 导航链接：上一部/下一部
    if (RegExp(r'^上一部：|下一部：').hasMatch(line)) return true;
    
    // 5. 经名标题：以“佛说”开头且以“经”结尾且很短（<25字）
    if (line.length < 25 && line.startsWith('佛说') && line.endsWith('经')) return true;
    
    return false;
  }

  String _getCurrentParagraph() {
    if (_cache.containsKey(_currentPosition)) {
      return _cache[_currentPosition]!;
    }
    
    final result = _getNextParagraph(_currentPosition);
    if (result == null) return '';
    
    final paragraph = result.$1;
    _cache[_currentPosition] = paragraph;
    if (_cache.length > 5) {
      _cache.remove(_cache.keys.first);
    }
    
    return paragraph;
  }

  void _goNext() {
    final result = _getNextParagraph(_currentPosition);
    if (result != null) {
      setState(() {
        _currentPosition = result.$2;
      });
      widget.onCurrentParagraphChanged?.call(_getCurrentParagraph());
    }
  }

  void _goPrevious() {
    int pos = 0;
    int lastPos = 0;
    
    while (pos < _currentPosition) {
      final result = _getNextParagraph(pos);
      if (result == null || result.$2 >= _currentPosition) break;
      lastPos = pos;
      pos = result.$2;
    }
    
    if (lastPos != _currentPosition) {
      setState(() {
        _currentPosition = lastPos;
      });
      widget.onCurrentParagraphChanged?.call(_getCurrentParagraph());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.textContent.isEmpty) {
      return Container(color: Colors.black);
    }

    final paragraph = _getCurrentParagraph();

    return Container(
      color: Colors.black,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width / 2) {
              _goPrevious();
            } else {
              _goNext();
            }
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    paragraph,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '位置: $_currentPosition',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
