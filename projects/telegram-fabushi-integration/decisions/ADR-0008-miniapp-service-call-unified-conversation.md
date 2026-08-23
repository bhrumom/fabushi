# ADR-0008 — MiniApp Service Call 复用统一 Conversation / MiniApp / Realtime

- **状态**：Accepted
- **日期**：2026-08-23
- **决策所有者**：Fabushi / TFI
- **来源**：`../source/2026-08-23-miniapp-ai-service-calls.md`

## Context

MiniApp 需要具备类似 10086 客服电话的交互：传统 DTMF 菜单、语音 AI 直接理解需求、实时通话转写进入聊天，以及直接用聊天文字驱动服务。如果为“电话客服”单独建立一套会话、消息或 Bot 状态，会违背 ADR-0003 的统一 Conversation/Message 原则，并导致权限、同步、历史记录和跨端 UI 分叉。

## Decision

1. 定义 `MiniApp Service Call` 为 MiniApp 的一种实时服务会话，而不是第二套 IM。
2. 每个 service call 必须绑定已有 `ConversationId`；实时转写和文字驱动以该 Conversation 为唯一 UI/审计载体。
3. DTMF、speech transcript、chat text 在 Rust 核心归一化为 `MiniAppServiceCallInput`，共享同一状态机。
4. DTMF 进入确定性菜单路由；final speech transcript 与 chat text 进入同一 AI intent/action resolver。
5. MiniApp bridge 增加独立 `ServiceCall` capability；voice/hybrid 与 speech 输入还要求 `Microphone`。
6. AI 只能产生经过 MiniApp capability/permission 校验的 action request；模型不得直接绕开 bridge 调用宿主权限。
7. 媒体传输复用 M10 realtime/signaling/WebRTC；未来 PSTN/SIP 只作为 adapter，不改变核心会话模型。

## Alternatives considered

- **独立客服/电话消息栈**：拒绝。会产生第二套会话、历史、权限和同步模型。
- **仅使用 WebRTC CallSession，不建 MiniApp service-call contract**：不足。无法表达 DTMF、AI intent、文字驱动和 MiniApp capability。
- **所有输入直接交给 LLM**：拒绝。DTMF 应保持确定性，AI 动作必须受权限与能力契约约束。

## Consequences

- Electron/iOS/Android 可共享同一 Rust contract。
- 聊天与语音客服天然连续，用户可在同一会话里从说话切换到打字。
- 后续需要补齐 host-side STT、intent resolver/action executor、WebRTC/SIP adapter、转写 message projection 与跨端 E2E。
- 协议字段扩展需要 CI contract coverage；若出现不可兼容 wire change，再单独升级 messaging protocol version。

## Rollout / migration

先以新增 capability 和 additive serde enum variants 落地，不迁移既有 MiniApp 会话。客户端未使用新 capability 时行为不变。

## Supersedes / Superseded by

- 补充 ADR-0003 与 ADR-0006，不取代它们。
