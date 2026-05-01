import 'package:flutter/material.dart';
import 'package:preload_page_view/preload_page_view.dart';
import '../services/text_search_service.dart';
import '../features/video_feed/domain/entities/video_entity.dart';
import '../features/video_feed/presentation/view/widgets/video_feed_view_item.dart';
import '../services/content_stats_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _searchService = TextSearchService();
  final _pageController = PreloadPageController();
  List<TextItem> _results = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = false;
  String _query = '';
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _searchService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('加载分类失败: $e');
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _query = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _query = query;
    });

    try {
      final results = await _searchService.searchRemote(
        query,
        category: _selectedCategory,
      );

      setState(() {
        _results = results;
        _currentPage = 0;
      });

      // 异步获取点赞和评论数据，不阻塞搜索结果显示
      // 使用 filePath 作为 contentId，与法流视频页面保持一致，确保点赞评论数据同步
      if (results.isNotEmpty) {
        final contentIds = results
            .map(
              (item) => item.filePath.isNotEmpty ? item.filePath : item.title,
            )
            .toList();
        ContentStatsService().fetchContentStats(contentIds).then((_) {
          if (mounted) {
            setState(() {}); // 统计数据加载完成后刷新UI
          }
        });
      }
      // 搜索后重置 PageView 到第一页
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('搜索失败: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: '搜索经文内容',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.cancel,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (value) {
              if (value.isEmpty) {
                _search('');
              }
              setState(() {}); // Update suffix icon visibility
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _search(_controller.text),
            child: const Text(
              '搜索',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    if (_query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              '搜索你感兴趣的内容',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: 80,
              color: Colors.grey[800],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无内容，换个词试试',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return PreloadPageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _results.length,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemBuilder: (context, index) {
        final item = _results[index];
        // 使用 filePath 作为 id，与 ContentStatsService 的 contentId 保持一致
        final contentId = item.filePath.isNotEmpty ? item.filePath : item.title;
        final videoEntity = VideoEntity(
          id: contentId, // 使用 filePath 作为 contentId，与法流视频一致
          username: item.title,
          description: item.preview ?? '点击头像阅读全文',
          videoUrl: '',
          profileImageUrl: '',
          likeCount: ContentStatsService().getLikeCount(contentId),
          commentCount: ContentStatsService().getCommentCount(contentId),
          shareCount: 0,
          timestamp: DateTime.now(),
          contentType: ContentType.text,
          textContent: item.content,
          filePath: item.filePath,
        );

        return VideoFeedViewItem(
          key: ValueKey(item.filePath),
          videoItem: videoEntity,
          controller: null,
          isVisible: index == _currentPage,
        );
      },
    );
  }

  void _showContentDialog(TextItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(child: Text(item.content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
