# M8-CALL-001 — MiniApp MCP Service Call 核心契约

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `M8-CALL-001`
- Status: `IN_PROGRESS`
- Branch: `feat/tfi-miniapp-ai-service-calls`
- Started: `2026-08-23`
- Updated: `2026-08-23`
- Completed: N/A

## Objective

在 `native/mahayana-messaging` 建立 MiniApp 客服电话的统一 Rust 领域契约，使 DTMF 数字选择、实时语音转写、聊天文字统一进入 MiniApp MCP 能力边界：业务查询/修改只能由当前 MiniApp 已暴露并授权的 MCP Tool 执行；AI 只负责在 Tool catalog 中理解、选择与组参，不能直接执行 MiniApp 或宿主业务能力。

## Source requirements

- `source/2026-08-23-miniapp-ai-service-calls.md`
- `source/完整telegram融合进fabushi.txt`
- ADR-0003 统一 Conversation/Participant/Message
- ADR-0006 Mini App 权限与沙箱
- ADR-0008 MiniApp Service Call 统一 Conversation + MCP-only execution
- 现有 MCP Apps runtime：`frontend/packages/mcp-app-sdk` 的 `tools/list` / `tools/call`

## In scope

- Rust service-call ID/session/state/input/turn 契约。
- MCP Tool capability snapshot、DTMF→MCP Tool route、MCP semantic resolution、`tools/call` invocation request/result 契约。
- IVR 数字按键输入模型。
- chat composer 纯数字与 DTMF 共用同一 MCP route。
- final speech/chat natural-language 只在当前 MiniApp Tool catalog 中选择工具。
- 没有对应 MCP Tool 时返回 capability unavailable，禁止 fallback 到 AI/宿主直接执行。
- AI resolver 选择未暴露 Tool 时由 Rust domain 拒绝。
- MiniApp bridge 权限与请求/响应类型。
- service call 绑定现有 `ConversationId`，为聊天实时呈现提供唯一会话载体。
- 纯领域单元测试。

## Out of scope for this atomic task

- 实际云/本地 STT 模型接入。
- LLM provider 与 host-side MCP semantic resolver 实现。
- MCP HTTP/stdio transport 的生产 Host executor 接线（后续任务必须复用既有 MCP runtime）。
- WebRTC/SIP/PSTN 媒体网关。
- Electron/iOS/Android 可视拨号盘与波形 UI。
- 端到端发布验证。

## Dependencies

- `native/mahayana-messaging/src/miniapp.rs`
- `native/mahayana-messaging/src/realtime.rs`
- `native/mahayana-messaging/src/message.rs`
- `frontend/packages/mcp-app-sdk`
- M8 Mini Apps 权限桥 / MCP Apps runtime
- M10 realtime call transport

## Acceptance criteria

1. 一个 MiniApp service call 必须绑定 `mini_app_id + actor_id + ConversationId`。
2. 输入至少支持 DTMF、speech transcript、chat text 三种来源。
3. DTMF 必须确定性映射到当前 MiniApp 已暴露的 MCP Tool；route 引用未暴露 Tool 时 session 创建失败。
4. 聊天框发送纯数字必须与 DTMF 走同一 MCP route，而不是自然语言/Agent backend。
5. final speech/chat natural-language 只能生成带当前 MiniApp Tool catalog 的 MCP semantic-resolution request。
6. AI resolver 选择 catalog 外 Tool 必须被领域层拒绝；无匹配 Tool 必须返回 `McpCapabilityUnavailable`，不得产生业务执行请求。
7. 实际业务执行 effect 必须是 `InvokeMcpTool`；不得存在直接 MiniApp action executor effect。
8. call state machine 拒绝结束后的新输入。
9. MiniApp bridge 对 service call 要求独立 `ServiceCall` 权限；语音输入同时要求 `Microphone`。
10. Rust 单元测试覆盖 DTMF→MCP、聊天数字→同一 MCP route、speech/chat→MCP resolver、catalog 外 Tool 拒绝、无匹配 Tool、结束后拒绝输入、MCP result 审计和权限映射。

## Verification

- GitHub Actions Rust/CI workflow 编译并运行 `mahayana-messaging` 测试。
- 本机仅做源码/差异轻量检查；依据根 `AGENTS.md` 禁止本地 build/test。

## Evidence

- Core MCP-only refactor commit: `89cad5682e6abcb3bb9e23c132bb772db9ea0bba`
- Source requirement update: `fa2a96e953643b49465a2a5de34db9283ead048e`
- PR: #2063
- CI: latest-head pending
- Evidence index: `evidence/M8-CALL-001/README.md`

## Risks / blockers

- 实际 STT、AI MCP resolver、MCP Host executor、媒体 transport 尚未在本任务内接线；本任务完成后仍需后续原子任务。
- MCP Tool catalog 必须来自该 MiniApp 的真实 `tools/list`，不能由模型自行生成；Host 接线任务需要保留现有 MCP 审批/高风险工具确认语义。
- 新增协议字段需确认向后兼容策略；当前先保持 protocol version 2，仅扩展 serde 枚举/结构，若跨版本兼容测试要求升级则另立 ADR/任务。

## Next action

通过 GitHub Actions 验证 MCP-only Rust contract；随后落地 host-side `tools/list` catalog snapshot、AI constrained tool selection、`tools/call` executor、Conversation result projection，并继续拆分 STT/desktop-mobile UI/E2E。
