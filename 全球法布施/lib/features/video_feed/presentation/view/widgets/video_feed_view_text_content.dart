import 'package:flutter/material.dart';

class VideoFeedViewTextContent extends StatelessWidget {
  const VideoFeedViewTextContent({
    required this.textContent,
    super.key,
  });

  final String textContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            textContent,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.6,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }
}
