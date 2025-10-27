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
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final ContentType contentType;
  final String? textContent;

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
                      ),
                    ),
                  )
              : null,
          child: CircleAvatar(
            radius: context.sq(20),
            backgroundImage: NetworkImage(profileImageUrl),
          ),
        ),
        Text(
          username,
          style: TextStyle(
            color: white,
            fontWeight: FontWeight.bold,
            fontSize: context.fontSize(18),
          ),
        ),
        const VideoFeedViewFollowButton(),
      ],
    );
  }
}
