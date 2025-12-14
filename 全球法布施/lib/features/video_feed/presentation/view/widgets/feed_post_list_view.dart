import 'package:flutter/material.dart';
import '../../../../../models/feed_post_model.dart';
import '../../../../../services/feed_service.dart';
import '../../../../../services/video_title_service.dart';
import '../../../../../features/video_feed/domain/entities/video_entity.dart';
import 'feed_post_card.dart';
import 'comment_bottom_sheet.dart';
import 'video_feed_view_item.dart';

/// 感应/发愿帖子列表视图（朋友圈风格）
class FeedPostListView extends StatefulWidget {
  final String tag; // 'ganying' | 'fayuan'
  
  const FeedPostListView({
    super.key,
    required this.tag,
  });

  @override
  State<FeedPostListView> createState() => _FeedPostListViewState();
}

class _FeedPostListViewState extends State<FeedPostListView> {
  final FeedService _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();
  
  List<FeedPostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    final posts = await _feedService.getTaggedPosts(widget.tag, page: 1);
    
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
        _hasMore = posts.length >= 20;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    final morePosts = await _feedService.getTaggedPosts(widget.tag, page: _currentPage);
    
    if (mounted) {
      setState(() {
        _posts.addAll(morePosts);
        _isLoadingMore = false;
        _hasMore = morePosts.length >= 20;
      });
    }
  }

  /// 点击@原视频标题时跳转到全屏视频并显示评论
  void _navigateToOriginalVideo(FeedPostModel post) {
    if (post.videoId.isEmpty) return;
    
    // 从VideoTitleService获取视频数据
    final videoTitleService = VideoTitleService();
    final videoEntity = videoTitleService.getVideo(post.videoId);
    
    if (videoEntity != null) {
      // 跳转到全屏视频页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _OriginalVideoScreen(
            video: videoEntity,
            autoShowComments: true,
          ),
        ),
      );
    } else {
      // 如果找不到视频数据，直接打开评论
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CommentBottomSheet(videoId: post.videoId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.tag == 'ganying' ? Icons.auto_awesome : Icons.favorite_outline,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              widget.tag == 'ganying' ? '还没有感应分享' : '还没有发愿',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '成为第一个分享的人吧~',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 60, 
          bottom: 80
        ),
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            );
          }

          final post = _posts[index];
          return FeedPostCard(
            post: post,
            onTap: () {
              // 打开帖子详情 - 使用评论底部弹窗
            },
            onAvatarTap: () {
              // TODO: 跳转用户主页
            },
            onLikeTap: () {
              // TODO: 点赞
            },
            onCommentTap: () {
              // TODO: 打开评论
            },
            onOriginalVideoTap: () => _navigateToOriginalVideo(post),
          );
        },
      ),
    );
  }
}

/// 原视频全屏显示页面
class _OriginalVideoScreen extends StatefulWidget {
  final VideoEntity video;
  final bool autoShowComments;

  const _OriginalVideoScreen({
    required this.video,
    this.autoShowComments = true,
  });

  @override
  State<_OriginalVideoScreen> createState() => _OriginalVideoScreenState();
}

class _OriginalVideoScreenState extends State<_OriginalVideoScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟显示评论底部弹窗
    if (widget.autoShowComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => CommentBottomSheet(videoId: widget.video.id),
            );
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 视频/文本内容
          VideoFeedViewItem(
            videoItem: widget.video,
            controller: null, // 将在内部初始化
          ),
          // 返回按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
