import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/core/design_system/colors.dart';
import 'package:global_dharma_sharing/core/utils/extensions/context_size_extensions.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_follow_button.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_full_text_reader.dart';

class VideoFeedViewUserHeader extends StatelessWidget {
  const VideoFeedViewUserHeader({
    required this.profileImageUrl,
    required this.username,
    this.contentType = ContentType.video,
    this.textContent,
    this.currentParagraph,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final ContentType contentType;
  final String? textContent;
  final String? currentParagraph;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: context.w(8),
      children: [
        GestureDetector(
          onTap: contentType == ContentType.text && textContent != null
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoFeedViewFullTextReader(
                        bookTitle: username,
                        fullText: textContent!,
                        currentParagraph: currentParagraph,
                      ),
                    ),
                  )
              : null,
          child: CircleAvatar(
            radius: context.sq(20),
            backgroundColor: white.withOpacity(0.2),
            backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
            child: profileImageUrl.isEmpty
                ? Icon(Icons.menu_book, color: white, size: context.sq(20))
                : null,
          ),
        ),
        Flexible(
          child: Text(
            username,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: white,
              fontWeight: FontWeight.bold,
              fontSize: context.fontSize(18),
            ),
          ),
        ),
        const VideoFeedViewFollowButton(),
      ],
    );
  }
}
