import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/core/design_system/colors.dart';

class VideoFeedViewInteractionButton extends StatelessWidget {
  const VideoFeedViewInteractionButton({
    required this.icon,
    required this.count,
    super.key,
    this.color = white,
    this.iconSize = 36.0,
    this.compact = false,
  });

  final IconData icon;
  final int count;
  final Color color;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: iconSize),
        SizedBox(height: compact ? 2 : 4),
        Text(
          count.toString(),
          style: TextStyle(
            color: white,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
