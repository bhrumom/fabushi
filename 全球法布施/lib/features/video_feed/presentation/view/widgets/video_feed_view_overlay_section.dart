import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_interaction_buttons.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_user_info_section.dart';

class VideoFeedViewOverlaySection extends StatelessWidget {
  const VideoFeedViewOverlaySection({
    required this.profileImageUrl,
    required this.username,
    required this.description,
    required this.isBookmarked,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    this.contentType = ContentType.video,
    this.textContent,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final String description;
  final bool isBookmarked;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final ContentType contentType;
  final String? textContent;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: VideoFeedViewUserInfoSection(
              profileImageUrl: profileImageUrl,
              username: username,
              description: description,
              contentType: contentType,
              textContent: textContent,
            ),
          ),
          VideoFeedViewInteractionButtons(
            isLiked: isLiked,
            isBookmarked: isBookmarked,
            likeCount: likeCount,
            commentCount: commentCount,
            shareCount: shareCount,
          ),
        ],
      ),
    );
  }
}
