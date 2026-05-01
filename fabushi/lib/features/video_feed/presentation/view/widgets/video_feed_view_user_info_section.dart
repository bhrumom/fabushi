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
    this.onStartRecitation,
    this.onStartReading,
    super.key,
  });

  final String username;
  final String description;
  final ContentType contentType;
  final String? textContent;
  final String? currentParagraph;
  final VoidCallback? onStartRecitation;
  final VoidCallback? onStartReading;

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
          // @用户名 + 背诵/读诵按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '@$username',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 15 : 18,
                  ),
                ),
              ),
              // 背诵按钮（仅文字内容显示）
              if (contentType == ContentType.text &&
                  onStartRecitation != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onStartRecitation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '背诵',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // 读诵按钮（仅文字内容显示）
              if (contentType == ContentType.text &&
                  onStartReading != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onStartReading,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '读诵',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          VideoFeedViewDescriptionText(text: description),
        ],
      ),
    );
  }
}
