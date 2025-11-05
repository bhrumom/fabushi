import 'package:flutter/material.dart';

class VideoFeedViewFullTextReader extends StatefulWidget {
  const VideoFeedViewFullTextReader({
    required this.bookTitle,
    required this.fullText,
    this.currentParagraph,
    super.key,
  });

  final String bookTitle;
  final String fullText;
  final String? currentParagraph;

  @override
  State<VideoFeedViewFullTextReader> createState() =>
      _VideoFeedViewFullTextReaderState();
}

class _VideoFeedViewFullTextReaderState
    extends State<VideoFeedViewFullTextReader> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.currentParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlight();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlight() {
    final context = _highlightKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.bookTitle,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: _buildTextWithHighlight(),
      ),
    );
  }

  Widget _buildTextWithHighlight() {
    if (widget.currentParagraph == null || widget.currentParagraph!.isEmpty) {
      return SelectableText(
        widget.fullText,
        style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.6),
      );
    }

    final text = widget.fullText;
    final paragraph = widget.currentParagraph!.trim();
    final index = text.indexOf(paragraph);

    if (index == -1) {
      return SelectableText(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.6),
      );
    }

    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, index),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.6,
            ),
          ),
          WidgetSpan(
            child: Container(
              key: _highlightKey,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                paragraph,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.6,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
          TextSpan(
            text: text.substring(index + paragraph.length),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
