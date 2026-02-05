# 点赞功能使用指南

## 功能概述

类似抖音的点赞功能，用户在法流页面点赞后，内容会自动保存到"我的"页面的喜欢模块中。

## 功能特性

✅ **实时点赞**: 在法流页面点击喜欢按钮即时生效  
✅ **本地持久化**: 使用 SharedPreferences 保存点赞数据  
✅ **云端同步**: 点赞数据自动同步到D1数据库  
✅ **真实计数**: 显示所有用户的点赞总数  
✅ **状态同步**: 点赞状态在法流页面和我的页面实时同步  
✅ **支持视频和文本**: 同时支持视频内容和文本内容的点赞  
✅ **时间排序**: 按点赞时间倒序显示  
✅ **一键取消**: 在喜欢列表中可以快速取消点赞  
✅ **查看全文**: 点击喜欢的内容可查看详情

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                    D1 Database (云端)                    │
│              content_likes 表 (点赞记录)                 │
└─────────────────────────────────────────────────────────┘
                          ↑ ↓
┌─────────────────────────────────────────────────────────┐
│              LikeService (单例 + ChangeNotifier)         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  - 点赞状态管理                                    │  │
│  │  - SharedPreferences 本地持久化                   │  │
│  │  - 云端同步 (API调用)                             │  │
│  │  - 点赞数缓存                                      │  │
│  │  - 状态变化通知                                    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
           ↑                              ↑
           │                              │
    ┌──────┴──────┐              ┌───────┴────────┐
    │   法流页面   │              │   我的页面      │
    │ (VideoFeed)  │              │ (MyProfile)    │
    │              │              │                │
    │ - 点赞按钮   │              │ - 喜欢模块     │
    │ - 真实计数   │              │ - 内容列表     │
    │              │              │ - 查看详情     │
    └─────────────┘              └────────────────┘
```

## 核心文件

### 1. 数据模型
**文件**: `lib/models/liked_item.dart`

```dart
class LikedItem {
  final String id;              // 内容ID
  final String username;        // 作者用户名
  final String description;     // 内容描述
  final String? videoUrl;       // 视频URL（视频内容）
  final String? textContent;    // 文本内容（文本内容）
  final String profileImageUrl; // 作者头像
  final DateTime likedAt;       // 点赞时间
  final String contentType;     // 内容类型: 'video' 或 'text'
}
```

### 2. 点赞服务
**文件**: `lib/services/like_service.dart`

核心方法：
- `initialize()` - 初始化服务，加载本地数据
- `setAuthToken(String? token)` - 设置认证token
- `isLiked(String id)` - 检查内容是否已点赞
- `toggleLike(LikedItem item)` - 切换点赞状态（自动同步云端）
- `getLikedItems()` - 获取所有点赞内容（按时间倒序）
- `getLikeCount(String contentId)` - 获取内容的点赞数
- `fetchLikeCounts(List<String> contentIds)` - 批量获取点赞数
- `likedCount` - 获取用户点赞总数

### 3. 喜欢列表页面
**文件**: `lib/screens/liked_content_screen.dart`

功能：
- 显示所有点赞的内容
- 点击查看内容详情
- 支持取消点赞
- 空状态提示
- 时间格式化显示

### 4. 内容详情页面
**文件**: `lib/screens/content_detail_screen.dart`

功能：
- 显示内容全文（文本内容）
- 显示作者信息
- 支持取消点赞
- 视频内容提示跳转到法流页面

### 5. 视频Feed集成
**文件**: `lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart`

集成点：
- 初始化 LikeService
- 监听点赞状态变化
- 处理点赞按钮点击
- 显示点赞提示

### 6. 我的页面集成
**文件**: `lib/screens/my_profile_screen.dart`

新增模块：
- 喜欢模块卡片
- 显示点赞数量
- 跳转到喜欢列表

## 使用流程

### 用户操作流程

1. **在法流页面点赞**
   ```
   用户浏览法流内容
       ↓
   点击喜欢按钮（❤️）
       ↓
   按钮变红，显示"已添加到喜欢"提示
       ↓
   内容保存到本地
   ```

2. **查看喜欢的内容**
   ```
   进入"我的"页面
       ↓
   点击"我的喜欢"卡片
       ↓
   查看所有点赞的内容列表
       ↓
   可以取消点赞
   ```

3. **取消点赞**
   ```
   在喜欢列表中点击红心按钮
       ↓
   显示"已取消喜欢"提示
       ↓
   内容从列表中移除
       ↓
   法流页面的点赞状态同步更新
   ```

## 数据存储

### 本地存储
- **平台**: 所有平台（iOS、Android、Web、macOS、Windows、Linux）
- **方式**: SharedPreferences
- **键名**: `liked_items`
- **格式**: JSON 数组

### 云端存储 (D1数据库)
- **表名**: `content_likes`
- **字段**:
  - `id`: 自增主键
  - `content_id`: 内容ID
  - `content_type`: 内容类型 (video/text)
  - `user_id`: 用户ID (可为空，游客模式)
  - `created_at`: 创建时间
- **索引**: content_id, user_id
- **唯一约束**: (content_id, user_id)

### 数据结构
```json
[
  {
    "id": "video_001",
    "username": "法师",
    "description": "心经讲解",
    "videoUrl": "https://...",
    "textContent": null,
    "profileImageUrl": "https://...",
    "likedAt": "2024-01-06T10:30:00.000Z",
    "contentType": "video"
  },
  {
    "id": "text_002",
    "username": "佛学堂",
    "description": "金刚经",
    "videoUrl": null,
    "textContent": "如是我闻...",
    "profileImageUrl": "https://...",
    "likedAt": "2024-01-06T11:00:00.000Z",
    "contentType": "text"
  }
]
```

## 状态管理

### LikeService 状态管理
```dart
// 单例模式
final likeService = LikeService();

