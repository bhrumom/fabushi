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

      // 预加载点赞和评论数据
      if (results.isNotEmpty) {
        final contentIds = results.map((item) => item.filePath).toList();
        await ContentStatsService().fetchContentStats(contentIds);
      }

      setState(() {
        _results = results;
        _currentPage = 0;
      });
      // 搜索后重置 PageView 到第一页
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全文搜索'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '搜索经文内容...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              _search('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: _search,
                  onChanged: (value) {
                    if (value.isEmpty) {
                      _search('');
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('全部'),
                              selected: _selectedCategory == null,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = null;
                                });
                                if (_query.isNotEmpty) {
                                  _search(_query);
                                }
                              },
                            ),
                          );
                        }
                        final category = _categories[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? category : null;
                              });
                              if (_query.isNotEmpty) {
                                _search(_query);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '输入关键词搜索经文内容',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '未找到包含"$_query"的内容',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: PreloadPageView.builder(
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
          // 将 TextItem 转换为 VideoEntity 以便重用 VideoFeedViewItem
          final videoEntity = VideoEntity(
            id: item.filePath, // 使用 filePath 作为统一 ID
            username: item.title,
            description: item.preview ?? '点击头像阅读全文',
            videoUrl: '',
            profileImageUrl: '', // 可以根据需要设置默认头像
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            timestamp: DateTime.now(),
            contentType: ContentType.text,
            textContent: item.content,
            filePath: item.filePath,
          );

          return VideoFeedViewItem(
            key: ValueKey(item.filePath),
            videoItem: videoEntity,
            controller: null, // 文本类型不需要视频控制器
            isVisible: index == _currentPage,
          );
        },
      ),
    );
  }

  void _showContentDialog(TextItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: Text(item.content),
        ),
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
