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
    
    // 先尝试按双换行符分段
    var paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    
    // 如果分段少于2个，尝试按单换行符分段
    if (paragraphs.length < 2) {
      paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    }
    
    // 如果还是只有1段且内容很长，按句号分段
    if (paragraphs.length == 1 && text.length > 200) {
      paragraphs = text.split(RegExp(r'[。！？]')).where((p) => p.trim().isNotEmpty).map((p) => p.trim()).toList();
    }
    
    return paragraphs.isEmpty ? [''] : paragraphs;
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
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
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
          );
          },
        ),
      ),
    );
  }
}
