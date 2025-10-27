# 🔍 文本信息流调试指南

## 问题现象
屏幕显示"暂无视频"提示，没有显示文本信息流

## 调试步骤

### 1. 检查控制台日志
运行应用后，查看控制台输出，应该看到：
```
No videos found, loading text content...
Fetching text file list...
Found X text files
Selected file: assets/...
Successfully loaded: XXX (XXXX chars)
Loaded text content: XXX
Total text content loaded: 5
```

### 2. 可能的错误情况

#### 错误A: 网络连接失败
```
Error fetching text file list: ...
```
**解决方案**: 
- 检查网络连接
- 确认 `https://flutter.ombhrum.com` 可访问
- 在浏览器中测试: `https://flutter.ombhrum.com/assets/data/asset-manifest.json`

#### 错误B: 文件列表为空
```
Found 0 text files
No text files available
```
**解决方案**:
- 检查 asset-manifest.json 是否存在
- 确认文件中包含 .txt 文件

#### 错误C: 文本内容加载失败
```
Failed to load content from: ...
```
**解决方案**:
- 检查文件路径是否正确
- 确认文件可以通过HTTP访问

### 3. 手动测试文本服务

在 `main.dart` 中添加测试代码：
```dart
import 'package:global_dharma_sharing/services/cloudflare_text_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 测试文本服务
  final textService = CloudflareTextService();
  print('Testing text service...');
  final textData = await textService.getRandomTextContent();
  if (textData != null) {
    print('✅ Text service working!');
    print('Title: ${textData['title']}');
    print('Content length: ${textData['content']?.length}');
  } else {
    print('❌ Text service failed!');
  }
  
  runApp(const MyApp());
}
```

### 4. 检查State更新

在 `video_feed_cubit.dart` 的 `loadVideos()` 方法中添加日志：
```dart
result.fold(
  (error) {
    print('❌ Error: $error');
    emit(state.copyWith(...));
  },
  (videos) {
    print('✅ Loaded ${videos.length} items');
    print('Video count: ${videos.where((v) => v.contentType != ContentType.text).length}');
    print('Text count: ${videos.where((v) => v.contentType == ContentType.text).length}');
    emit(state.copyWith(...));
  },
);
```

### 5. 验证UI渲染

在 `video_feed_screen.dart` 中添加日志：
```dart
builder: (context, state) {
  print('State: isLoading=${state.isLoading}, videos=${state.videos.length}, error=${state.errorMessage}');
  
  if (state.isLoading) { ... }
  if (state.errorMessage.isNotEmpty) { ... }
  if (state.videos.isEmpty && !state.isLoading) { ... }
  
  return const VideoFeedView();
}
```

## 预期行为

### 正常流程
1. 用户打开法流页面
2. 显示"正在加载视频..."
3. Repository查询Firestore（无视频）
4. Repository调用CloudflareTextService
5. 加载5个随机文本内容
6. State更新，videos包含5个文本实体
7. UI显示VideoFeedView
8. 用户可以滑动浏览文本内容

### 数据流
```
VideoFeedScreen
  ↓
VideoFeedCubit.loadVideos()
  ↓
FetchVideosUseCase()
  ↓
VideoFeedRepositoryImpl.fetchVideos()
  ↓
Firestore查询 (空结果)
  ↓
CloudflareTextService.getRandomTextContent() × 5
  ↓
返回 List<VideoEntity> (5个文本实体)
  ↓
VideoFeedCubit更新state
  ↓
VideoFeedScreen重建
  ↓
显示VideoFeedView
```

## 快速修复检查清单

- [ ] 网络连接正常
- [ ] `flutter.ombhrum.com` 可访问
- [ ] asset-manifest.json 存在且包含.txt文件
- [ ] CloudflareTextService 正确注入
- [ ] Repository 正确处理空视频情况
- [ ] Cubit 正确更新state
- [ ] Screen 正确检查state.videos.isEmpty
- [ ] VideoFeedView 支持文本内容渲染

## 临时解决方案

如果文本服务暂时不可用，可以使用硬编码的文本内容：

```dart
if (videos.isEmpty) {
  // 使用硬编码文本内容
  final sampleTexts = [
    '南无阿弥陀佛',
    '观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。',
    '诸恶莫作，众善奉行，自净其意，是诸佛教。',
  ];
  
  for (int i = 0; i < sampleTexts.length; i++) {
    videos.add(VideoEntity(
      id: 'text_sample_$i',
      username: '法布施',
      description: '佛法文本',
      videoUrl: '',
      profileImageUrl: 'https://via.placeholder.com/100',
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      timestamp: DateTime.now(),
      contentType: ContentType.text,
      textContent: sampleTexts[i],
    ));
  }
}
```

---

💡 **提示**: 运行应用后，仔细查看控制台日志，找出具体在哪一步失败了。
