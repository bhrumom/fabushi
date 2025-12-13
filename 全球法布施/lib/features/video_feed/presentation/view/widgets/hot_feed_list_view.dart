import 'package:flutter/material.dart';
import '../../../../../services/feed_service.dart';

/// 热门内容列表（只显示有点赞量的内容）
class HotFeedListView extends StatefulWidget {
  const HotFeedListView({super.key});

  @override
  State<HotFeedListView> createState() => _HotFeedListViewState();
}

class _HotFeedListViewState extends State<HotFeedListView> {
  final FeedService _feedService = FeedService();
  
  List<Map<String, dynamic>> _hotItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHotContent();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreContent();
    }
  }

  Future<void> _loadHotContent() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    try {
      final hotContent = await _feedService.getHotFeed(page: 1, pageSize: 20);
      
      if (mounted) {
        setState(() {
          _hotItems = hotContent;
          _isLoading = false;
          _hasMore = hotContent.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreContent() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final moreContent = await _feedService.getHotFeed(page: _currentPage, pageSize: 20);
      
      if (mounted) {
        setState(() {
          _hotItems.addAll(moreContent);
          _isLoadingMore = false;
          _hasMore = moreContent.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_hotItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('暂无热门内容', style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 8),
            Text('点赞多的内容会出现在这里', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHotContent,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          16, 
          MediaQuery.of(context).padding.top + 60, 
          16, 
          16
        ),
        itemCount: _hotItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _hotItems.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ),
              ),
            );
          }

          final item = _hotItems[index];
          return _buildHotItemCard(item, index);
        },
      ),
    );
  }

  Widget _buildHotItemCard(Map<String, dynamic> item, int index) {
    final contentId = item['id'] ?? '';
    final likeCount = item['like_count'] ?? 0;
    final contentType = item['content_type'] ?? 'text';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: index < 3 
                  ? (index == 0 ? Colors.orange : index == 1 ? Colors.grey[400] : Colors.brown[300])
                  : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: index < 3 ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // 内容信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contentId.length > 30 ? '${contentId.substring(0, 30)}...' : contentId,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  contentType == 'text' ? '文本内容' : '视频内容',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // 点赞数
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 18),
              const SizedBox(width: 4),
              Text(
                '$likeCount',
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
