import 'package:flutter/material.dart';
import '../models/liked_item.dart';
import '../services/like_service.dart';
import '../widgets/report_dialog.dart';

class ContentDetailScreen extends StatefulWidget {
  final LikedItem item;

  const ContentDetailScreen({super.key, required this.item});

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  final LikeService _likeService = LikeService();
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = _likeService.isLiked(widget.item.id);
    _likeService.addListener(_updateLikeState);
  }

  @override
  void dispose() {
    _likeService.removeListener(_updateLikeState);
    super.dispose();
  }

  void _updateLikeState() {
    if (mounted) {
      setState(() => _isLiked = _likeService.isLiked(widget.item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.contentType == 'video' ? '视频详情' : '文本详情'),
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
            color: _isLiked ? Colors.red : null,
            onPressed: () async {
              await _likeService.toggleLike(widget.item);
              if (!_isLiked && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: '举报/屏蔽',
            onPressed: () {
              ReportDialog.show(
                context,
                contentId: widget.item.id,
                authorName: widget.item.username,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: NetworkImage(widget.item.profileImageUrl),
          onBackgroundImageError: (_, __) {},
          child: widget.item.profileImageUrl.isEmpty
              ? Text(widget.item.username[0].toUpperCase())
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(widget.item.likedAt),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (widget.item.contentType == 'text' && widget.item.textContent != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.description,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.item.textContent!,
              style: const TextStyle(
                fontSize: 16,
                height: 1.8,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.item.description, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 64,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '视频内容',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请在法流页面观看',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
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
