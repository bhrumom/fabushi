import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_overlay_section.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/video_feed_view_text_content.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/recitation_game_widget.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/widgets/reading_game_widget.dart';
import 'package:global_dharma_sharing/models/liked_item.dart';
import 'package:global_dharma_sharing/models/favorite_item.dart';
import 'package:global_dharma_sharing/services/like_service.dart';
import 'package:global_dharma_sharing/services/favorite_service.dart';
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
  final FavoriteService _favoriteService = FavoriteService();
  bool _isLiked = false;
  bool _isFavorited = false;
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
    
    // 初始化收藏服务并获取收藏状态
    _favoriteService.initialize();
    _isFavorited = _favoriteService.isFavorited(widget.videoItem.id);
    _favoriteService.addListener(_updateFavoriteState);
  }

  @override
  void dispose() {
    _likeService.removeListener(_updateLikeState);
    _favoriteService.removeListener(_updateFavoriteState);
    super.dispose();
  }

  void _updateFavoriteState() {
    if (mounted) {
      setState(() {
        _isFavorited = _favoriteService.isFavorited(widget.videoItem.id);
      });
    }
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

  void _handleFavoriteTap() async {
    // 检查登录状态
    final hasAuth = await AuthGuard.check(context);
    if (!hasAuth) return;

    final item = FavoriteItem(
      id: widget.videoItem.id,
      title: widget.videoItem.username, // username 字段存储的是标题
      description: widget.videoItem.description,
      textContent: widget.videoItem.textContent,
      filePath: widget.videoItem.filePath,
      favoritedAt: DateTime.now(),
      contentType: widget.videoItem.contentType == ContentType.video ? 'video' : 'text',
    );

    final wasFavorited = _isFavorited;
    await _favoriteService.toggleFavorite(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasFavorited ? '已取消收藏' : '已收藏'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
    }
  }

  /// 将文本分割成不超过指定字数的片段
  /// 优先在标点符号处分割，否则在指定长度处强制分割
  List<String> _splitTextForRecitation(String text, {int maxLength = 21}) {
    if (text.isEmpty) return [];
    
    // 移除空白字符
    text = text.trim();
    
    // 如果文本短于最大长度，直接返回
    if (text.length <= maxLength) {
      return [text];
    }
    
    final sentences = <String>[];
    int start = 0;
    
    while (start < text.length) {
      int end = start + maxLength;
      
      if (end >= text.length) {
        // 剩余部分不足最大长度
        sentences.add(text.substring(start).trim());
        break;
      }
      
      // 在区间内寻找最佳分割点（标点符号）
      int bestSplit = -1;
      for (int i = end; i > start; i--) {
        final char = text[i - 1];
        // 优先在句号、叹号、问号处分割
        if ('。！？；'.contains(char)) {
          bestSplit = i;
          break;
        }
        // 其次在逗号、顿号处分割
        if ('，、：'.contains(char) && bestSplit == -1) {
          bestSplit = i;
        }
      }
      
      if (bestSplit > start) {
        sentences.add(text.substring(start, bestSplit).trim());
        start = bestSplit;
      } else {
        // 没找到标点，向后扩展搜索直到找到标点
        int forwardSplit = -1;
        for (int i = end; i < text.length; i++) {
          final char = text[i];
          if ('。！？；，、：'.contains(char)) {
            forwardSplit = i + 1;  // 包含标点
            break;
          }
        }
        
        if (forwardSplit > start) {
          sentences.add(text.substring(start, forwardSplit).trim());
          start = forwardSplit;
        } else {
          // 整个剩余文本都没有标点，作为最后一段
          sentences.add(text.substring(start).trim());
          break;
        }
      }
    }
    
    // 过滤空字符串
    return sentences.where((s) => s.isNotEmpty).toList();
  }

  void _handleStartRecitation() {
    // 使用当前段落或完整文本
    final text = _currentParagraph ?? widget.videoItem.textContent ?? '';
    if (text.isEmpty) return;
    
    // 将文本分割成不超过21个字的句子列表
    final sentences = _splitTextForRecitation(text);
    if (sentences.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecitationGameWidget(sentences: sentences),
      ),
    );
  }

  /// 解析文本为句子列表
  List<String> _parseSentences(String text) {
    if (text.isEmpty) return [];
    
    // 按标点符号分割句子
    final sentences = <String>[];
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);
      
      // 识别句子结束标点
      if ('。！？；'.contains(char)) {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        buffer.clear();
      }
    }
    
    // 处理最后可能没有标点的部分
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }
    
    return sentences;
  }

  void _handleStartReading() {
    final textContent = widget.videoItem.textContent ?? '';
    if (textContent.isEmpty) return;
    
    // 使用智能切分，与背诵功能和文本视频保持一致（最大21字，优先在标点处分割）
    final sentences = _splitTextForRecitation(textContent);
    if (sentences.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingGameWidget(
          sentences: sentences,
          contentId: widget.videoItem.id,
          contentTitle: widget.videoItem.description, // Using description as title
          onComplete: (result) {
            // Callback kept for future use if needed
            debugPrint('读诵完成: 音频路径=${result.audioPath}, 时间戳=${result.markers.length}个');
          },
        ),
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
          isBookmarked: _isFavorited,
          isLiked: _isLiked,
          likeCount: _likeCount,
          commentCount: _commentCount,
          shareCount: widget.videoItem.shareCount,
          contentType: widget.videoItem.contentType,
          textContent: widget.videoItem.textContent,
          currentParagraph: _currentParagraph,
          onLikeTap: _handleLikeTap,
          onCommentTap: _handleCommentTap,
          onBookmarkTap: _handleFavoriteTap,
          onStartRecitation: widget.videoItem.contentType == ContentType.text
              ? _handleStartRecitation
              : null,
          onStartReading: widget.videoItem.contentType == ContentType.text
              ? _handleStartReading
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

