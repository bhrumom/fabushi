import 'package:flutter/material.dart';
import '../database/search_database.dart';
import '../services/text_indexer.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = SearchDatabase();
  final _controller = TextEditingController();
  List<TextContent> _results = [];
  bool _isIndexing = false;

  @override
  void initState() {
    super.initState();
    _indexAssets();
  }

  Future<void> _indexAssets() async {
    setState(() => _isIndexing = true);
    try {
      await TextIndexer(_db).indexAssets();
      debugPrint('✅ 索引完成');
    } catch (e) {
      debugPrint('❌ 索引失败: $e');
    }
    setState(() => _isIndexing = false);
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    debugPrint('🔍 搜索: $query');
    final results = await _db.searchTexts(query);
    debugPrint('📊 结果数: ${results.length}');
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全文搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '搜索经文、咒语...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          if (_isIndexing)
            const LinearProgressIndicator()
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final item = _results[i];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      item.content.substring(0, item.content.length > 100 ? 100 : item.content.length),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _showDetail(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showDetail(TextContent item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(child: Text(item.content)),
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
    _controller.dispose();
    _db.close();
    super.dispose();
  }
}
