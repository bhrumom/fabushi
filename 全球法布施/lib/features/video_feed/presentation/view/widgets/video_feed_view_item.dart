import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_overlay_section.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_text_content.dart';
import 'package:video_player/video_player.dart';

class VideoFeedViewItem extends StatefulWidget {
  const VideoFeedViewItem({required this.videoItem, required this.controller, super.key});

  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  @override
  State<VideoFeedViewItem> createState() => _VideoFeedViewItemState();
}

class _VideoFeedViewItemState extends State<VideoFeedViewItem> {
  String? _currentParagraph;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.videoItem.contentType == ContentType.text
            ? VideoFeedViewTextContent(
                textContent: widget.videoItem.textContent ?? '',
                onCurrentParagraphChanged: (paragraph) {
                  setState(() => _currentParagraph = paragraph);
                },
              )
            : VideoFeedViewOptimizedVideoPlayer(controller: widget.controller, videoId: widget.videoItem.id),
        VideoFeedViewOverlaySection(
          profileImageUrl: widget.videoItem.profileImageUrl,
          username: widget.videoItem.username,
          description: widget.videoItem.description,
          isBookmarked: false,
          isLiked: false,
          likeCount: widget.videoItem.likeCount,
          commentCount: widget.videoItem.commentCount,
          shareCount: widget.videoItem.shareCount,
          contentType: widget.videoItem.contentType,
          textContent: widget.videoItem.textContent,
          currentParagraph: _currentParagraph,
        ),
      ],
    );
  }
}
