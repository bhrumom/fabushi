import 'dart:math';
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
  static int _currentPage = 1;
  late String _text;

  @override
  void initState() {
    super.initState();
    if (widget.textContent.isNotEmpty) {
      _text = widget.textContent;
      _currentPosition = _findValidStartPosition(Random().nextInt(max(_text.length - 100, 1)));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCurrentParagraphChanged?.call(_getCurrentParagraph());
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoFeedViewTextContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textContent != oldWidget.textContent) {
      setState(() {
        _text = widget.textContent;
        _cache.clear();
        final randomPos = Random().nextInt(max(_text.length - 100, 1));
        _currentPosition = _findValidStartPosition(randomPos);
        _currentPage = Random().nextInt(9999) + 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCurrentParagraphChanged?.call(_getCurrentParagraph());
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  int _findValidStartPosition(int randomPos) {
    if (randomPos == 0) return 0;
    
    int pos = 0;
    int lastValidPos = 0;
    
    while (pos < randomPos && pos < _text.length) {
      final result = _getNextParagraph(pos);
      if (result == null) break;
      lastValidPos = result.$2;
      pos = result.$3;
    }
    
    return lastValidPos;
  }

  (String, int, int)? _getNextParagraph(int startPos) {
    if (startPos >= _text.length) return null;

    int pos = startPos;

    // 跳过空白字符和标点符号
    while (pos < _text.length &&
        RegExp(
          r'[\s""'
          '「」『』（）()、，,]',
        ).hasMatch(_text[pos])) {
      pos++;
    }

    if (pos >= _text.length) return null;

    String buffer = '';
    final contentStart = pos;

    while (pos < _text.length) {
      final lineEnd = _text.indexOf('\n', pos);
      final hasLineBreak = lineEnd != -1;
      final lineEndPos = hasLineBreak ? lineEnd : _text.length;
      final currentLine = _text.substring(pos, lineEndPos).trim();

      if (currentLine.isNotEmpty && _isMetadataLine(currentLine)) {
        pos = hasLineBreak ? lineEnd + 1 : _text.length;
        continue;
      }

      final sentenceEnd = RegExp(
        r'[。！？；：、，][""'
        '」』）)]*',
      ).firstMatch(_text.substring(pos));
      final sentenceEndInLine = sentenceEnd != null && (pos + sentenceEnd.end) <= lineEndPos;

      if (!sentenceEndInLine) {
        if (currentLine.isEmpty) {
          pos = hasLineBreak ? lineEnd + 1 : _text.length;
          continue;
        }

        if (buffer.isEmpty) {
          return (currentLine, contentStart, hasLineBreak ? lineEnd + 1 : _text.length);
        }

        if ((buffer + currentLine).length <= 21) {
          return (buffer + currentLine, contentStart, hasLineBreak ? lineEnd + 1 : _text.length);
        }
        return (buffer, contentStart, pos);
      }

      final sentenceEndPos = pos + sentenceEnd.end;
      final sentence = _text
          .substring(pos, sentenceEndPos)
          .trim()
          .replaceAll(
            RegExp(
              r'^[""'
              '「」『』（）(),、，\s]+',
            ),
            '',
          );

      if (sentence.isEmpty || sentence.length < 2) {
        pos = sentenceEndPos;
        continue;
      }

      if (sentence.length > 21) {
        if (buffer.isEmpty) {
          return (sentence, contentStart, sentenceEndPos);
        }
        return (buffer, contentStart, pos);
      }

      if (buffer.isEmpty) {
        buffer = sentence;
        pos = sentenceEndPos;
      } else if ((buffer + sentence).length <= 21) {
        buffer += sentence;
        pos = sentenceEndPos;
      } else {
        return (buffer, contentStart, pos);
      }
    }

    return buffer.isNotEmpty ? (buffer, contentStart, pos) : null;
  }

  bool _isMetadataLine(String line) {
    // 1. 部号标题：第XXXX部～...
    if (RegExp(r'^第\d{4}部～').hasMatch(line)) return true;

    // 2. 卷数信息：单独一行且包含“卷”且很短（<15字）
    if (line.length < 15 && RegExp(r'(卷[上中下第]|[一二三四五六七八九十百千]+卷$)').hasMatch(line)) return true;

    // 3. 译者作者信息：单独一行且包含“造”“译”“撰”“述”且很短（<30字）
    if (line.length < 30 &&
        !RegExp(r'^(夫|如是我闻|尔时|佛告|世尊|一时)').hasMatch(line) &&
        RegExp(r'[菩萨法师大师尊者].*[造译撰述集注疏释]$').hasMatch(line))
      return true;

    // 4. 导航链接：上一部/下一部
    if (RegExp(r'^上一部：|下一部：').hasMatch(line)) return true;

    // 5. 经名标题：以“佛说”开头且以“经”结尾且很短（<25字）
    if (line.length < 20 && line.startsWith('佛说') && line.endsWith('经') && !line.contains('。'))
      return true;

    return false;
  }

  String _getCurrentParagraph() {
    if (_cache.containsKey(_currentPosition)) {
      return _cache[_currentPosition]!;
    }

    final result = _getNextParagraph(_currentPosition);
    if (result == null) {
      print('⚠️ No paragraph at position $_currentPosition');
      return '';
    }

    final paragraph = result.$1;
    print(
      '📄 Paragraph at $_currentPosition: ${paragraph.substring(0, paragraph.length > 20 ? 20 : paragraph.length)}...',
    );
    _cache[_currentPosition] = paragraph;
    if (_cache.length > 5) {
      _cache.remove(_cache.keys.first);
    }

    return paragraph;
  }

  void _goNext() {
    final result = _getNextParagraph(_currentPosition);
    if (result != null && result.$3 < _text.length) {
      setState(() {
        _currentPosition = result.$3;
        _currentPage++;
      });
      widget.onCurrentParagraphChanged?.call(_getCurrentParagraph());
    }
  }

  void _goPrevious() {
    int pos = 0;
    int lastPos = 0;
    int secondLastPos = 0;

    // 遍历所有段落，找到当前位置之前的最后一个段落
    while (pos < _currentPosition) {
      final result = _getNextParagraph(pos);
      if (result == null) break;
      
      // 如果下一个段落的起始位置已经到达或超过当前位置，停止
      if (result.$2 >= _currentPosition) break;
      
      // 保存前两个位置
      secondLastPos = lastPos;
      lastPos = result.$2;
      pos = result.$3;
    }

    // 如果找到了前一个段落，切换到它
    if (lastPos != _currentPosition && lastPos > 0) {
      setState(() {
        _currentPosition = lastPos;
        _currentPage--;
      });
      widget.onCurrentParagraphChanged?.call(_getCurrentParagraph());
    } else if (secondLastPos > 0 && secondLastPos != _currentPosition) {
      // 如果lastPos等于当前位置，使用secondLastPos
      setState(() {
        _currentPosition = secondLastPos;
        _currentPage--;
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
    // 计算当前页在5个点中的位置（循环显示）
    final dotIndex = (_currentPage - 1) % 5;

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
          child: Stack(
            children: [
              // 文本内容
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText(
                    paragraph,
                    style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.6),
                  ),
                ),
              ),
              // 底部页面指示点
              Positioned(
                left: 0,
                right: 0,
                bottom: 100, // 在用户信息上方
                child: _buildPageIndicator(dotIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建页面指示点（类似抖音图片轮播）
  Widget _buildPageIndicator(int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
