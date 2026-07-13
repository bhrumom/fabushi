# 打开应用（全球法布施）右侧面板白屏修复需求与设计文档 (PRD)

- **状态**: 已完成（自动分析与测试全部跑通通过）
- **日期**: 2026-07-08

## 1. 背景与问题定义

用户在 macOS 桌面端应用（`global_dharma_sharing`）底部的聊天栏中点击“打开应用”按钮后，右侧展开“全球法布施”内嵌小程序控制面板。当前现象为：
- 顶部标题栏正常显示（由 `MiniAppHostScreen` 渲染“全球法布施”标题及操作控制按钮）。
- 标题栏下方的主要交互区域完全呈现**纯白色屏幕（白屏）**，未正常显示应用界面底色或过渡态。

## 2. 根因剖析（第一性原理分析）

通过对 `lib/screens/mini_app_host_screen.dart` 的底层实现与 macOS Native PlatformView (`WKWebView`) 机制分析，发现以下核心技术冲突：

1. **WKWebView 原生背景白底冲突 (`transparentBackground: false`)**：
   - 默认情况下，macOS WKWebView 的底层视图背景为不透明纯白 (`#FFFFFF`)。在页面 DOM 和外部 CSS (`https://fabushi.ombhrum.com/miniapps/official.global-dharma/`) 完成网络下载与重绘前，或者页面加载耗时较长期间，原生视图将持续呈现大片高亮白斑，与深色应用界面 (`#0F1722`) 形成断裂式的“白屏”。
2. **加载态覆盖缺失**：
   - 当前 loading 状态下未提供全覆盖式的深色底层占位遮罩层（仅在 `Stack` 顶层渲染了一个半透明或居中的 Indicator），在原生 WKWebView 创建及网络解析前无法完全掩盖白底。
3. **桌面端 PlatformView 与剪裁层相容性优化**：
   - 保障在桌面端应用层中 WKWebView 渲染能够平稳依托底色并正确传递声明周期事务。

## 3. 解决方案与核心改动设计

遵循 **KISS 原则**（Keep It Simple, Stupid）和**第一性原理**：

### 3.1 WKWebView 背景开启透明底色适配
在 `InAppWebViewSettings` 中进行优化：
```dart
initialSettings: InAppWebViewSettings(
  javaScriptEnabled: true,
  transparentBackground: true, // 核心修复：开启透明背景，消除默认纯白 #FFFFFF 涂层
  mediaPlaybackRequiresUserGesture: false,
  supportZoom: false,
  domStorageEnabled: true,
  databaseEnabled: true,
)
```
使得在网页 HTML 和样式表加载前，WebView 天然透出下层应用的深色主题底色 (`#0F1722`)。

### 3.2 Stack 结构底色与深色占位过渡层增强
对 `_MiniAppHostScreenState.build` 返回的 `content` 构建进行强化：
- 根底层使用 `ColoredBox(color: Color(0xFF0F1722))` 作为纯正且连续的暗色画布。
- 在 `_loading == true` 或 `_error != null` 时，覆盖与主色调融合平滑的深色过渡遮罩并提供明确反馈，绝不给纯白屏留任何渲染时机。

## 4. 任务清单 (Task List)

- [ ] **任务 1**：修改 `lib/screens/mini_app_host_screen.dart` 中 `InAppWebViewSettings` 配置，开启 `transparentBackground: true` 并规范化样式设置。
- [ ] **任务 2**：在 `MiniAppHostScreen` 渲染层中补全深色底层画布与占位层（`ColoredBox(color: Color(0xFF0F1722))`），对加载中与加载报错提供深色全覆盖过渡视图。
- [ ] **任务 3**：执行自动化分析与测试验证 (`dart analyze` 及相关自动化回归检查)，确保修复正确无误并且编译无错。

## 5. 验收标准

1. 点击“打开应用”按钮后，侧边栏在页面建立连接及加载前天然呈现应用深色主题底色，不再出现任何瞬间或持续性全白屏。
2. 小程序正常载入或发生加载异常时，均具备优雅稳定的深色主题与反馈。
