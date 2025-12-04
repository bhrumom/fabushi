import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/core/design_system/colors.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_description_text.dart';

class VideoFeedViewUserInfoSection extends StatelessWidget {
  const VideoFeedViewUserInfoSection({
    required this.username,
    required this.description,
    this.contentType = ContentType.video,
    this.textContent,
    this.currentParagraph,
    super.key,
  });

  final String username;
  final String description;
  final ContentType contentType;
  final String? textContent;
  final String? currentParagraph;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // @用户名 - 支持换行显示
          Text(
            '@$username',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 15 : 18,
            ),
          ),
          const SizedBox(height: 8),
          VideoFeedViewDescriptionText(text: description),
        ],
      ),
    );
  }
}
