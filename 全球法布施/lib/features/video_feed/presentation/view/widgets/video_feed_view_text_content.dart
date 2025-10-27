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
  late List<String> _paragraphs;
  late int _currentIndex;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _paragraphs = _splitIntoParagraphs(widget.textContent);
    _currentIndex = _paragraphs.isEmpty ? 0 : Random().nextInt(_paragraphs.length);
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

  List<String> _splitIntoParagraphs(String text) {
    if (text.isEmpty) return [''];
    
    var lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<String> result = [];
    final headerPattern = RegExp(r'(第\d+部|卷[上中下]|卷第|论卷|经卷|品第)');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // 跳过书名、卷名等标题行
      if (headerPattern.hasMatch(trimmed)) continue;
      
      final sentences = trimmed.split(RegExp(r'(?<=[。！？])'));
      if (sentences.length > 1) {
        String current = '';
        for (final sentence in sentences) {
          final s = sentence.trim();
          if (s.isEmpty) continue;
          
          if (s.length > 21) {
            if (current.isNotEmpty) result.add(current);
            result.add(s);
            current = '';
          } else if (current.isEmpty) {
            current = s;
          } else if ((current + s).length <= 21) {
            current += s;
          } else {
            result.add(current);
            current = s;
          }
        }
        if (current.isNotEmpty) result.add(current);
      } else {
        result.add(trimmed);
      }
    }
    
    return result.isEmpty ? [''] : result;
  }

  @override
  Widget build(BuildContext context) {
    if (_paragraphs.isEmpty) {
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
          itemCount: _paragraphs.length,
          scrollDirection: Axis.horizontal,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
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
                  if (_currentIndex < _paragraphs.length - 1) {
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
                  _pageController.jumpToPage(_paragraphs.length - 1);
                }
              },
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SelectableText(
                      _paragraphs[index],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${index + 1} / ${_paragraphs.length}',
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
