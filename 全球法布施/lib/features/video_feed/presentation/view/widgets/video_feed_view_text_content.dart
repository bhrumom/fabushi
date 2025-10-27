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
    
    final sentences = text.split(RegExp(r'(?<=[。！？])'));
    final List<String> result = [];
    String current = '';
    
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;
      
      if (trimmed.length > 21) {
        if (current.isNotEmpty) result.add(current);
        result.add(trimmed);
        current = '';
      } else if (current.isEmpty) {
        current = trimmed;
      } else if ((current + trimmed).length <= 21) {
        current += trimmed;
      } else {
        result.add(current);
        current = trimmed;
      }
    }
    
    if (current.isNotEmpty) result.add(current);
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
          return GestureDetector(
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
          );
          },
        ),
      ),
    );
  }
}
