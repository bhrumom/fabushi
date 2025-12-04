import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_user_info_section.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_interaction_buttons.dart';

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
    this.currentParagraph,
    this.onLikeTap,
    this.onCommentTap,
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
  final String? currentParagraph;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rightColumnWidth = screenWidth < 600 ? 56.0 : 70.0;

    return RepaintBoundary(
      child: Stack(
        children: [
          // 左下角用户信息区域
          Positioned(
            left: 0,
            right: rightColumnWidth + 8,
            bottom: 0,
            child: VideoFeedViewUserInfoSection(
              username: username,
              description: description,
              contentType: contentType,
              textContent: textContent,
              currentParagraph: currentParagraph,
            ),
          ),
          // 右侧：头像 + 交互按钮
          Positioned(
            right: 0,
            bottom: 0,
            top: 0,
            child: VideoFeedViewInteractionButtons(
              profileImageUrl: profileImageUrl,
              isLiked: isLiked,
              isBookmarked: isBookmarked,
              likeCount: likeCount,
              commentCount: commentCount,
              shareCount: shareCount,
              onLikeTap: onLikeTap,
              onCommentTap: onCommentTap,
              contentType: contentType,
              textContent: textContent,
              username: username,
              currentParagraph: currentParagraph,
            ),
          ),
        ],
      ),
    );
  }
}
