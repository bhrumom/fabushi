import 'package:flutter/material.dart';
import '../services/text_search_service.dart';

/// 搜索功能使用示例
class SearchExample extends StatefulWidget {
  const SearchExample({Key? key}) : super(key: key);

  @override
  State<SearchExample> createState() => _SearchExampleState();
}

class _SearchExampleState extends State<SearchExample> {
  final TextSearchService _searchService = TextSearchService();
  final TextEditingController _searchController = TextEditingController();
  List<TextItem> _results = [];
  bool _isLoading = false;
  bool _isIndexed = false;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
  }

  Future<void> _initializeSearch() async {
    setState(() => _isLoading = true);
    await _searchService.indexAssets();
    setState(() {
      _isLoading = false;
      _isIndexed = true;
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    // 使用远程搜索（基于drift数据库）
    final results = await _searchService.search(query, limit: 50);

    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  Future<void> _indexToRemote() async {
    setState(() => _isLoading = true);

    final success = await _searchService.indexToRemote();

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '索引成功！' : '索引失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('经文搜索'),
        actions: [
          if (_isIndexed)
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              tooltip: '索引到云端',
              onPressed: _isLoading ? null : _indexToRemote,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索经文...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('输入关键词搜索经文', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: TextStyle(color: Colors.blue[700], fontSize: 12),
                ),
                if (item.preview != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.preview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // 打开经文详情
              _showTextDetail(item);
            },
          ),
        );
      },
    );
  }

  void _showTextDetail(TextItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '分类: ${item.category}',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(item.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
