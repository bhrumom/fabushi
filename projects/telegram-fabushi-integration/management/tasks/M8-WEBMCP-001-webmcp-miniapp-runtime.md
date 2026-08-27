# M8-WEBMCP-001 — 全量 MiniApp WebMCP Runtime

- **Project**: FAB-P0001 / TFI
- **Stage**: M8 Mini Apps
- **Status**: IN_PROGRESS
- **Branch**: `feat/tfi-webmcp-miniapp-runtime`
- **PR**: #2169
- **Source**: `source/2026-08-27-webmcp-miniapp-runtime.md`
- **ADR**: `decisions/ADR-0010-webmcp-foreground-rust-background.md`

## 目标

把 WebMCP 设为所有 MiniApp 的统一前台 Agent 接口，同时保持 Rust/Native Runtime 为长任务与后台业务执行面。Tool contract 是唯一事实源，WebMCP、slash command、Mahayana Host、CLI/Bot 均由同一 Tool catalog 派生。

## 原子验收

1. SDK 能 feature-detect `document.modelContext` 并注册/注销 Tool；浏览器暂不支持时有 Fabushi-compatible fallback registry。
2. Hosted MiniApp 在加载后把真实 MCP `tools/list` 自动投影为 WebMCP；`tools/call` 仍走同一后端，不维护第二份映射。
3. read-only Tool 无写操作确认；write/destructive/open-world Tool 继续走批准语义。
4. 本地安装 MiniApp 能在桌面受控 iframe 中发现并调用当前 app Tool。
5. Android/iOS 主壳保持 Compose/SwiftUI；MiniApp surface 使用受控 WebView/WKWebView 时能获得同一 WebMCP bridge。
6. Rust Host 对便携本地 Runtime 暴露 tool list + call，页面关闭后 Rust Job/状态不随 WebMCP teardown 丢失。
7. Marketplace/BotFather 新 MiniApp 验收强制 WebMCP contract，slash command 从 Tool metadata 派生。
8. SDK unit/contract tests、web/desktop/native compile/test、MiniApp WebMCP E2E 通过。
9. PR 通过 required checks 并合入 protected `main`。
10. exact-main desktop/mobile packaged simulated-user E2E 有截图/视频/trace/report evidence；发布新版本 GitHub Release。

## 开源优先

研究并采用：WebMCP Community Group specification/repository、OpenAI WebMCP/Site Tools 产品模型、MCP/MCP Apps。未复制第三方实现代码；Fabushi 只实现标准 adapter + existing Tool contract projection。

## 已完成实现

- `frontend/packages/mcp-app-sdk/src/webmcp.ts`
- SDK export + WebMCP tests
- Hosted MiniApp `WebMcpMiniAppAdapter` 自动 `tools/list -> WebMCP -> tools/call`
- 所有 `/miniapps/[id]` 页面统一挂载 adapter
- 原始需求与 ADR 已持久化

## 当前缺口

- Rust `mahayana-app-host` 尚需把已有 `DeepSeekJsHost::call_tool_json` 暴露为 Host `runtime.call`。
- 桌面 installed MiniApp iframe 目前只注入 CloudStorage bridge，需增加 WebMCP bridge。
- 当前 native mobile 只有 Compose/SwiftUI 市场 UI，需增加 MiniApp Web surface，而不是恢复 WebView 主壳。
- marketplace/generation policy、WBS/acceptance/status/changelog、版本、CI/main/release 仍需闭环。

## 证据

见 `evidence/M8-WEBMCP-001/README.md`。
