import 'package:flutter/material.dart';
import '../../../../../models/feed_post_model.dart';
import '../../../../../services/feed_service.dart';
import 'feed_post_card.dart';

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
              // TODO: 打开帖子详情
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
          );
        },
      ),
    );
  }
}
