import 'package:flutter/services.dart';

class TextItem {
  final String title;
  final String content;
  final String filePath;
  final String category;

  TextItem({
    required this.title,
    required this.content,
    required this.filePath,
    required this.category,
  });
}

class TextSearchService {
  List<TextItem> _items = [];
  bool _isIndexed = false;

  Future<void> indexAssets() async {
    if (_isIndexed) return;
    
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = {};
    
    // 简单解析 JSON
    final entries = manifestContent.split('"').where((s) => s.contains('assets/built_in/')).toList();
    
    for (final path in entries) {
      if (path.endsWith('.txt')) {
        try {
          final content = await rootBundle.loadString(path);
          final title = path.split('/').last.replaceAll('.txt', '');
          final parts = path.split('/');
          final category = parts.length > 2 ? parts[2] : '其他';
          
          _items.add(TextItem(
            title: title,
            content: content,
            filePath: path,
            category: category,
          ));
        } catch (e) {
          // Skip files that can't be loaded
        }
      }
    }
    
    _isIndexed = true;
  }

  List<TextItem> search(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    return _items.where((item) =>
      item.title.toLowerCase().contains(lowerQuery) ||
      item.content.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}
