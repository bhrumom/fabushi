# ADR-0010 — WebMCP 前台控制面 + Rust 后台执行面

- **状态**：ACCEPTED
- **日期**：2026-08-27
- **项目**：FAB-P0001 / TFI
- **任务**：M8-WEBMCP-001

## 背景

Fabushi 既有 MiniApp 同时存在 Hosted MCP、MCP Apps/AppBridge、本地 JS Runtime、Rust Host、CLI 与 Bot 命令。历史 Local Web MCP 方案使用 Web Runtime/Worker + MessagePort 暴露 Tool；这可以工作，但要求 Fabushi 自行维护页面 Tool discovery、transport、lifecycle 和状态同步。

WebMCP 将当前 Document 的 Agent Tool 注册标准化。与此同时，全球法布施等应用的长任务、队列、数据库、系统能力和崩溃恢复仍必须由 Rust/Native Runtime 持有，不能依赖网页生命周期。

## 决策

1. 所有 MiniApp 的当前页面 Agent 接口统一为 WebMCP。
2. Tool catalog/Tool schema/annotations 是唯一事实源；WebMCP、Slash Commands、Mahayana Host/CLI/Bot 仅为投影/适配器，不复制业务实现。
3. 打开的 MiniApp 优先通过 WebMCP 执行当前页面/应用 Tool；页面关闭时，后台与持久任务继续通过 Mahayana Host -> Rust/Native executor 操作同一业务能力。
4. Rust/Native Runtime 继续拥有 Job、queue、database、system permission、recovery、background execution。
5. 页面 WebMCP Tool 可以薄转发到 Rust/Native Bridge、现有 MCP `tools/call` 或批准的 Remote MCP；执行位置由 Tool/Runtime Profile 决定。
6. WebMCP 未原生提供时使用 `@fabushi/mcp-app-sdk` 的兼容 registry/host bridge；检测到标准 `document.modelContext` 时优先标准 API。
7. 移动端主 UI 继续 SwiftUI/Compose；MiniApp surface 可以使用受控 WKWebView/WebView，但不得恢复 WebView 作为整个 App Shell。
8. 非 read-only、destructive、open-world Tool 必须继续通过现有审批/权限层。
9. 新 MiniApp marketplace/generation 验收必须包含 WebMCP discovery、call、teardown 和后台连续性测试。

## 开源优先证据

- Web Machine Learning Community Group WebMCP specification / repository：采用标准 `Document.modelContext` Tool registration 模型，不复制第三方实现代码。
- OpenAI WebMCP/Site Tools 公开实现方向：验证“当前已打开网页 + 当前登录/页面状态 + page-scoped tools”的产品模型。
- Model Context Protocol / MCP Apps：继续作为后台/Host、远程、本地 Runtime 以及嵌入 UI 的协议基础，不与 WebMCP 二选一。

本次实现仅适配公开标准接口与现有 Fabushi Tool contract，不引入需要额外分发的第三方 WebMCP 代码，因此没有新增代码许可证传播义务。

## 后果

优点：前台 Agent 路径更短；当前页面状态无需同步到独立 Worker；所有平台可逐步采用同一 WebMCP API；Rust 后台能力不受页面关闭影响。

代价：在系统 WebView 尚未原生支持 WebMCP 的平台，需要 Fabushi-compatible bridge/polyfill；过渡期仍需保留现有 MCP/Host executor。

## 回滚

WebMCP adapter 是执行入口适配层。可禁用/移除 adapter 并继续使用既有 MCP/Host executor；不得删除 Rust 后台数据或 Job 状态作为回滚手段。
