import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_overlay_section.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_text_content.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/recitation_game_widget.dart';
import 'package:global_dharma_sharing/models/liked_item.dart';
import 'package:global_dharma_sharing/services/like_service.dart';
import 'package:global_dharma_sharing/services/content_stats_service.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/comment_bottom_sheet.dart';
import 'package:global_dharma_sharing/core/utils/auth_guard.dart';
import 'package:video_player/video_player.dart';

class VideoFeedViewItem extends StatefulWidget {
  const VideoFeedViewItem({
    required this.videoItem,
    required this.controller,
    this.isVisible = false,
    super.key,
  });

  final VideoEntity videoItem;
  final VideoPlayerController? controller;
  final bool isVisible;

  @override
  State<VideoFeedViewItem> createState() => _VideoFeedViewItemState();
}

class _VideoFeedViewItemState extends State<VideoFeedViewItem> {
  String? _currentParagraph;
  final LikeService _likeService = LikeService();
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _likeService.initialize();
    
    // 从缓存获取点赞数
    _isLiked = _likeService.isLiked(widget.videoItem.id);
    _likeCount = ContentStatsService().getLikeCount(widget.videoItem.id);
    if (_likeCount == 0) {
      _likeCount = _likeService.getLikeCount(widget.videoItem.id);
    }
    if (_likeCount == 0) {
      _likeCount = widget.videoItem.likeCount;
    }
    
    // 从缓存获取评论数
    _commentCount = ContentStatsService().getCommentCount(widget.videoItem.id);
    if (_commentCount == 0) {
      _commentCount = widget.videoItem.commentCount;
    }
    
    _likeService.addListener(_updateLikeState);
  }

  @override
  void dispose() {
    _likeService.removeListener(_updateLikeState);
    super.dispose();
  }

  void _updateLikeState() {
    if (mounted) {
      setState(() {
        _isLiked = _likeService.isLiked(widget.videoItem.id);
        _likeCount = _likeService.getLikeCount(widget.videoItem.id);
      });
    }
  }

  void _handleLikeTap() async {
    // 检查登录状态
    final hasAuth = await AuthGuard.check(context);
    if (!hasAuth) return;

    final item = LikedItem(
      id: widget.videoItem.id,
      username: widget.videoItem.username,
      description: widget.videoItem.description,
      videoUrl: widget.videoItem.contentType == ContentType.video
          ? widget.videoItem.videoUrl
          : null,
      textContent: widget.videoItem.textContent,
      profileImageUrl: widget.videoItem.profileImageUrl,
      likedAt: DateTime.now(),
      contentType: widget.videoItem.contentType == ContentType.video ? 'video' : 'text',
      filePath: widget.videoItem.filePath,  // 传递文件路径
    );

    await _likeService.toggleLike(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLiked ? '已添加到喜欢' : '已取消喜欢'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
    }
  }

  void _handleStartRecitation() {
    // 使用当前段落或完整文本
    final sentence = _currentParagraph ?? widget.videoItem.textContent ?? '';
    if (sentence.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecitationGameWidget(sentence: sentence),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.videoItem.contentType == ContentType.text
            ? VideoFeedViewTextContent(
                textContent: widget.videoItem.textContent ?? '',
                isVisible: widget.isVisible,
                onCurrentParagraphChanged: (paragraph) {
                  if (mounted) {
                    setState(() => _currentParagraph = paragraph);
                  }
                },
              )
            : VideoFeedViewOptimizedVideoPlayer(
                controller: widget.controller,
                videoId: widget.videoItem.id,
              ),
        VideoFeedViewOverlaySection(
          profileImageUrl: widget.videoItem.profileImageUrl,
          username: widget.videoItem.username,
          description: widget.videoItem.description,
          isBookmarked: false,
          isLiked: _isLiked,
          likeCount: _likeCount,
          commentCount: _commentCount,
          shareCount: widget.videoItem.shareCount,
          contentType: widget.videoItem.contentType,
          textContent: widget.videoItem.textContent,
          currentParagraph: _currentParagraph,
          onLikeTap: _handleLikeTap,
          onCommentTap: _handleCommentTap,
          onStartRecitation: widget.videoItem.contentType == ContentType.text
              ? _handleStartRecitation
              : null,
        ),
      ],
    );
  }

  void _handleCommentTap() async {
    // 抖音风格：查看评论通常不需要登录，但如果是为了发表评论，发表时会检查
    // 如果用户希望"任何操作"都弹出登录，那么点击评论按钮也可以弹出
    // 不过通常点击按钮弹出底栏，发表时弹出登录更流畅
    // 按照用户要求"任何同步云端的操作"，查看评论不是同步云端（是读取），执行点赞/发表评论是同步。
    // 但是用户说"就像抖音app一样"，抖音点赞会跳登录，点评论按钮看评论是允许的。
    // 所以这里我让点击评论按钮直接显示底栏。
    // 但我会修改 CommentBottomSheet 里的发表逻辑。
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        videoId: widget.videoItem.id,
        videoTitle: widget.videoItem.username, // username 字段存储的是视频标题
        filePath: widget.videoItem.id, // 使用 id 作为统一的内容ID
        onCommentPosted: () {
          if (mounted) {
            setState(() {
              _commentCount++;
            });
          }
        },
      ),
    );
  }
}

