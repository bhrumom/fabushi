# ADR-0008 — MiniApp Service Call 复用统一 Conversation / MiniApp / MCP / Realtime

- **状态**：Accepted
- **日期**：2026-08-23
- **决策所有者**：Fabushi / TFI
- **来源**：`../source/2026-08-23-miniapp-ai-service-calls.md`

## Context

MiniApp 需要具备类似 10086 客服电话的交互：传统 DTMF 菜单、语音 AI 直接理解需求、实时通话转写进入聊天，以及直接用聊天文字驱动服务。如果为“电话客服”单独建立一套会话、消息、Bot 状态或业务 action executor，会违背 ADR-0003 的统一 Conversation/Message 原则，并导致权限、同步、历史记录、MCP 能力边界和跨端 UI 分叉。

用户进一步明确：MiniApp 的实际功能全部通过 MCP 暴露；AI、DTMF、聊天输入本身不得直接实现业务。如果 MiniApp 没有对应 MCP Tool，则该功能就是不可用。

## Decision

1. 定义 `MiniApp Service Call` 为 MiniApp 的一种实时服务会话，而不是第二套 IM。
2. 每个 service call 必须绑定已有 `ConversationId`；实时转写、数字输入、MCP 调用结果和文字驱动以该 Conversation 为唯一 UI/审计载体。
3. DTMF、speech transcript、chat text 在 Rust 核心归一化为 `MiniAppServiceCallInput`，共享同一状态机。
4. **MCP 是 MiniApp 客服业务功能唯一执行边界。** 所有业务查询、修改、支付前置操作或其它 MiniApp 功能最终都必须落为该 MiniApp 的 `tools/call`；不得建立独立 action executor 绕过 MCP。
5. DTMF 进入确定性 `digits -> MCP Tool + arguments` 路由；聊天框发送纯数字复用同一路由。路由引用未由当前 MiniApp 暴露的 Tool 时必须拒绝。
6. final speech transcript 与非数字 chat text 进入受限 MCP Tool resolver。Resolver 只能看到当前 MiniApp `tools/list` 得到的 catalog，并只能从该 catalog 选择 Tool 与构造参数。
7. 如果 resolver 无法在当前 catalog 找到满足需求的 Tool，则返回 `McpCapabilityUnavailable`；不得调用宿主其它能力、不得创造未声明 Tool、不得让通用 Agent 代替 MiniApp 完成功能。
8. Resolver 即使返回一个 Tool 名称，Rust domain 仍必须再次验证该 Tool 属于当前 MiniApp catalog；catalog 外选择必须拒绝，形成 defense-in-depth。
9. MiniApp bridge 增加独立 `ServiceCall` capability；voice/hybrid 与 speech 输入还要求 `Microphone`。MCP Tool 自身仍沿用现有 MCP Apps 风险注解、授权和高风险确认语义。
10. MCP result 作为 service-call audit 记录，并投影回同一个 Conversation，可派生 spoken response / display response。
11. 媒体传输复用 M10 realtime/signaling/WebRTC；未来 PSTN/SIP 只作为 adapter，不改变核心会话或 MCP 执行模型。

## Alternatives considered

- **独立客服/电话消息栈**：拒绝。会产生第二套会话、历史、权限和同步模型。
- **仅使用 WebRTC CallSession，不建 MiniApp service-call contract**：不足。无法表达 DTMF、MCP Tool catalog、文字驱动和 MiniApp capability。
- **所有输入直接交给 LLM 并由 Agent 执行**：拒绝。会让模型越过 MiniApp 实际功能边界；MiniApp 未提供的功能不能由通用 Agent 补做。
- **DTMF 在客户端直接调用本地业务函数**：拒绝。数字按键与聊天数字都必须映射到 MCP Tool，确保所有入口共享同一业务执行面。
- **另建 MiniApp action executor，再由其可选调用 MCP**：拒绝。会形成第二个业务执行通道并破坏可审计性。

## Consequences

- Electron/iOS/Android 可共享同一 Rust contract。
- 聊天与语音客服天然连续，用户可在同一会话里从说话切换到打字或数字选择。
- MiniApp 的“能不能做某件事”由其真实 MCP Tool catalog 决定，AI 不再拥有超出应用能力的隐式权限。
- MCP `tools/list` 需要在 service-call 启动/刷新时形成可审计 capability snapshot；`tools/call` 结果需要回投 Conversation。
- 后续需要补齐 host-side STT、constrained MCP resolver、MCP Host executor、WebRTC/SIP adapter、转写/message projection 与跨端 E2E。
- 协议字段扩展需要 CI contract coverage；若出现不可兼容 wire change，再单独升级 messaging protocol version。

## Security invariants

- Tool catalog 必须来自目标 MiniApp 的真实 MCP session，不得由模型自行声明。
- Tool selection、DTMF route、实际 `tools/call` 三层都绑定同一个 `mini_app_id` / service-call session。
- destructive/open-world/write Tool 必须继续执行现有确认、授权、sensitive-input 和审计策略。
- 无 Tool = 无能力；错误、超时、撤销授权都不得触发 fallback 到非 MCP 业务路径。

## Rollout / migration

先以新增 capability 和 additive serde enum/struct 落地，不迁移既有 MiniApp 会话。客户端未使用新 capability 时行为不变。现有 MCP Apps `tools/list` / `tools/call` runtime 作为后续 Host 接线基线，不新增平行 RPC 协议。

## Supersedes / Superseded by

- 补充 ADR-0003 与 ADR-0006，不取代它们。
- 本 ADR 在同一未合并实现流中吸收 2026-08-23 用户补充的 MCP-only execution 要求；早期“AI intent/action executor”表述以本版为准。
