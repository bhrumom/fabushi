# Drift本地搜索功能指南

## 概述

本应用使用**Drift**包在Web浏览器中实现本地全文搜索功能。Drift在浏览器中使用IndexedDB存储数据，无需服务器端数据库。

## 架构

```
┌─────────────────────────────────────┐
│      Flutter Web 应用                │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  TextSearchService           │  │
│  │  - 索引assets文本            │  │
│  │  - 执行搜索查询              │  │
│  └──────────────────────────────┘  │
│              ↓                      │
│  ┌──────────────────────────────┐  │
│  │  SearchDatabase (Drift)      │  │
│  │  - text_contents 表          │  │
│  └──────────────────────────────┘  │
│              ↓                      │
│  ┌──────────────────────────────┐  │
│  │  IndexedDB (浏览器)          │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## 已实现的文件

### 1. 数据库定义
`lib/database/search_database.dart` - Drift数据库定义

### 2. 搜索服务
`lib/services/text_search_service.dart` - 搜索服务实现

### 3. Worker配置
`web/drift_worker.dart` - Drift worker入口

### 4. 示例代码
`lib/examples/search_example.dart` - 完整使用示例

## 使用方法

### 1. 初始化搜索服务

```dart
import 'package:your_app/services/text_search_service.dart';

final searchService = TextSearchService();

// 初始化数据库
await searchService.initialize();

// 索引所有文本文件
await searchService.indexAssets();
```

### 2. 执行搜索

```dart
// 搜索关键词
final results = await searchService.search('维摩');

// 显示结果
for (final item in results) {
  print('${item.title} - ${item.category}');
}
```

### 3. 清理资源

```dart
@override
void dispose() {
  searchService.dispose();
  super.dispose();
}
```

## 数据库结构

```dart
class TextContents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();           // 标题
  TextColumn get content => text()();         // 完整内容
  TextColumn get filePath => text()();        // 文件路径
  TextColumn get category => text()();        // 分类
}
```

## 搜索功能

- **模糊搜索**: 支持标题和内容的模糊匹配
- **本地存储**: 数据存储在浏览器IndexedDB中
- **离线可用**: 无需网络连接即可搜索
- **快速响应**: 本地数据库查询速度快

## 性能优化

1. **首次索引**: 应用启动时索引所有文本（约需几秒）
2. **持久化**: IndexedDB数据持久化，刷新页面无需重新索引
3. **增量更新**: 只在内容变化时重新索引

## 完整示例

```dart
import 'package:flutter/material.dart';
import 'package:your_app/services/text_search_service.dart';

class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchService = TextSearchService();
  final _controller = TextEditingController();
  List<TextItem> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    await _searchService.initialize();
    await _searchService.indexAssets();
    setState(() => _isLoading = false);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    final results = await _searchService.search(query);
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('搜索')),
      body: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: '搜索...'),
            onSubmitted: (_) => _search(),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchService.dispose();
    super.dispose();
  }
}
```

## 注意事项

1. **仅Web平台**: Drift搜索功能仅在Web平台可用
2. **首次加载**: 首次索引需要时间，建议显示加载指示器
3. **存储限制**: IndexedDB有存储限制（通常几百MB）
4. **隐私模式**: 隐私/无痕模式下IndexedDB可能不可用

## 故障排除

### 搜索无结果

1. 确保已调用 `indexAssets()`
2. 检查浏览器控制台是否有错误
3. 验证IndexedDB是否启用

### 索引失败

1. 检查assets文件路径是否正确
2. 确保文本文件可以被加载
3. 查看浏览器存储空间是否充足

### 性能问题

1. 减少索引的文件数量
2. 使用分批索引
3. 考虑只索引标题而非全文

## 下一步优化

- [ ] 添加全文索引（FTS5）
- [ ] 实现搜索结果高亮
- [ ] 添加搜索历史
- [ ] 支持高级搜索语法
- [ ] 实现搜索建议

---

**愿此功德回向法界众生，同证菩提！** 🙏
