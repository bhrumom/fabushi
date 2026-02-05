# Video Feed 集成文档

## 概述

本项目已集成 [flutter-video-feed](https://github.com/Deatsilence/flutter-video-feed) 项目，实现了类似 TikTok/Instagram Reels 的短视频流功能。

## 功能特性

- ✅ 垂直滑动视频流
- ✅ 视频自动播放和循环
- ✅ LRU 缓存策略优化内存
- ✅ 预加载机制提升流畅度
- ✅ 后台/前台自动管理
- ✅ Firebase Firestore 数据源

## 项目结构

```
lib/
├── features/
│   └── video_feed/              # Video Feed 核心模块
│       ├── data/                # 数据层
│       │   ├── models/          # 数据模型
│       │   └── repository_impl/ # 仓库实现
│       ├── domain/              # 领域层
│       │   ├── entities/        # 实体
│       │   ├── repositories/    # 仓库接口
│       │   └── usecases/        # 用例
│       └── presentation/        # 表现层
│           ├── bloc/            # 状态管理
│           └── view/            # UI 组件
├── core/
│   └── video_feed_di/           # 依赖注入
│       └── video_feed_injector.dart
└── screens/
    └── video_feed_screen.dart   # 视频流屏幕
```

## 使用方法

### 1. 初始化依赖

在 `main.dart` 中初始化 Video Feed 依赖：

```dart
import 'package:global_dharma_sharing/core/video_feed_di/video_feed_injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 初始化 Video Feed 依赖
  setupVideoFeedDependencies();
  
  runApp(const MyApp());
}
```

### 2. 导航到视频流页面

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const VideoFeedScreen(),
  ),
);
```

### 3. 在主导航中集成

在 `main_navigation_screen.dart` 或其他导航页面中添加：

```dart
ListTile(
  leading: const Icon(Icons.video_library),
  title: const Text('视频流'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VideoFeedScreen(),
      ),
    );
  },
),
```

## Firebase 配置

### Firestore 数据结构

在 Firebase Firestore 中创建 `videos` 集合，文档结构如下：

```json
{
  "id": "video_001",
  "videoUrl": "https://example.com/video.mp4",
  "thumbnailUrl": "https://example.com/thumbnail.jpg",
  "username": "用户名",
  "userProfilePicture": "https://example.com/avatar.jpg",
  "description": "视频描述",
  "likes": 1000,
  "comments": 50,
  "shares": 20,
  "isFollowing": false,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### 示例数据

```javascript
// 在 Firebase Console 中添加测试数据
db.collection('videos').add({
  id: 'video_001',
  videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  thumbnailUrl: 'https://via.placeholder.com/400x600',
  username: '法布施用户',
  userProfilePicture: 'https://via.placeholder.com/100',
  description: '分享佛法智慧 🙏',
  likes: 108,
  comments: 18,
  shares: 6,
  isFollowing: false,
  createdAt: new Date().toISOString()
});
```

## 同步更新

### 一键同步最新代码

运行同步脚本从 GitHub 获取最新版本：

```bash
./sync_video_feed.sh
```

### 手动同步步骤

1. 更新临时仓库：
```bash
cd temp_video_feed
git pull origin main
cd ..
```

2. 复制更新的代码：
```bash
cp -r temp_video_feed/lib/features/video_feed/* lib/features/video_feed/
```

3. 安装依赖：
```bash
flutter pub get
```

4. 生成代码（如需要）：
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 依赖说明

Video Feed 模块需要以下依赖：

- `get_it: ^8.0.3` - 依赖注入
- `flutter_bloc: ^9.1.0` - 状态管理
- `equatable: ^2.0.7` - 值比较
- `fpdart: ^1.1.0` - 函数式编程
- `json_annotation: ^4.9.0` - JSON 序列化
- `cloud_firestore: ^5.6.6` - Firebase 数据库
- `video_player: ^2.9.5` - 视频播放
- `flutter_cache_manager: ^3.4.1` - 缓存管理
- `preload_page_view: ^0.2.0` - 预加载页面视图

## 性能优化

### LRU 缓存策略

- 最多缓存 3 个视频控制器
- 自动释放最少使用的控制器
- 减少内存占用

### 预加载机制

- 预加载当前视频的前后各 1 个视频
- 快速滑动时优先加载目标视频
- 提升用户体验

### 生命周期管理

- 应用进入后台时暂停所有视频
- 应用返回前台时恢复当前视频
- 自动处理错误和重新初始化

## 自定义配置

### 修改缓存大小

在 `video_feed_view.dart` 中修改：

```dart
final int _maxCacheSize = 3; // 改为你需要的数量
```

### 修改预加载范围

在 `_manageControllerWindow` 方法中修改：

```dart
final windowStart = (currentPage - 1).clamp(0, _videos.length - 1);
final windowEnd = (currentPage + 1).clamp(0, _videos.length - 1);
```

## 故障排除

### 视频无法播放

1. 检查 Firebase 配置是否正确
2. 确认 Firestore 中有视频数据
3. 检查视频 URL 是否可访问
4. 查看控制台错误日志

### 内存占用过高

1. 减小 `_maxCacheSize` 值
2. 检查视频文件大小
3. 优化视频质量和分辨率

### 滑动不流畅

1. 增加预加载范围
2. 优化网络连接
3. 使用 CDN 加速视频加载

## 参考资源

- [原项目 GitHub](https://github.com/Deatsilence/flutter-video-feed)
- [YouTube 教程](https://www.youtube.com/watch?v=oQ_Izz1Q4iY)
- [Flutter Video Player 文档](https://pub.dev/packages/video_player)
- [Firebase Firestore 文档](https://firebase.google.com/docs/firestore)

## 许可证

本集成遵循原项目的开源许可证。
