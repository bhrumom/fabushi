import 'package:flutter/material.dart';
import '../../../../../models/feed_post_model.dart';
import '../../../../../core/design_system/app_theme.dart';
import '../../../../../services/video_title_service.dart';

/// 感应/发愿帖子卡片（朋友圈风格）
class FeedPostCard extends StatelessWidget {
  final FeedPostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onOriginalVideoTap; // 点击@原视频标题的回调
  final bool isLiked;

  const FeedPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAvatarTap,
    this.onLikeTap,
    this.onCommentTap,
    this.onOriginalVideoTap,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息行
            _buildUserHeader(),
            const SizedBox(height: 12),
            
            // 帖子内容
            Text(
              post.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            
            // 原视频链接（单独一行，显示在内容下方）
            if (post.videoId.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildOriginalVideoLink(),
            ],
            
            const SizedBox(height: 12),
            
            // 底部操作栏
            _buildActionBar(),
          ],
        ),
      ),
    );
  }
  
  /// 构建原视频链接（单独一行）
  Widget _buildOriginalVideoLink() {
    // 提取可读标题
    String displayTitle = _extractDisplayTitle(post.videoId, post.videoTitle);
    
    return GestureDetector(
      onTap: onOriginalVideoTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline, color: AppTheme.primaryColor, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '@$displayTitle',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 从 videoId 提取可读的显示标题
  String _extractDisplayTitle(String videoId, String? videoTitle) {
    // 首先尝试从VideoTitleService获取真实标题
    final cachedTitle = VideoTitleService().getVideoTitle(videoId);
    if (cachedTitle != null && cachedTitle.isNotEmpty) {
      return cachedTitle;
    }
    
    // 如果API已提供标题且不是原始ID格式，直接使用
    if (videoTitle != null && videoTitle.isNotEmpty) {
      if (!RegExp(r'^(text|video)[\s_-]?\d+').hasMatch(videoTitle)) {
        return videoTitle;
      }
    }
    
    if (videoId.isEmpty) return '原视频';
    
    // 如果是路径格式，提取文件名
    String contentId = videoId;
    if (contentId.contains('/')) {
      final parts = contentId.split('/');
      contentId = parts.last;
    }
    
    // 去掉扩展名
    if (contentId.contains('.')) {
      contentId = contentId.substring(0, contentId.lastIndexOf('.'));
    }
    
    // 替换下划线和横杠为空格
    String title = contentId.replaceAll(RegExp(r'[_-]'), ' ').trim();
    
    // 如果是纯数字ID格式如 "text 1764818600612 1"，返回更友好的名称
    if (RegExp(r'^(text|video)\s+\d+').hasMatch(title)) {
      return '法布施内容';
    }
    
    // 首字母大写
    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }
    
    return title.isEmpty ? '法布施内容' : title;
  }

  Widget _buildUserHeader() {
    return Row(
      children: [
        // 头像
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[800],
            backgroundImage: post.avatar != null ? NetworkImage(post.avatar!) : null,
            child: post.avatar == null
                ? Text(
                    (post.displayName.isNotEmpty ? post.displayName[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        
        // 用户名和时间
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: post.isGanying 
                          ? Colors.orange.withOpacity(0.2) 
                          : Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      post.tagDisplayName,
                      style: TextStyle(
                        color: post.isGanying ? Colors.orange : Colors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(post.createdAt),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        // 点赞
        GestureDetector(
          onTap: onLikeTap,
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.white54,
                size: 20,
              ),
              if (post.likeCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 24),
        
        // 评论
        GestureDetector(
          onTap: onCommentTap,
          child: const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: Colors.white54, size: 20),
              SizedBox(width: 4),
              Text('评论', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}
