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
  late List<int> _paragraphIndices;
  late int _currentIndex;
  final PageController _pageController = PageController();
  final Map<int, String> _cachedParagraphs = {};

  @override
  void initState() {
    super.initState();
    _paragraphIndices = _buildParagraphIndices(widget.textContent);
    _currentIndex = _paragraphIndices.isEmpty ? 0 : Random().nextInt(_paragraphIndices.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<int> _buildParagraphIndices(String text) {
    if (text.isEmpty) return [0];
    
    final List<int> indices = [];
    final List<String> sentences = [];
    
    // 提取所有有效句子
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // 跳过逻辑：只跳过明确的元数据行
      if (_isMetadataLine(trimmed)) continue;
      
      // 检查是否有标点符号
      if (RegExp(r'[。！？]').hasMatch(trimmed)) {
        // 按句号、感叹号、问号切分句子
        final parts = trimmed.split(RegExp(r'(?<=[。！？])'));
        for (final part in parts) {
          final s = part.trim();
          if (s.isNotEmpty) sentences.add(s);
        }
      } else {
        // 没有标点，整行作为一个片段
        sentences.add(trimmed);
      }
    }
    
    // 构建索引：合并句子直到超过21字，或单句超过21字则独立
    int searchPos = 0;
    String buffer = '';
    int bufferStartPos = 0;
    
    for (final sentence in sentences) {
      final pos = text.indexOf(sentence, searchPos);
      if (pos == -1) continue;
      
      if (sentence.length > 21) {
        // 单句超过21字
        if (buffer.isNotEmpty) {
          indices.add(bufferStartPos);
          buffer = '';
        }
        indices.add(pos);
        searchPos = pos + sentence.length;
      } else if (buffer.isEmpty) {
        // 开始新片段
        buffer = sentence;
        bufferStartPos = pos;
        searchPos = pos + sentence.length;
      } else if ((buffer + sentence).length <= 21) {
        // 合并
        buffer += sentence;
        searchPos = pos + sentence.length;
      } else {
        // 保存buffer，开始新片段
        indices.add(bufferStartPos);
        buffer = sentence;
        bufferStartPos = pos;
        searchPos = pos + sentence.length;
      }
    }
    
    // 保存最后buffer
    if (buffer.isNotEmpty) {
      indices.add(bufferStartPos);
    }
    
    return indices.isEmpty ? [0] : indices;
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

  String _getParagraphAt(int index) {
    if (_cachedParagraphs.containsKey(index)) {
      return _cachedParagraphs[index]!;
    }
    
    final text = widget.textContent;
    if (text.isEmpty || index >= _paragraphIndices.length) return '';
    
    final startIdx = _paragraphIndices[index];
    String paragraph;
    
    if (index + 1 < _paragraphIndices.length) {
      final endIdx = _paragraphIndices[index + 1];
      paragraph = text.substring(startIdx, endIdx).trim();
    } else {
      // 最后一个片段，找到下一个句号结束
      final remaining = text.substring(startIdx);
      final match = RegExp(r'[^。！？]*[。！？]').firstMatch(remaining);
      paragraph = match != null ? match.group(0)!.trim() : remaining.trim();
    }
    
    _cachedParagraphs[index] = paragraph;
    
    // 智能缓存管理
    if (_cachedParagraphs.length > 10) {
      final keysToRemove = _cachedParagraphs.keys.where((k) => (k - index).abs() > 5).toList();
      for (final key in keysToRemove) {
        _cachedParagraphs.remove(key);
      }
    }
    
    return paragraph;
  }

  @override
  Widget build(BuildContext context) {
    if (_paragraphIndices.isEmpty) {
      return Container(color: Colors.black);
    }

    return Container(
      color: Colors.black,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          },
        ),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _paragraphIndices.length,
          scrollDirection: Axis.horizontal,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            final paragraph = _getParagraphAt(index);
            widget.onCurrentParagraphChanged?.call(paragraph);
          },
          itemBuilder: (context, index) {
            final paragraph = _getParagraphAt(index);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < width / 2) {
                  if (_currentIndex > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                } else {
                  if (_currentIndex < _paragraphIndices.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              onDoubleTapDown: (details) {
                final width = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < width / 2) {
                  _pageController.jumpToPage(0);
                } else {
                  _pageController.jumpToPage(_paragraphIndices.length - 1);
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
                      '${index + 1} / ${_paragraphIndices.length}',
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
          );
          },
        ),
      ),
    );
  }
}
