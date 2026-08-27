# M8-CALL-007 — MiniApp-defined Bot call programs + 口播视频通话

- **Project**: FAB-P0001 / TFI
- **Stage**: M8 Mini Apps + M10 realtime call integration
- **Status**: IN_PROGRESS
- **Branch**: `feat/tfi-miniapp-call-program-teleprompter`
- **Source**: `../../source/2026-08-27-miniapp-defined-bot-calls-and-teleprompter.md`
- **Owner**: Fabushi / TFI

## Objective

把 MiniApp 所属 Bot 的语音/视频通话入口从 Fabushi 写死行为提升为 MiniApp manifest 可声明的扩展点，同时保证业务执行仍受当前 MiniApp MCP catalog 约束。以独立“口播” MiniApp 作为首个完整 `videoCall` 样板：视频通话打开摄像头/麦克风，显示提词器，录制，保存，并把成品视频回投同一个 Conversation。

## Architecture invariants

1. 普通联系人 1:1 语音/视频继续使用现有 Fabushi WebRTC controller；MiniApp Bot 只有在 manifest 明确声明对应 call program 时才接管按钮。
2. MiniApp call program 是 UI/流程声明，不是第二套业务 RPC。
3. 固定 IVR/DTMF 在 AI 不可用或无额度时仍可工作，但实际业务 effect 只能进入该 MiniApp MCP Tool；不能调用 host 任意业务函数。
4. AI 是可选 resolver：只能从当前 MiniApp `tools/list` catalog 选 Tool；无匹配 Tool = unavailable。
5. Conversation/Message 是唯一通话转写、数字选择、MCP result、录制视频的持久 UI/审计载体。
6. Camera/Microphone/媒体写入必须经过明确权限和 host bridge；MiniApp 不获得任意本地文件系统能力。

## Atomic acceptance tasks

| ID | Deliverable | Acceptance criterion | Objective verification | State |
|---|---|---|---|---|
| M8-CALL-007.A | Manifest call-program schema | `bot.calls.voice/video` 可声明 service-call 或 miniapp-surface；非法 surface/state/DTMF 被拒绝；release/browse 不丢字段 | Marketplace unit/HTTP contracts | IN_PROGRESS |
| M8-CALL-007.B | Bot projection | Marketplace Bot -> installed Bot -> PeerItem 保留 voice/video program | projection unit test + desktop typecheck | NOT_STARTED |
| M8-CALL-007.C | Messenger routing | MiniApp Bot call button优先进入其 program；普通 peer 仍走 WebRTC | Playwright/component acceptance | NOT_STARTED |
| M8-CALL-007.D | AI-off deterministic IVR | `aiMode=optional/disabled` 时固定 state/DTMF 可前进；MCP Tool route 仍校验 catalog | Rust/Host contract + desktop E2E | NOT_STARTED |
| M8-CALL-007.E | Teleprompter MiniApp | 独立可安装 package + Bot + videoCall；摄像头、提词、滚动、录制、停止可用 | package contract + Playwright media stub/real Chromium journey | NOT_STARTED |
| M8-CALL-007.F | Conversation media projection | recording-ready 只能由 active MiniApp call 产生，经过 host media pipeline 保存并成为同 Conversation video message | desktop integration/E2E | NOT_STARTED |
| M8-CALL-007.G | Failure/security | 权限拒绝、无设备、MediaRecorder 不支持、伪造 recording event、oversized media、保存失败可恢复 | negative tests | NOT_STARTED |
| M8-CALL-007.H | Delivery | PR protected merge -> canonical-main readback -> packaged E2E screenshot/video/trace -> newer Release | GitHub Actions / Release evidence | NOT_STARTED |

## Open-source-first record

- `livekit/rust-sdks` — Apache-2.0. Studied as a mature Rust/WebRTC reference. Fabushi already owns an existing realtime/WebRTC controller, so no dependency is added in this task; revisit for broader M10 SFU/media expansion.
- `asterisk/asterisk` — GPLv2 / alternative commercial licensing. Studied only for mature deterministic IVR/DTMF state-machine concepts. No code copied or linked into Fabushi.
- `memfactorduke/phrasa-app` — Apache-2.0 teleprompter reference. Used only as a product/interaction reference. Current teleprompter implementation uses platform-standard camera/media primitives to minimize dependency and attack surface.

## Test plan

- Marketplace normalizer rejects unknown call type, missing surface, duplicate state, invalid DTMF route and unknown next-state.
- Marketplace browse/release returns Bot call metadata unchanged after normalization.
- Bot projection test confirms call metadata survives canonical top-level and compatibility fallbacks.
- Desktop E2E proves ordinary peer voice/video remains WebRTC and MiniApp Bot routes to declared call program.
- Teleprompter E2E stubs deterministic media stream/MediaRecorder in CI, verifies script editing, scroll, start/stop, recording-ready event and Conversation video-message projection; packaged real Chromium journey retains screenshots/video/trace.
- Security negative test rejects recording events from wrong MiniApp/call/session and refuses media over configured limit.

## Completion gate

This task may only become COMPLETED after all required implementation, tests, project records, protected merge, canonical-main readback, exact-main packaged E2E evidence and a verified newer Release are present. Until then it remains `IN_PROGRESS` / `TESTING` / `DELIVERY_BLOCKED` as appropriate.
