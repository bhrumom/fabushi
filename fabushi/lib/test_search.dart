import 'package:flutter/material.dart';
import 'services/text_search_service.dart';

void main() {
  runApp(const TestSearchApp());
}

class TestSearchApp extends StatelessWidget {
  const TestSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '搜索测试',
      home: const TestSearchPage(),
    );
  }
}

class TestSearchPage extends StatefulWidget {
  const TestSearchPage({super.key});

  @override
  State<TestSearchPage> createState() => _TestSearchPageState();
}

class _TestSearchPageState extends State<TestSearchPage> {
  final _searchService = TextSearchService();
  final _controller = TextEditingController();
  List<TextItem> _results = [];
  List<String> _categories = [];
  bool _isLoading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _testCategories();
  }

  Future<void> _testCategories() async {
    setState(() {
      _status = '正在获取分类...';
    });
    
    try {
      final categories = await _searchService.getCategories();
      setState(() {
        _categories = categories;
        _status = '获取到 ${categories.length} 个分类: ${categories.join(", ")}';
      });
    } catch (e) {
      setState(() {
        _status = '获取分类失败: $e';
      });
    }
  }

  Future<void> _testSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _status = '正在搜索 "$query"...';
    });

    try {
      final results = await _searchService.searchRemote(query);
      setState(() {
        _results = results;
        _status = '搜索完成，找到 ${results.length} 条结果';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '搜索失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索功能测试'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态显示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            
            // 搜索框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入搜索关键词（如：心经）',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _testSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testSearch,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('搜索'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 分类显示
            if (_categories.isNotEmpty) ...[
              const Text('可用分类:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _categories.map((category) => Chip(
                  label: Text(category),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // 搜索结果
            const Text('搜索结果:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                ? const Center(child: Text('暂无搜索结果'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('分类: ${item.category}'),
                              if (item.preview != null)
                                Text(
                                  item.preview!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}