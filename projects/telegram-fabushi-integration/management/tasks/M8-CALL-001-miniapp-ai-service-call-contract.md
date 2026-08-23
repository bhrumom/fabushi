# M8-CALL-001 — MiniApp AI Service Call 核心契约

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `M8-CALL-001`
- Status: `IN_PROGRESS`
- Branch: `feat/tfi-miniapp-ai-service-calls`
- Started: `2026-08-23`
- Updated: `2026-08-23`
- Completed: N/A

## Objective

在 `native/mahayana-messaging` 建立 MiniApp 客服电话的统一 Rust 领域契约，使 DTMF 数字选择、实时语音转写、聊天文字和 AI 意图动作使用同一 service-call session/state machine，并可绑定既有 Conversation。

## Source requirements

- `source/2026-08-23-miniapp-ai-service-calls.md`
- `source/完整telegram融合进fabushi.txt`
- ADR-0003 统一 Conversation/Participant/Message
- ADR-0006 Mini App 权限与沙箱

## In scope

- Rust service-call ID/session/state/input/turn/action contract。
- IVR 数字菜单输入模型。
- speech transcript / text 输入统一模型。
- AI intent/action 请求与执行结果的数据契约。
- MiniApp bridge 权限与请求/响应类型。
- 将 service call 绑定现有 `ConversationId`，为聊天实时呈现提供唯一会话载体。
- 纯领域单元测试。

## Out of scope for this atomic task

- 实际云/本地 STT 模型接入。
- LLM intent resolver/provider 选择。
- WebRTC/SIP/PSTN 媒体网关。
- Electron/iOS/Android 可视拨号盘与波形 UI。
- 端到端发布验证。

## Dependencies

- `native/mahayana-messaging/src/miniapp.rs`
- `native/mahayana-messaging/src/realtime.rs`
- `native/mahayana-messaging/src/message.rs`
- M8 Mini Apps 权限桥
- M10 realtime call transport

## Acceptance criteria

1. 一个 MiniApp service call 必须绑定 `mini_app_id + actor_id + ConversationId`。
2. 输入至少支持 DTMF、speech transcript、chat text 三种来源。
3. 最终 speech/chat text 可形成 AI intent 请求；DTMF 可作为确定性菜单选择。
4. call state machine 拒绝结束后的新输入。
5. MiniApp bridge 对 service call 要求独立 `ServiceCall` 权限；语音输入同时要求 `Microphone`。
6. Rust 单元测试覆盖创建、DTMF、speech/text、AI action result、结束后拒绝输入和权限映射。

## Verification

- GitHub Actions Rust/CI workflow 编译并运行 `mahayana-messaging` 测试。
- 本机仅做源码/差异轻量检查；依据根 `AGENTS.md` 禁止本地 build/test。

## Evidence

- Commit: pending
- PR: pending
- CI: pending
- Evidence index: `evidence/M8-CALL-001/README.md`

## Risks / blockers

- 实际 STT、AI resolver、媒体 transport 尚未在本任务内接线；本任务完成后仍需后续原子任务。
- 新增协议字段需确认向后兼容策略；当前先保持 protocol version 2，仅扩展 serde 枚举，若跨版本兼容测试要求升级则另立 ADR/任务。

## Next action

实现 Rust 核心契约和 MiniApp bridge，提交 PR 并由 GitHub Actions 验证。
