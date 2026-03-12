# 法流页面举报、屏蔽与内容审核功能

满足 App Store Guideline 1.2 要求的第 2、3、4 项：用户可长按视频/评论触发举报和屏蔽，屏蔽后立即从 Feed 移除内容并通知开发者。

## 现状分析

**已有能力（无需重写）：**
- `ContentReportService` — 举报提交到后端 + 本地防重复
- `UserBlockService` — 屏蔽用户 + 本地持久化 + 后端通知
- `ContentFilterService` — 关键词过滤，已集成到视频仓库和帖子列表
- `ReportDialog` — 完整的举报/屏蔽 UI 底部弹窗
- 右侧「更多」按钮已可触发 `ReportDialog`

**缺失的部分（本次需实现）：**
1. 视频/评论没有「长按」手势触发举报
2. 评论列表未过滤违禁词和被屏蔽用户
3. 屏蔽用户后 Feed/评论未即时刷新

## Proposed Changes

### 视频长按举报

#### [MODIFY] [video_feed_view_item.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart)

在 `build()` 方法中为整个 `Stack` 外层包一个 `GestureDetector`，添加 `onLongPress` 触发 `ReportDialog.show()`。同时增加 `onBlockCompleted` 回调，屏蔽后自动触发 Feed 刷新。

---

### 评论长按举报 + 评论过滤

#### [MODIFY] [comment_bottom_sheet.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/features/video_feed/presentation/view/widgets/comment_bottom_sheet.dart)

1. 在 `_buildCommentItem` 外层添加 `GestureDetector.onLongPress`，长按评论时弹出 `ReportDialog`，传入评论的 `contentId`（评论 ID）和 `authorId`（评论者 userId）
2. 在 `_loadComments` 中加入 `ContentFilterService` 过滤含违禁词的评论
3. 在 `_loadComments` 中加入 `UserBlockService.shouldFilter` 过滤被屏蔽用户的评论
4. 屏蔽用户后重新加载评论列表

---

### ReportDialog 添加回调

#### [MODIFY] [report_dialog.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/widgets/report_dialog.dart)

给 `ReportDialog` 和 `ReportDialog.show()` 增加可选的 `VoidCallback? onActionCompleted` 参数，在举报/屏蔽操作完成后回调，用于通知调用方刷新数据。

---

### Overlay 传递 authorId

#### [MODIFY] [video_feed_view_overlay_section.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/features/video_feed/presentation/view/widgets/video_feed_view_overlay_section.dart)

增加 `authorId` 参数透传到 `VideoFeedViewInteractionButtons`，确保屏蔽功能可获取作者 ID。

## Verification Plan

### Automated Tests

1. **现有单元测试**（确保不破坏）：
```bash
cd /Users/gloriachan/Documents/fabushi/fabushi && flutter test test/unit/content_filter_service_test.dart
```

2. **静态分析**：
```bash
cd /Users/gloriachan/Documents/fabushi/fabushi && flutter analyze lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart lib/features/video_feed/presentation/view/widgets/comment_bottom_sheet.dart lib/widgets/report_dialog.dart
```

### Manual Verification

需要用户在真机或模拟器上验证以下场景：
1. 打开法流页面 → 长按任意视频 → 应弹出「举报/屏蔽」底部弹窗
2. 点击评论按钮 → 长按任意评论 → 应弹出「举报/屏蔽」底部弹窗
3. 执行屏蔽操作 → Feed 中该用户内容应立即消失
4. 评论列表中含违禁词的评论应被自动过滤
