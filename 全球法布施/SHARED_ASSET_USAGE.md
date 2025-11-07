# 共享素材管理使用指南

## 概述

`SharedAssetManager` 是一个统一的素材管理服务，用于在首页和法流页面之间共享下载的素材内容。

## 核心特性

✅ **统一存储**: 所有下载的素材存储在同一位置  
✅ **自动复用**: 已下载的素材自动被两个页面共享  
✅ **智能检测**: 自动检测素材是否已下载  
✅ **跨平台支持**: 支持 Web 和原生平台

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│              SharedAssetManager (单例)                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │  - 素材下载状态管理                                │  │
│  │  - 本地文件缓存                                    │  │
│  │  - 下载任务管理                                    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
           ↑                              ↑
           │                              │
    ┌──────┴──────┐              ┌───────┴────────┐
    │   首页       │              │   法流页面      │
    │ (HomeScreen) │              │ (VideoFeed)    │
    └─────────────┘              └────────────────┘
```

## 使用方法

### 1. 在首页使用（已集成）

首页通过 `FileTransferModel` 自动使用 `SharedAssetManager`：

```dart
// lib/models/file_transfer_model.dart
final SharedAssetManager _sharedAssetManager = SharedAssetManager();

// 选择内置素材时
Future<void> selectBuiltInAssets(BuildContext context) async {
  // 自动检测已下载的素材
  if (_sharedAssetManager.isAssetDownloaded(assetPath)) {
    // 直接复用本地文件
    final file = await _sharedAssetManager.getDownloadedAsset(assetPath);
    addFiles([file]);
  } else {
    // 下载新素材
    final taskId = await _sharedAssetManager.downloadAsset(assetPath);
    await _sharedAssetManager.startDownload(taskId);
  }
}
```

### 2. 在法流页面使用（已集成）

法流页面通过 `CloudflareTextService` 自动使用 `SharedAssetManager`：

```dart
// lib/services/cloudflare_text_service.dart
final SharedAssetManager _sharedAssetManager = SharedAssetManager();

Future<Map<String, dynamic>?> _getCloudTextFromLocalManifest() async {
  // 检查是否已下载
  if (_sharedAssetManager.isAssetDownloaded(requestPath)) {
    // 从本地读取
    final file = await _sharedAssetManager.getDownloadedAsset(requestPath);
    // 使用本地文件内容
  } else {
    // 从云端下载
    final content = await http.get(Uri.parse('$baseUrl/$requestPath'));
    // 标记为已下载
    await _sharedAssetManager.markAssetDownloaded(requestPath);
  }
}
```

### 3. 在新页面中使用

如果需要在其他页面使用共享素材：

```dart
import 'package:global_dharma_sharing/services/shared_asset_manager.dart';

class MyNewScreen extends StatefulWidget {
  @override
  State<MyNewScreen> createState() => _MyNewScreenState();
}

class _MyNewScreenState extends State<MyNewScreen> {
  final SharedAssetManager _assetManager = SharedAssetManager();

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    // 初始化
    await _assetManager.initialize();

    // 检查素材是否已下载
    final assetPath = 'assets/built_in/texts/心经.txt';
    if (_assetManager.isAssetDownloaded(assetPath)) {
      // 直接使用本地文件
      final file = await _assetManager.getDownloadedAsset(assetPath);
      print('使用本地文件: ${file?.name}');
    } else {
      // 下载素材
      final taskId = await _assetManager.downloadAsset(assetPath);
      await _assetManager.startDownload(taskId);
      
      // 标记为已下载
      await _assetManager.markAssetDownloaded(assetPath);
    }
  }
}
```

## API 参考

### SharedAssetManager

#### 初始化
```dart
await sharedAssetManager.initialize();
```

#### 检查素材是否已下载
```dart
bool isDownloaded = sharedAssetManager.isAssetDownloaded(assetPath);
```

#### 获取已下载的素材
```dart
PlatformFile? file = await sharedAssetManager.getDownloadedAsset(assetPath);
```

#### 批量获取素材
```dart
Map<String, PlatformFile?> files = await sharedAssetManager.getAssets([
  'assets/built_in/texts/心经.txt',
  'assets/built_in/texts/金刚经.txt',
]);
```

#### 下载素材
```dart
String taskId = await sharedAssetManager.downloadAsset(assetPath);
await sharedAssetManager.startDownload(taskId);
```

#### 标记素材为已下载
```dart
await sharedAssetManager.markAssetDownloaded(assetPath);
```

## 存储位置

### Web 平台
- 使用 `localStorage` 存储
- 键名格式: `file_<fileName>`
- 元数据存储在 `saved_files` 键中

### 原生平台
- Android: `getExternalStorageDirectory()`
- iOS/macOS: `getApplicationDocumentsDirectory()`
- 文件直接存储在目录中

## 工作流程

### 首页下载素材
```
用户选择素材
    ↓
检查是否已下载
    ↓
已下载 → 直接使用本地文件
    ↓
未下载 → 下载并保存到共享位置
    ↓
标记为已下载
```

### 法流页面使用素材
```
需要显示文本内容
    ↓
检查是否已下载
    ↓
已下载 → 从本地读取（首页下载的）
    ↓
未下载 → 从云端下载并保存
    ↓
标记为已下载（供首页使用）
```

## 优势

1. **节省流量**: 素材只需下载一次
2. **提升速度**: 本地读取比网络下载快
3. **离线可用**: 已下载的素材可离线访问
4. **统一管理**: 所有素材在一个地方管理
5. **自动同步**: 两个页面自动共享素材状态

## 注意事项

1. **初始化**: 使用前必须调用 `initialize()`
2. **路径一致**: 确保素材路径在两个页面中一致
3. **错误处理**: 下载失败时要有适当的错误处理
4. **清理机制**: 考虑实现素材清理功能（未来优化）

## 示例场景

### 场景 1: 用户先访问首页
1. 用户在首页选择"心经"素材
2. 素材下载到共享位置
3. 用户切换到法流页面
4. 法流页面检测到"心经"已下载
5. 直接从本地读取，无需重新下载

### 场景 2: 用户先访问法流页面
1. 用户打开法流页面
2. 法流页面随机显示"金刚经"
3. 从云端下载并保存到共享位置
4. 用户切换到首页
5. 首页检测到"金刚经"已下载
6. 用户选择时直接使用本地文件

## 未来优化

- [ ] 添加素材过期机制
- [ ] 实现素材清理功能
- [ ] 添加素材大小限制
- [ ] 支持素材更新检测
- [ ] 添加下载进度回调
- [ ] 实现批量下载优化

---

**更新日期**: 2024-01-06  
**版本**: 1.0.0