// 初始化（应用启动时）
await likeService.initialize();

// 检查点赞状态
bool isLiked = likeService.isLiked('video_001');

// 切换点赞
await likeService.toggleLike(likedItem);

// 监听状态变化
likeService.addListener(() {
  // 状态更新时的回调
});
```

### 在Widget中使用
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final LikeService _likeService = LikeService();
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _likeService.initialize();
    _isLiked = _likeService.isLiked(widget.itemId);
    _likeService.addListener(_updateState);
  }

  @override
  void dispose() {
    _likeService.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    setState(() {
      _isLiked = _likeService.isLiked(widget.itemId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
      onPressed: () => _likeService.toggleLike(item),
    );
  }
}
```

## UI 展示

### 法流页面
- **位置**: 右侧交互按钮区域
- **样式**: 
  - 未点赞: 空心红心 ♡
  - 已点赞: 实心红心 ❤️（红色）
- **反馈**: 点击后显示 SnackBar 提示

### 我的页面
- **位置**: 用户信息卡片下方
- **样式**: 
  - 卡片形式
  - 左侧红色爱心图标
  - 显示点赞数量
  - 右侧箭头指示可点击
- **空状态**: "还没有喜欢的内容"

### 喜欢列表页面
- **布局**: 列表形式
- **每项包含**:
  - 作者头像
  - 作者用户名
  - 内容类型标签（视频/文本）
  - 内容描述
  - 点赞时间
  - 取消点赞按钮
- **空状态**: 
  - 大号空心爱心图标
  - "还没有喜欢的内容"提示
  - "在法流页面点赞后会显示在这里"说明

## 性能优化

### 1. 单例模式
- LikeService 使用单例模式，避免重复初始化
- 全局共享同一个实例

### 2. 懒加载
- 只在需要时初始化服务
- 首次访问时加载本地数据

### 3. 批量操作
- 使用 Map 存储点赞状态，O(1) 查询复杂度
- 一次性保存所有数据，减少 I/O 操作

### 4. 状态通知
- 使用 ChangeNotifier 实现状态变化通知
- 只有监听的 Widget 会重建

## 后端API

### 1. 切换点赞状态
```http
POST /api/likes/toggle
Authorization: Bearer <token> (可选)
Content-Type: application/json

{
  "contentId": "video_001",
  "contentType": "video",
  "action": "like" | "unlike"
}

Response:
{
  "success": true,
  "likeCount": 42
}
```

### 2. 获取单个内容点赞数
```http
GET /api/likes/count?contentId=video_001

Response:
{
  "likeCount": 42
}
```

### 3. 批量获取点赞数
```http
POST /api/likes/batch-counts
Content-Type: application/json

{
  "contentIds": ["video_001", "video_002", "text_001"]
}

Response:
{
  "likeCounts": {
    "video_001": 42,
    "video_002": 15,
    "text_001": 88
  }
}
```

## 扩展功能（未来）

- [x] 云端同步点赞数据
- [x] 查看内容详情
- [ ] 点赞内容分类（视频/文本）
- [ ] 点赞内容搜索
- [ ] 批量管理点赞
- [ ] 导出点赞列表
- [ ] 点赞统计分析
- [ ] 点赞内容推荐

## 测试指南

### 功能测试
1. **点赞测试**
   - 在法流页面点击喜欢按钮
   - 验证按钮状态变化
   - 验证提示信息显示

2. **列表测试**
   - 进入"我的喜欢"页面
   - 验证点赞内容显示
   - 验证排序正确（最新在前）

3. **取消点赞测试**
   - 在喜欢列表中取消点赞
   - 验证内容从列表移除
   - 返回法流页面验证状态同步

4. **持久化测试**
   - 点赞后关闭应用
   - 重新打开应用
   - 验证点赞状态保持

### 边界测试
- 空列表状态
- 大量点赞内容（100+）
- 网络图片加载失败
- 快速连续点击

## 故障排除

### 问题1: 点赞状态不同步
**原因**: LikeService 未正确初始化  
**解决**: 确保在使用前调用 `await likeService.initialize()`

### 问题2: 数据丢失
**原因**: SharedPreferences 保存失败  
**解决**: 检查存储权限，查看日志错误信息

### 问题3: 状态不更新
**原因**: 未添加监听器  
**解决**: 使用 `ListenableBuilder` 或手动添加监听器

## 注意事项

1. **初始化时机**: 在使用 LikeService 前必须调用 `initialize()`
2. **内存管理**: 记得在 dispose 时移除监听器
3. **异步操作**: toggleLike 是异步方法，需要 await
4. **状态同步**: 使用 ChangeNotifier 确保状态同步
5. **数据安全**: 本地存储，无需担心隐私泄露

## 更新日志

### v1.1.0 (2024-01-06)
- ✅ 云端同步点赞数据到D1数据库
- ✅ 显示真实的点赞数量
- ✅ 添加内容详情页面
- ✅ 支持查看文本内容全文
- ✅ 批量获取点赞数优化性能

### v1.0.0 (2024-01-06)
- ✅ 实现基础点赞功能
- ✅ 添加喜欢列表页面
- ✅ 集成到法流页面
- ✅ 集成到我的页面
- ✅ 本地数据持久化
- ✅ 状态实时同步

---

**愿此功能让更多人喜欢佛法内容！** 🙏
