# M8-WEBMCP-001 — 全量 MiniApp WebMCP Runtime

- **Project**: FAB-P0001 / TFI
- **Stage**: M8 Mini Apps
- **Status**: IN_PROGRESS
- **Branch**: `feat/tfi-webmcp-miniapp-runtime`
- **PR**: #2169
- **Target version**: 1.0.4
- **Source**: `source/2026-08-27-webmcp-miniapp-runtime.md`
- **ADR**: `decisions/ADR-0010-webmcp-foreground-rust-background.md`
- **Evidence**: `evidence/M8-WEBMCP-001/README.md`

## 目标

把 WebMCP 设为所有 MiniApp 的统一前台 Agent 接口，同时保持 Rust/Native Runtime 为长任务与后台业务执行面。Tool Contract 是唯一事实源，WebMCP、slash command、Mahayana Host、CLI/Bot 均由同一 Tool catalog 派生，不维护平台级第二份命令映射。

## 原子验收

1. SDK 能 feature-detect `document.modelContext` 并按当前 WebMCP Draft 注册/注销 Tool；浏览器暂不支持时有 Fabushi-compatible fallback registry。
2. Hosted MiniApp 在加载后把真实 MCP `tools/list` 自动投影为 WebMCP；`tools/call` 仍走同一后端，不维护第二份映射。
3. read-only Tool 无写操作确认；write/destructive Tool 继续走宿主批准语义。
4. 本地安装 MiniApp 能在桌面受控 iframe 中发现当前 app Tool，并调用本地 Rust Runtime；Host 全局 Tool inventory 不得跨 MiniApp 泄露。
5. Android/iOS 主壳保持 Compose/SwiftUI；MiniApp 使用受控 WebView/WKWebView，优先打开已安装本地 HTML，缺失时才回退 Hosted WebMCP。
6. Rust Host 对便携本地 Runtime 暴露 `runtime.tools` + `runtime.call`；调用前要求插件 Active 且 Tool 已注册；页面关闭仅 teardown 前台 WebMCP，不停止 Rust Job/状态。
7. Marketplace/BotFather 新 MiniApp 验收强制 WebMCP Tool Contract；slash command 从同一 Tool metadata 派生。
8. SDK unit/contract tests、web/desktop/native compile/test、MiniApp WebMCP E2E 通过。
9. PR 通过 required checks 并合入 protected `main`。
10. exact-main desktop/mobile packaged simulated-user E2E 有截图/视频/trace/report evidence；发布 GitHub Release 1.0.4。

## 开源优先

研究并采用 WebMCP Community Group specification/repository、OpenAI WebMCP/Site Tools 产品模型、MCP/MCP Apps。未复制第三方实现代码；Fabushi 实现标准 adapter + existing Tool Contract projection。2026-08-26 WebMCP Draft 的关键兼容点已落地：`registerTool(tool, { signal })`、abort lifecycle、`getTools()` / `executeTool()` 与当前 annotations。

## 已完成实现

- `frontend/packages/mcp-app-sdk/src/webmcp.ts`: WebMCP standard adapter、native feature detection、fallback registry、native discovery/call。
- `frontend/packages/mcp-app-sdk/test/webmcp.test.ts`: fallback/native lifecycle/native execute/MCP projection contract tests。
- Hosted MiniApp `WebMcpMiniAppAdapter`: `tools/list -> WebMCP -> tools/call` 自动投影，所有 `/miniapps/[id]` 页面统一挂载。
- Marketplace/BotFather WebMCP admission policy + tests：新 MiniApp 必须有可调用 Tool Contract 才能进入完整发布链。
- Desktop installed MiniApp host：本地 HTML 自动注入 WebMCP；随机 nonce；Tool inventory 与当前 MiniApp Contract 取交集；写操作审批；本地调用进入 Rust `runtime.call`。
- Rust `mahayana-app-host`: 新增 `runtime.call`，要求 runtime Active、参数为 object、Tool 已注册，随后调用既有 `DeepSeekJsHost::call_tool_json`。
- Android：Compose 主壳保留；MiniApp WebMCP surface 本地优先、Hosted 兜底；Tool Contract 驱动；Native approval；调用 Rust `runtime.call`。
- iOS：SwiftUI 主壳保留；WKWebView MiniApp surface 本地优先、Hosted 兜底；Tool Contract 驱动；Native approval；调用 Rust `runtime.call`。
- 版本基线已提升到 1.0.4，build/version code 2；desktop/mobile/iOS metadata 已对齐。
- 原始需求、ADR、证据索引已持久化。

## 当前进行中

- 最新 PR head required CI / desktop / native mobile / Mahayana checks 正在重新验证。
- 收紧 Hosted fallback 与 local Native bridge 的来源隔离。
- 补充 MiniApp WebMCP E2E 与项目 WBS/acceptance/status/changelog。
- required checks 全绿后转 Ready，进入 protected-main/merge-queue。
- merge 后执行 exact-main packaged desktop/mobile E2E 与 1.0.4 Release。

## 已发现并修复的预检问题

- 版本漂移：架构门曾报告 `canonical=1.0.4 desktop=1.0.4 mobile=1.0.3`；已将 `mobile/package.json` 对齐 1.0.4。
- Rust 格式：`cargo fmt --check` 要求 `PluginState` import 换行；已按 rustfmt 精确修复。
- Rust Host 全文件更新过程中曾意外把 `MAHAYANA_DOCKER_BIN` 写成 `DOCKER_PATH`；通过精确 PR patch 审计发现并恢复，最终 Rust diff 仅保留 `runtime.call` 相关改动。

## 完成定义

只有以下全部成立才把本任务从 `IN_PROGRESS` 改为 `COMPLETED`：

1. latest head required checks 全绿；
2. PR #2169 合入 protected `main`；
3. 从 canonical `main` 回读实现与版本；
4. exact-main Electron/Android/iOS required packaged E2E 与证据 bundle 全绿；
5. GitHub Release 1.0.4 指向验收后的 main SHA，包含 updater-compatible desktop assets 与移动端构建资产。
