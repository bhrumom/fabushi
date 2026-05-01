import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/search_utils.dart';

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
    id: _parseIdSafe(json['id']),
    title: (json['title'] ?? '').toString(),
    content: (json['content'] ?? '').toString(),
    filePath: (json['path'] ?? json['filePath'] ?? json['file_path'] ?? '')
        .toString(),
    category: (json['category'] ?? '').toString(),
    preview: json['preview']?.toString(),
  );

  static int? _parseIdSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class TextSearchService {
  final String baseUrl;
  List<TextItem> _items = [];
  bool _isIndexed = false;

  TextSearchService({this.baseUrl = 'https://flutter.ombhrum.com'});

  // 本地索引（用于离线搜索）
  Future<void> indexAssets() async {
    if (_isIndexed) return;

    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestContent);

      final entries = manifest.keys
          .where((s) => s.contains('assets/built_in/') && s.endsWith('.txt'))
          .toList();

      for (final path in entries) {
        final title = path.split('/').last.replaceAll('.txt', '');
        final parts = path.split('/');
        final category = parts.length > 2 ? parts[2] : '其他';

        String content = '';
        try {
          content = await rootBundle.loadString(path);
        } catch (e) {
          print('加载内容失败: $path');
        }

        _items.add(
          TextItem(
            title: title,
            content: content,
            filePath: path,
            category: category,
          ),
        );
      }

      print('✅ 本地索引完成: ${_items.length} 个项目');
    } catch (e) {
      print('❌ 本地索引失败: $e');
    }

    _isIndexed = true;
  }

  // 本地搜索
  List<TextItem> searchLocal(String query) {
    if (query.isEmpty) return [];

    // 1. 优先匹配标题
    final titleMatches = _items.where((item) {
      return SearchUtils.fuzzyMatch(item.title, query);
    }).toList();

    if (titleMatches.isNotEmpty) {
      return titleMatches;
    }

    // 2. 如果标题没有匹配，再匹配内容
    return _items.where((item) {
      return SearchUtils.fuzzyMatch(item.content, query);
    }).toList();
  }

  // 远程搜索（使用D1数据库）
  Future<List<TextItem>> search(String query, {int limit = 50}) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/builtin/search?q=${Uri.encodeComponent(query)}&limit=$limit',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final results = data['data']['results'] as List;
          return results
              .map(
                (json) => TextItem(
                  id: _parseId(json['id']),
                  title: json['title'] ?? '',
                  content: json['content'] ?? '',
                  filePath: json['file_path'] ?? json['filePath'] ?? '',
                  category: json['category'] ?? '',
                  preview: _generatePreview(json['content'] ?? '', query),
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      print('远程搜索失败: $e');
    }

    // 如果远程搜索失败，使用本地搜索
    return searchLocal(query);
  }

  // 远程搜索（带分类筛选）
  Future<List<TextItem>> searchRemote(
    String query, {
    String? category,
    int limit = 50,
  }) async {
    if (query.isEmpty) return [];

    try {
      var url =
          '$baseUrl/api/builtin/search?q=${Uri.encodeComponent(query)}&limit=$limit';
      if (category != null && category.isNotEmpty) {
        url += '&category=${Uri.encodeComponent(category)}';
      }

      print('🔍 搜索请求: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      print('📊 响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 解析数据: $data');

        if (data['success'] == true && data['data'] != null) {
          final dataMap = data['data'] as Map<String, dynamic>;
          final results = dataMap['results'] as List;
          final pagination = dataMap['pagination'] as Map<String, dynamic>?;

          print('✅ 找到 ${results.length} 条结果');
          if (pagination != null) {
            print(
              '📊 分页信息: total=${pagination['total']}, limit=${pagination['limit']}, offset=${pagination['offset']}',
            );
          }

          // 如果远程搜索没有结果，尝试本地搜索
          if (results.isEmpty) {
            print('⚠️ 远程搜索无结果，转为本地搜索...');
            if (!_isIndexed) {
              await indexAssets();
            }
            return searchLocal(query);
          }

          return results
              .map(
                (json) => TextItem(
                  id: _parseId(json['id']),
                  title: json['title'] ?? '',
                  content: json['content'] ?? '',
                  filePath: json['file_path'] ?? json['filePath'] ?? '',
                  category: json['category'] ?? '',
                  preview: _generatePreview(json['content'] ?? '', query),
                ),
              )
              .toList();
        } else {
          print('⚠️ API返回数据格式不正确');
        }
      } else {
        print('❌ HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 远程搜索异常: $e');
    }

    // 如果远程搜索失败，使用本地搜索
    print('💻 尝试本地搜索...');
    if (!_isIndexed) {
      await indexAssets();
    }
    return searchLocal(query);
  }

  // 获取所有分类
  Future<List<String>> getCategories() async {
    try {
      final url = '$baseUrl/api/builtin/categories';
      print('📚 获取分类请求: $url');

      final response = await http.get(Uri.parse(url));

      print('📊 分类响应状态码: ${response.statusCode}');
      print('📝 分类响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final categories = data['data'] as List;
          final categoryNames = categories
              .map((cat) => (cat['category'] ?? '').toString())
              .toList();
          print('✅ 获取到 ${categoryNames.length} 个分类: $categoryNames');
          return categoryNames;
        } else {
          print('⚠️ 分类API返回数据格式不正确');
        }
      } else {
        print('❌ 获取分类HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 获取分类异常: $e');
    }

    return [];
  }

  // 安全解析ID字段
  int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // 安全解析整数字段 - 处理null、int和string类型
  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // 安全解析整数字段并提供默认值
  static int _parseIntWithDefault(dynamic value, int defaultValue) {
    return _parseIntSafe(value) ?? defaultValue;
  }

  // 生成预览文本
  String _generatePreview(String content, String query) {
    if (content.isEmpty) return '';

    final queryLower = query.toLowerCase();
    final contentLower = content.toLowerCase();
    final index = contentLower.indexOf(queryLower);

    if (index != -1) {
      final start = (index - 50).clamp(0, content.length);
      final end = (index + query.length + 150).clamp(0, content.length);
      final preview = content.substring(start, end);
      return (start > 0 ? '...' : '') +
          preview +
          (end < content.length ? '...' : '');
    }

    return content.length > 200 ? content.substring(0, 200) + '...' : content;
  }

  // 获取文本内容
  Future<TextItem?> getTextContent(String path) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/builtin/content?path=${Uri.encodeComponent(path)}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TextItem.fromJson(data);
      }
    } catch (e) {
      print('获取内容失败: $e');
    }

    return null;
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
