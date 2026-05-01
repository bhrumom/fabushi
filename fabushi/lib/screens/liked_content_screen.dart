import 'package:flutter/material.dart';
import '../models/liked_item.dart';
import '../services/like_service.dart';
import 'content_detail_screen.dart';

class LikedContentScreen extends StatefulWidget {
  final bool embed;
  const LikedContentScreen({this.embed = false, super.key});

  @override
  State<LikedContentScreen> createState() => _LikedContentScreenState();
}

class _LikedContentScreenState extends State<LikedContentScreen> {
  final LikeService _likeService = LikeService();

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _likeService,
      builder: (context, _) {
        final likedItems = _likeService.getLikedItems();

        if (likedItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  '还没有喜欢的内容',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  '在法流页面点赞后会显示在这里',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero, // Remove default padding for tab view
          itemCount: likedItems.length,
          itemBuilder: (context, index) {
            final item = likedItems[index];
            return _buildLikedItemCard(item);
          },
        );
      },
    );

    if (widget.embed) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的喜欢'), centerTitle: true),
      body: content,
    );
  }

  Widget _buildLikedItemCard(LikedItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContentDetailScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(item.profileImageUrl),
                onBackgroundImageError: (_, __) {},
                child: item.profileImageUrl.isEmpty
                    ? Text(item.username[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              // 内容信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.contentType == 'video'
                                ? Colors.blue.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.contentType == 'video' ? '视频' : '文本',
                            style: TextStyle(
                              fontSize: 10,
                              color: item.contentType == 'video'
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(item.likedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // 取消点赞按钮
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () async {
                  await _likeService.toggleLike(item);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已取消喜欢'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
