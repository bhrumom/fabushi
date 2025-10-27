import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/core/utils/extensions/context_size_extensions.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_description_text.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_user_header.dart';

class VideoFeedViewUserInfoSection extends StatelessWidget {
  const VideoFeedViewUserInfoSection({
    required this.profileImageUrl,
    required this.username,
    required this.description,
    this.contentType = ContentType.video,
    this.textContent,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final String description;
  final ContentType contentType;
  final String? textContent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.paddingAll(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: context.h(8),
        children: [
          VideoFeedViewUserHeader(
            profileImageUrl: profileImageUrl,
            username: username,
            contentType: contentType,
            textContent: textContent,
          ),
          VideoFeedViewDescriptionText(text: description),
        ],
      ),
    );
  }
}
