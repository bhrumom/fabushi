# 大乘单一身份多构件 MCP Apps 市场任务

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 8`  
文档状态：等待产品审核，尚未合并到 `main`，不得启动实施 Action。

## 一句话目标

> 一个小程序只有一个插件身份、一个版本、一套 Tool 契约和一套 MCP Apps UI，但同一个签名 Release 可以包含桌面原生 CLI、网页 JavaScript/WebAssembly 等多个平台构件；安装器识别平台后只下载当前设备需要的内容。

## 全球法布施

同一个 `global-dharma` Release 包含：

- common：manifest、tools、permissions、MCP Apps UI、Skills、workflows；
- native artifacts：macOS、Windows、Linux 对应 OS/CPU 的 CLI；
- web-wasm artifact：iOS、Android、桌面 WebView、普通 Web/PWA 使用的 Worker、JavaScript adapter 和 WebAssembly。

平台安装：

```text
桌面 App = common UI + 当前 OS/CPU native CLI
纯 CLI    = 必要 common + 当前 OS/CPU native CLI
移动端    = common UI + web-wasm
Web/PWA   = common UI + web-wasm
```

桌面端 MCP Host 通过 stdio 调用 CLI；移动/Web Host 通过 Worker/MessagePort 调用 WebAssembly/Web Runtime。两者实现同一组：

```text
global-dharma.send
global-dharma.status
global-dharma.cancel
global-dharma.logs
```

页面按钮和聊天输入必须调用同一个 Tool，不得模拟网页点击。

## 关键原则

- 不是多个独立平台插件，而是同一插件版本下的多个构件；
- plugin ID、version、Tool schema、错误码、权限和 UI resource 跨平台一致；
- 每个构件独立 URL、SHA、大小、provenance 和平台条件；
- 父 Release Manifest 对完整构件图签名；
- 安装器按 platform、OS、architecture、Host version、WASM features 和 capabilities 选择最小下载集合；
- 移动端不得下载桌面二进制；
- 无头 CLI 可不下载非必要 UI；
- UI 与 Runtime 必须同版本原子激活、升级和回滚；
- native CLI 和 web-wasm 必须通过同一 Tool Contract Test；
- 推荐共享 Rust 核心同时编译为 native 和 WASM，平台适配层分别处理 stdio、fetch、Worker、IndexedDB/OPFS 等能力；
- 不要求每个插件支持所有平台，例如 ChatGPT 自动确认可以只有 desktop native 构件。

## MCP Apps 与本地网页

UI 统一使用 MCP Apps stable `2026-01-26`：

- `io.modelcontextprotocol/ui`；
- `ui://`；
- `text/html;profile=mcp-app`；
- `_meta.ui.resourceUri`；
- AppBridge、sandbox、CSP、tool visibility、host context 和 teardown。

移动/Web 的网页与 WASM 构件下载安装到本地，从安全本地 Origin、WebView 或 Service Worker 缓存加载，可在不升级大乘主 App 的情况下热更新。新增受限原生系统能力时仍可能需要主 App 更新。

## 必读顺序

1. `MULTI_ARTIFACT_MCP_APP.md`：构件、Release、平台选择、原子安装最高优先级约束；
2. `LOCAL_WEB_MCP_RUNTIME.md`：移动/Web 本地网页与 WASM Runtime；
3. `LOCAL_FIRST_MCP_APPS.md`：本地优先执行；
4. `MCP_APPS_ONLY.md`：MCP Apps、Host、安全与旧协议删除；
5. 其余 PRD、技术设计、迁移、验收和安全文档。

## 旧路径删除

仍必须删除：

- `Mcp-Session-Id`；
- 旧 GET/SSE/DELETE Session；
- SDK v1 Server；
- `createLegacyMcpHandler`、`McpAgent`、`WorkerTransport`；
- `mcp-2025-06-18` fallback；
- 大乘自定义 iframe bridge；
- 运行旧插件的兼容路径。

## 审核状态

本分支和 Draft PR 只用于审核任务方案。收到明确“审核通过”之前：

- 不合并到 `main`；
- 不启用自动合并；
- 不启动新的持续 Action；
- 不影响当前队列任务。
