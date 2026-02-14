# UGC 安全机制与支持页面实现计划

解决 App Store 审核 Guideline 1.2（UGC 安全）和 Guideline 1.5（支持页面）的问题。

## 调研结论

大部分核心功能已在之前的对话中实现，以下文件**已完成**且质量良好：

| 文件 | 状态 | 说明 |
|------|------|------|
| [eula_screen.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/screens/eula_screen.dart) | ✅ 已完成 | EULA 展示页面，含滚动检测、勾选同意、同意/不同意按钮 |
| [eula_service.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/services/eula_service.dart) | ✅ 已完成 | EULA 状态管理，含版本控制和完整协议文本 |
| [content_report_service.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/services/content_report_service.dart) | ✅ 已完成 | 举报 API 调用，8 种举报类型，本地+远程双存储 |
| [user_block_service.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/services/user_block_service.dart) | ✅ 已完成 | 用户屏蔽/取消屏蔽，内存缓存+本地持久化+后端通知 |
| [report_dialog.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/widgets/report_dialog.dart) | ✅ 已完成 | 举报弹窗 UI，集成屏蔽功能，已接入视频 Feed |
| [app_wrapper.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/widgets/app_wrapper.dart) 中 EULA 检查 | ✅ 已完成 | 首次启动强制显示 EULA |

## Proposed Changes

### 1. 内容详情页集成举报按钮

#### [MODIFY] [content_detail_screen.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/screens/content_detail_screen.dart)

在 AppBar 的 `actions` 中添加举报/更多操作按钮（`Icons.more_horiz`），点击调用 `ReportDialog.show()`。

---

### 2. 注册页面集成 EULA 检查

#### [MODIFY] [register_screen.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/screens/register_screen.dart)

注册成功后、返回主界面前，调用 `EulaScreen.checkAndShow()` 确保新用户同意协议。

> [!NOTE]
> `login_screen.dart` 不需要单独集成 EULA，因为 `app_wrapper.dart` 已在应用启动时统一检查。只有注册流程是新用户，需要额外确认。

---

### 3. EULA 增加英文版内容

#### [MODIFY] [eula_service.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/services/eula_service.dart)

在现有中文协议文本后追加英文版 EULA（Apple 审核团队需要能阅读协议内容）。重点加强 "Zero Tolerance" 政策、举报机制的英文描述。

---

### 4. 创建静态支持页面

#### [NEW] [index.html](file:///Users/gloriachan/Documents/fabushi/fabushi/web/support/index.html)

创建独立的静态 HTML 支持页面，部署在 `flutter.ombhrum.com/support`。包含：
- 应用简介（大乘 - 全球法布施）
- FAQ（常见问题：账号、内容、安全相关）
- 联系方式（support@ombhrum.com）
- 反馈表单（mailto 链接形式）
- 中英双语

## Verification Plan

### 自动化测试

```bash
# 静态分析
cd /Users/gloriachan/Documents/fabushi/fabushi && flutter analyze lib/screens/content_detail_screen.dart lib/screens/register_screen.dart lib/services/eula_service.dart
```

### 手动验证

1. **支持页面**：用浏览器直接打开 `web/support/index.html`，检查页面布局、内容完整性
2. **举报功能**：从内容详情页点击更多按钮，验证举报弹窗正常弹出
3. **注册 EULA**：新用户注册流程后应弹出 EULA 同意页面（需在设备上测试）
