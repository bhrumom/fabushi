import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/core/design_system/colors.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_interaction_button.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_full_text_reader.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoFeedViewInteractionButtons extends StatefulWidget {
  const VideoFeedViewInteractionButtons({
    required this.isLiked,
    required this.isBookmarked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    this.profileImageUrl = '',
    this.onLikeTap,
    this.onCommentTap,
    this.contentType = ContentType.video,
    this.textContent,
    this.username = '',
    this.currentParagraph,
    super.key,
  });

  final String profileImageUrl;
  final bool isLiked;
  final bool isBookmarked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final ContentType contentType;
  final String? textContent;
  final String username;
  final String? currentParagraph;

  @override
  State<VideoFeedViewInteractionButtons> createState() =>
      _VideoFeedViewInteractionButtonsState();
}

class _VideoFeedViewInteractionButtonsState
    extends State<VideoFeedViewInteractionButtons> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final iconSize = isMobile ? 28.0 : 36.0;
    final avatarSize = isMobile ? 44.0 : 52.0;
    final rightPadding = isMobile ? 8.0 : 12.0;
    final bottomPadding = isMobile ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding, right: rightPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像 + 关注按钮
          _buildAvatarWithFollow(avatarSize, isMobile),
          SizedBox(height: isMobile ? 16 : 20),
          // 点赞
          GestureDetector(
            onTap: widget.onLikeTap,
            child: VideoFeedViewInteractionButton(
              icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
              count: widget.likeCount,
              color: widget.isLiked ? red : white,
              iconSize: iconSize,
              compact: isMobile,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // 评论
          GestureDetector(
            onTap: widget.onCommentTap,
            child: VideoFeedViewInteractionButton(
              icon: LucideIcons.messageCircle,
              count: widget.commentCount,
              iconSize: iconSize,
              compact: isMobile,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // 分享
          VideoFeedViewInteractionButton(
            icon: LucideIcons.send,
            count: widget.shareCount,
            iconSize: iconSize,
            compact: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // 收藏
          Icon(
            widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: white,
            size: iconSize,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithFollow(double avatarSize, bool isMobile) {
    return GestureDetector(
      onTap: widget.contentType == ContentType.text && widget.textContent != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoFeedViewFullTextReader(
                    bookTitle: widget.username,
                    fullText: widget.textContent!,
                    currentParagraph: widget.currentParagraph,
                  ),
                ),
              )
          : null,
      child: SizedBox(
        width: avatarSize,
        height: avatarSize + 12, // 额外空间给+号按钮
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 头像
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: white, width: 2),
              ),
              child: CircleAvatar(
                radius: avatarSize / 2 - 2,
                backgroundColor: white.withValues(alpha: 0.2),
                backgroundImage: widget.profileImageUrl.isNotEmpty
                    ? NetworkImage(widget.profileImageUrl)
                    : null,
                child: widget.profileImageUrl.isEmpty
                    ? Icon(
                        Icons.menu_book,
                        color: white,
                        size: avatarSize * 0.45,
                      )
                    : null,
              ),
            ),
            // +号关注按钮
            if (!_isFollowing)
              Positioned(
                bottom: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isFollowing = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已关注'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
