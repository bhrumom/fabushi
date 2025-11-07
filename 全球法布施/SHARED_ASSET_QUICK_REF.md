# 共享素材管理 - 快速参考

## 🚀 快速开始

```dart
import 'package:global_dharma_sharing/services/shared_asset_manager.dart';

// 获取实例（单例）
final assetManager = SharedAssetManager();

// 初始化
await assetManager.initialize();

// 检查 + 使用
if (assetManager.isAssetDownloaded(path)) {
  final file = await assetManager.getDownloadedAsset(path);
} else {
  final taskId = await assetManager.downloadAsset(path);
  await assetManager.startDownload(taskId);
}
```

## 📚 核心 API

| 方法 | 说明 | 返回值 |
|------|------|--------|
| `initialize()` | 初始化管理器 | `Future<void>` |
| `isAssetDownloaded(path)` | 检查是否已下载 | `bool` |
| `getDownloadedAsset(path)` | 获取已下载素材 | `Future<PlatformFile?>` |
| `getAssets(paths)` | 批量获取素材 | `Future<Map<String, PlatformFile?>>` |
| `downloadAsset(path)` | 创建下载任务 | `Future<String>` |
| `startDownload(taskId)` | 开始下载 | `Future<void>` |
| `markAssetDownloaded(path)` | 标记已下载 | `Future<void>` |

## 🎯 使用场景

### 场景 1: 首页选择素材
```dart
// 用户选择内置素材
final assetPaths = ['assets/built_in/texts/心经.txt'];

// 检查是否已下载
if (assetManager.isAssetDownloaded(assetPaths[0])) {
  // 直接使用（可能是法流页面下载的）
  final file = await assetManager.getDownloadedAsset(assetPaths[0]);
  addFiles([file]);
} else {
  // 下载新素材
  final taskId = await assetManager.downloadAsset(assetPaths[0]);
  await assetManager.startDownload(taskId);
}
```

### 场景 2: 法流页面加载文本
```dart
// 随机选择文本
final selectedFile = 'assets/built_in/texts/金刚经.txt';

// 优先使用本地（可能是首页下载的）
if (assetManager.isAssetDownloaded(selectedFile)) {
  final file = await assetManager.getDownloadedAsset(selectedFile);
  // 读取文件内容
  final content = utf8.decode(file.bytes!);
} else {
  // 从云端下载
  final response = await http.get(Uri.parse(url));
  // 标记为已下载（供首页使用）
  await assetManager.markAssetDownloaded(selectedFile);
}
```

## 💡 最佳实践

### ✅ 推荐做法
```dart
// 1. 总是先初始化
await assetManager.initialize();

// 2. 先检查再下载
if (!assetManager.isAssetDownloaded(path)) {
  await downloadAsset(path);
}

// 3. 下载后标记
await assetManager.markAssetDownloaded(path);
```

### ❌ 避免做法
```dart
// 1. 不要跳过初始化
assetManager.isAssetDownloaded(path); // ❌ 可能出错

// 2. 不要重复下载
await downloadAsset(path); // ❌ 应先检查

// 3. 不要忘记标记
// 下载完成后没有调用 markAssetDownloaded // ❌
```

## 🔍 调试技巧

### 查看已下载素材
```dart
// Web 平台
// 打开浏览器控制台 → Application → Local Storage
// 查看 'saved_files' 键

// 原生平台
// Android: /storage/emulated/0/Android/data/com.app/files/
// iOS: /var/mobile/Containers/Data/Application/.../Documents/
```

### 清除已下载素材
```dart
// Web 平台
localStorage.clear();

// 原生平台
// 删除应用数据或重新安装
```

## 📊 状态流转

```
未下载 (null)
    ↓
  下载中 (downloading)
    ↓
  已完成 (completed)
    ↓
  可复用 (isAssetDownloaded = true)
```

## 🐛 常见问题

### Q: 为什么检测不到已下载的素材？
A: 确保路径完全一致，包括 `assets/built_in/` 前缀

### Q: 如何清除所有已下载素材？
A: Web 平台清除 localStorage，原生平台清除应用数据

### Q: 素材会过期吗？
A: 当前版本不会过期，未来会添加过期机制

### Q: 支持哪些文件类型？
A: 所有类型，主要用于文本、图片、音频、视频

## 📖 相关文档

- 📘 [详细使用指南](SHARED_ASSET_USAGE.md)
- 📗 [实现报告](SHARED_ASSET_IMPLEMENTATION.md)
- 📙 [功能总结](SHARED_ASSET_SUMMARY.md)
- 📕 [项目 README](README.md)

---

**快速参考** | v1.2.0 | 2024-01-06
