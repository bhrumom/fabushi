# 全平台统一 Telegram 风格 UI 重构需求文档 (PRD)

## 1. 目标 (Goal)
将移动端、桌面端、Web 三端的 UI 风格统一重构为 Telegram 样式。融合现有三端功能，并将现有的统一登录模块接入到新的 UI 逻辑中。整体布局、功能放置及侧边栏交互均需吸取 Telegram 版本的精髓。

## 2. 背景与现状 (Context)
目前项目中，导航入口被拆分为 `main_navigation_screen_native.dart` 和 `main_navigation_screen_web.dart`，导致各平台体验和代码分散。
根据需求，我们需要实现：
- **桌面端/Web宽屏：** 采用双栏或三栏布局。左侧为联系人/会话列表（头像与名称作为整体同步移动）；右侧为主聊天视图。
- **菜单交互：** 左上角的汉堡菜单点击后，会展开一个侧边栏（Drawer），其中包含用户设置、个人资料、登录/登出等功能按钮（参考 Telegram）。
- **移动端/Web窄屏：** 采用单栏流转布局，主界面为会话列表，点击后 Push 进入聊天视图。侧边栏通过汉堡菜单呼出。
- **登录接入：** 将现有的 `AuthModel` 登录逻辑（账号密码、支付宝等）统一封装，入口放置在侧边栏菜单中。

## 3. 待确认问题 (Open Questions)
1. **右侧主视图内容：** 统一后的右侧聊天视图目前是 `SocialFeatureChatScreen`。原来的 3D 地球主页 (`GlobeHomeScreen`) 是作为其中的一个标签页保留，还是完全替换为纯聊天界面？
2. **登录交互形式：** 当用户在侧边栏点击“登录”时，是弹出一个居中的 Dialog（如现有 Web 端），还是底部弹窗 (Bottom Sheet)，亦或是跳转到一个全屏的 `LoginScreen`？

## 4. 架构与实施计划 (Implementation Plan)

### 4.1 核心架构与路由重构
- **[修改] `fabushi/lib/screens/main_navigation_screen.dart`**
  - 移除平台条件编译导出 (`dart.library.html`)。
  - 引入 `LayoutBuilder`，在单一文件中统一处理宽屏（桌面/Web）和窄屏（移动）的响应式 Telegram 壳布局。
- **[删除] `main_navigation_screen_native.dart` 和 `main_navigation_screen_web.dart`**
  - 废弃特定平台的导航文件，彻底走向全平台统一。

### 4.2 Telegram 风格 UI 组件开发
- **[新增] `fabushi/lib/widgets/layout/telegram_drawer.dart`**
  - 点击左上角汉堡菜单呼出的侧边栏 Drawer。
  - 顶部显示用户头像、名称、状态。
  - 列表包含：个人资料、设置、全球法布施链接等。
  - 底部或顶部集成统一的**登录/退出**按钮，直接对接 `AuthModel`。
- **[新增] `fabushi/lib/widgets/layout/telegram_chat_list.dart`**
  - 统一的左侧面板（窄屏下的主屏）。
  - 顶部包含汉堡菜单按钮和搜索框。
  - 列表项包含头像与消息简写（两者作为同一组件一起移动和缩放）。
- **[新增] `fabushi/lib/widgets/auth/unified_login_dialog.dart`**
  - 将现有 Web 端的登录弹窗与注册逻辑整合为一个通用的登录组件。支持账号密码、支付宝一键登录等，用于全平台。

### 4.3 细节适配与打磨
- **[修改] `fabushi/lib/widgets/social/social_feature_chat_screen.dart`**
  - 调整样式使其完美嵌入 Telegram 布局的右侧面板中。
  - 确保在窄屏模式下（被 Push 出时）正确显示返回按钮。

## 5. 测试与验证 (Verification Plan)
- **桌面/Web端 (宽屏)：** 验证左侧会话列表与右侧聊天视图的响应式行为；调整窗口宽度，确认头像与名称同步移动；点击菜单展开侧边栏无异常覆盖。
- **移动端 (窄屏)：** 验证主页仅显示会话列表；点击会话正确进入聊天视图；侧滑或点击菜单正确呼出 Drawer。
- **统一登录验证：** 点击侧边栏登录，使用现有凭证或支付宝完成登录，验证侧边栏实时更新用户信息及鉴权状态。
