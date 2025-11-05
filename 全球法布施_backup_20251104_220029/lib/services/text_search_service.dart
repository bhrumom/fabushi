import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TextItem {
  final int? id;
  final String title;
  final String content;
  final String filePath;
  final String category;
  final String? preview;

  TextItem({
    this.id,
    required this.title,
    required this.content,
    required this.filePath,
    required this.category,
    this.preview,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'filePath': filePath,
    'category': category,
  };

  factory TextItem.fromJson(Map<String, dynamic> json) => TextItem(
    id: json['id'],
    title: json['title'],
    content: json['content'] ?? '',
    filePath: json['path'] ?? json['filePath'],
    category: json['category'],
    preview: json['preview'],
  );
}

class TextSearchService {
  final String baseUrl;
  List<TextItem> _items = [];
  bool _isIndexed = false;

  TextSearchService({this.baseUrl = 'https://ombhrum.com'});

  // 本地索引（用于离线搜索）
  Future<void> indexAssets() async {
    if (_isIndexed) return;
    
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    
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

  // 本地搜索
  List<TextItem> searchLocal(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    return _items.where((item) =>
      item.title.toLowerCase().contains(lowerQuery) ||
      item.content.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  // 远程搜索（使用worker的drift数据库）
  Future<List<TextItem>> search(String query, {int limit = 50}) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/search?q=${Uri.encodeComponent(query)}&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        return results.map((json) => TextItem.fromJson(json)).toList();
      }
    } catch (e) {
      print('远程搜索失败: $e');
    }

    // 如果远程搜索失败，使用本地搜索
    return searchLocal(query);
  }

  // 将本地文本索引到远程数据库
  Future<bool> indexToRemote() async {
    if (!_isIndexed) {
      await indexAssets();
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/search/index'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'texts': _items.map((item) => item.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('索引到远程失败: $e');
    }

    return false;
  }
}
