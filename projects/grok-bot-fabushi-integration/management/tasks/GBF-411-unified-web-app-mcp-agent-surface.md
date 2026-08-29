# GBF-411 — 统一 Web MCP / App MCP / 原生语义 Agent Surface

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-411`
- Stage: `M4`
- Requirement IDs: `GBR-005`, `GBR-007`, `GBR-010`, `GBR-016`, `GBR-017`, `GBR-018`
- Status: `IN_PROGRESS`
- Source: `source/2026-08-29-unified-web-app-mcp-agent-surface.md`
- Branch: `codex/interactive-runner-mcp`
- PR: `#2205`
- Started: `2026-08-29 20:10 +08:00`
- Updated: `2026-08-29 22:00 +08:00`
- Completed: —
- Risk tier: high — remote UI mutation, renderer/main loopback bridge, semantic state exposure, mobile/Web tool execution

## Objective

在不移除 GBF-409/410 任一能力的前提下，把 Fabushi 主 Web、Electron 主应用与移动端应用塑造成可由 AI 结构化理解和操作的 Agent Surface；远程 MCP 发现设备后优先调用设备公布的 App MCP/WebMCP 工具，第三方应用无 App MCP 时继续通过完整原生语义 Computer Use 控制，并把截图/坐标降为最后兜底。

## In scope

- 统一 `fabushi.app.*` 工具合同、schema、annotations、generation/stale-reference 语义。
- WebMCP imperative adapter 与不支持 WebMCP 浏览器的受控 fallback surface。
- Electron renderer 语义快照/查询/动作/等待/断言实现。
- Electron main loopback bridge、随机 bearer、0600 discovery、请求上限/并发/超时/退出清理。
- 打包 `fabushi-computer` stdio MCP 注册 App MCP 工具并动态连接运行中的 Fabushi。
- 远程设备工具目录与 Runner package verifier/CI 的增量覆盖。
- 原生控制路由工具，显式保留 browser DOM/AX、native AX/UIA/AT-SPI/X11 与 screenshot fallback。
- iOS/Android 主应用 Agent Surface 合同与测试 adapter；保留现有 MiniApp WebMCP Surface。
- 脱敏 trace / generated regression 对 App MCP 调用的支持。

## Out of scope

- 任意 JavaScript、Shell、内部函数、数据库写入或凭据读取工具。
- 取消现有本地/远程电脑控制、WebRTC、配对、MCP OAuth、secure input、OS permission 或审批边界。
- 把第三方 App 强制要求接入 Fabushi App MCP。
- 未经审查把 AI 探索 trace 自动升级为 required release gate。

## Dependencies

- GBF-409：全平台账号绑定电脑发现与完整 Computer Use。
- GBF-410：ChatGPT 远程 MCP、设备 agent、Runner 与动态 tool catalog。
- 现有 desktop/iOS/Android MiniApp WebMCP Surface。
- Electron native edge allowlist 与可信 renderer sender contract。

## Acceptance criteria

1. 现有 GBF-410 全部工具、安全上限、secure-input、公网 WSS、账号隔离、CI session 与 package/live Runner 能力不回归。
2. Web 页面在可用时通过 `document.modelContext.registerTool()` 注册稳定 `fabushi.app.*` 工具；无 WebMCP 时同合同可通过 `window.__fabushiAppMcp` 供受信宿主调用。
3. Desktop App MCP 返回结构化 screen/route/generation/elements，不返回密码、token、cookie 或输入值；stable ID 优先来自 `data-agent-id` / `data-testid` / DOM id。
4. Desktop 写操作必须匹配 generation、稳定 ID、动作 allowlist、元素可见/可用状态；陈旧引用、密码字段、隐藏/禁用目标均 fail closed。
5. Electron main 只监听 loopback；discovery 文件 0600、token 高熵、body/concurrency/timeout 有界，退出删除，renderer response 与 request id 精确绑定。
6. 打包私有 MCP 公布 App MCP 工具；App 未启动时仍可列出工具并返回 unavailable，启动后可读取/操作真实 Fabushi renderer。
7. Remote MCP `list_devices` / `describe_device_tool` / `device_call` 自动转发 App MCP 工具；原 `computer_*` 工具全集仍存在。
8. 第三方应用无 App MCP 时，`computer_control_route` 推荐并验证 native/browser semantic control；语义不可用才使用 screenshot/coordinate fallback。
9. Desktop/Web/Node contract/security tests、三桌面 package E2E、interactive Runner live test、Android instrumentation、iOS UI/unit contract 全部通过并保留证据。
10. PR 经受保护 main 合并，exact-main package/E2E/Release/deployment/live MCP 验证完成后才可标记完成。

