import 'package:flutter/material.dart';

class VideoFeedViewFullTextReader extends StatelessWidget {
  const VideoFeedViewFullTextReader({
    required this.bookTitle,
    required this.fullText,
    super.key,
  });

  final String bookTitle;
  final String fullText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(bookTitle, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          fullText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
