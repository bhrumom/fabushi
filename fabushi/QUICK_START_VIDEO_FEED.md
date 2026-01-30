# Video Feed 快速开始指南

## ✅ 已完成的集成

Video Feed 模块已成功集成到您的应用中！

### 已完成的工作

1. ✅ 复制了 video_feed 核心代码到 `lib/features/video_feed/`
2. ✅ 创建了依赖注入配置 `lib/core/video_feed_di/video_feed_injector.dart`
3. ✅ 创建了视频流屏幕 `lib/screens/video_feed_screen.dart`
4. ✅ 更新了 `pubspec.yaml` 添加所需依赖
5. ✅ 在 `main.dart` 中初始化了 Video Feed 依赖
6. ✅ 在主导航栏添加了视频流入口
7. ✅ 生成了 JSON 序列化代码
8. ✅ 创建了同步脚本 `sync_video_feed.sh`

## 🚀 立即使用

### 1. 运行应用

```bash
flutter run
```

### 2. 访问视频流

在应用底部导航栏点击"视频"图标即可进入视频流页面。

## 📝 添加测试数据

在 Firebase Console 中添加测试视频数据：

1. 打开 [Firebase Console](https://console.firebase.google.com/)
2. 选择您的项目
3. 进入 Firestore Database
4. 创建 `videos` 集合
5. 添加文档，使用以下结构：

```json
{
  "id": "video_001",
  "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
  "thumbnailUrl": "https://via.placeholder.com/400x600",
  "username": "法布施用户",
  "userProfilePicture": "https://via.placeholder.com/100",
  "description": "分享佛法智慧 🙏",
  "likes": 108,
  "comments": 18,
  "shares": 6,
  "isFollowing": false,
  "createdAt": "2024-01-15T10:00:00Z"
}
```

### 更多测试视频

```json
{
  "id": "video_002",
  "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
  "thumbnailUrl": "https://via.placeholder.com/400x600",
  "username": "禅修导师",
  "userProfilePicture": "https://via.placeholder.com/100",
  "description": "静心冥想，感受内心的平静 🧘",
  "likes": 256,
  "comments": 32,
  "shares": 15,
  "isFollowing": true,
  "createdAt": "2024-01-15T11:00:00Z"
}
```

## 🔄 同步更新

当 GitHub 项目有更新时，运行：

```bash
./sync_video_feed.sh
```

这将自动：
- 从 GitHub 拉取最新代码
- 复制到您的项目
- 提示您运行必要的命令

## 📚 详细文档

查看完整文档：`VIDEO_FEED_INTEGRATION.md`

## 🎯 导航结构

现在您的应用有 4 个主要页面：

1. 🌍 **首页** - 地球视图和法布施功能
2. 📹 **视频** - 短视频流（新增）
3. 🧘 **禅室** - 冥想和禅修空间
4. 👤 **我的** - 个人资料和设置

## ⚠️ 注意事项

### SDK 版本警告

构建时可能会看到 SDK 版本警告：
```
The language version (3.0.0) does not match the required range `^3.8.0`
```

这不影响功能，如需解决，可以更新 `pubspec.yaml`：

```yaml
environment:
  sdk: '>=3.8.0 <4.0.0'
```

### 视频加载

- 首次加载视频可能需要一些时间
- 确保设备有良好的网络连接
- 视频会自动缓存以提升后续加载速度

## 🎨 自定义

### 修改缓存策略

编辑 `lib/features/video_feed/presentation/view/video_feed_view.dart`：

```dart
final int _maxCacheSize = 3; // 修改缓存数量
```

### 修改 UI 样式

编辑 `lib/features/video_feed/presentation/view/widgets/` 下的组件文件。

## 🐛 故障排除

### 视频无法播放

1. 检查 Firebase 配置
2. 确认 Firestore 中有数据
3. 检查视频 URL 是否可访问

### 应用崩溃

1. 运行 `flutter clean`
2. 运行 `flutter pub get`
3. 重新构建应用

## 📞 获取帮助

- 查看原项目：https://github.com/Deatsilence/flutter-video-feed
- 观看教程视频：https://www.youtube.com/watch?v=oQ_Izz1Q4iY
- 查看完整文档：VIDEO_FEED_INTEGRATION.md

---

🎉 **恭喜！Video Feed 已成功集成到您的应用中！**
