import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class VideoFeedViewTextContent extends StatefulWidget {
  const VideoFeedViewTextContent({
    required this.textContent,
    super.key,
  });

  final String textContent;

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
    
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<int> indices = [];
    final headerPattern = RegExp(r'(第\d+部|卷[上中下]|卷第|论卷|经卷|品第|造|译|撰|述|集|注|疏|释|[一二三四五六七八九十百千]+卷$)');
    
    int charIndex = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        charIndex += line.length + 1;
        continue;
      }
      
      if (headerPattern.hasMatch(trimmed) || 
          trimmed.contains('菩萨') && (trimmed.contains('造') || trimmed.contains('译')) ||
          trimmed.contains('上一部：') || trimmed.contains('下一部：') ||
          trimmed.startsWith('佛说') && trimmed.contains('经')) {
        charIndex += line.length + 1;
        continue;
      }
      
      final sentences = trimmed.split(RegExp(r'(?<=[。！？])'));
      if (sentences.length > 1) {
        int sentenceStart = charIndex;
        String current = '';
        for (final sentence in sentences) {
          final s = sentence.trim();
          if (s.isEmpty) continue;
          
          if (s.length > 21) {
            if (current.isNotEmpty) indices.add(sentenceStart);
            indices.add(sentenceStart);
            sentenceStart += s.length;
            current = '';
          } else if (current.isEmpty) {
            current = s;
          } else if ((current + s).length <= 21) {
            current += s;
          } else {
            indices.add(sentenceStart);
            sentenceStart += current.length;
            current = s;
          }
        }
        if (current.isNotEmpty) indices.add(sentenceStart);
      } else {
        indices.add(charIndex);
      }
      charIndex += line.length + 1;
    }
    
    return indices.isEmpty ? [0] : indices;
  }

  String _getParagraphAt(int index) {
    if (_cachedParagraphs.containsKey(index)) {
      return _cachedParagraphs[index]!;
    }
    
    final text = widget.textContent;
    if (text.isEmpty || index >= _paragraphIndices.length) return '';
    
    final startIdx = _paragraphIndices[index];
    final endIdx = index + 1 < _paragraphIndices.length ? _paragraphIndices[index + 1] : text.length;
    
    final paragraph = text.substring(startIdx, endIdx.clamp(0, text.length)).trim();
    _cachedParagraphs[index] = paragraph;
    
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
          onPageChanged: (index) => setState(() => _currentIndex = index),
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