## Verification

- Lightweight: syntax/TypeScript schema review, `node --check`, focused Node tests, YAML/JSON parse, `git diff --check`, secret/material scan。
- CI: main CI, Computer Control security, Electron desktop, Native mobile, GBF security/RC, project governance。
- E2E: WebMCP tool registration/call; packaged App MCP snapshot/action/stale rejection; Runner device catalog retains computer tools and gains app tools; third-party app semantic fallback; mobile agent-surface contracts。
- Security: loopback-only, token/file mode, stale generation, sensitive values, hidden/disabled target, request/body/concurrency caps, reconnect generation, account isolation。

## Open-source survey and decision

- WebMCP draft/Chrome: adapt imperative tool contract, schema, state and cancellation; do not claim native App is a Web `Document`.
- MCP TypeScript SDK: reuse standard MCP tools and existing Streamable HTTP/stdin transports.
- Appium: learn native/web context and stable accessibility-id strategy; reject adding a second product automation daemon.
- Existing Fabushi MiniApp WebMCP: reuse bridge/security patterns and keep it intact.
- Existing `mahayana-computer` / `computer-use.js`: retain as authoritative non-App-MCP fallback.

## Implementation summary

- Added one shared six-tool `fabushi.app.*` contract and WebMCP adapter in `@fabushi/mcp-app-sdk`.
- Mounted the main Web App Agent Surface with stable IDs, redacted semantic snapshots, generation-bound actions, waits/assertions and progressive WebMCP fallback.
- Added an Electron loopback-only private bridge, trusted-renderer native edge, per-process credential/discovery, packaged App MCP client/registrar and deterministic shutdown cleanup.
- Preserved the full existing `computer_*`, secure-input, remote device, CI session and MiniApp WebMCP paths; added `computer_control_route` to prefer App MCP/browser/native semantics and use screenshots/coordinates only as fallback.
- Added native Android/iOS semantic surfaces with the same tool names, generation and sensitive-input rules, plus platform unit/UI adapters.
- Redacted App MCP/native typed values from device traces and extended content-addressed package file/tool verification.

## Evidence

- PR: `#2205` (branch update pending commit/push).
- Baseline head before GBF-411: `532faaeaae671351a00547b143e51006d14758f9`.
- Lightweight local evidence (no application/native build):
  - `chatgpt-vps-control` Node suite: 79/79 passed.
  - Electron private bridge tests: 3/3 passed.
  - shared MCP App SDK tests: 9/9 passed.
  - additive cross-platform contract validator: passed.
  - JS/CJS syntax and `git diff --check`: passed for completed rounds.
- GitHub CI/E2E/deployment/release/live ChatGPT Runner: pending.

## Risks / blockers

- Renderer/Main bridge must not become a credential or arbitrary code tunnel.
- Stable semantic IDs must survive layout changes; generated text/coordinate-only references are not writable.
- WebMCP is still an evolving web draft; adapter must be feature-detected and non-blocking.
- Native mobile background device registration remains governed by platform lifecycle; this task adds the semantic surface and CI adapters without bypassing OS background policy.

## Next action

Implement the shared semantic surface, desktop bridge and MCP registrar; add mobile/Web adapters and focused tests; push PR update and run all required GitHub Actions gates.
