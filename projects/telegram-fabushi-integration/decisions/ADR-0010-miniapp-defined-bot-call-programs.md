# ADR-0010 — MiniApp owns its Bot call program; Fabushi owns the safe call host

- **Status**: Accepted for M8-CALL-007 implementation
- **Date**: 2026-08-27
- **Project**: FAB-P0001 / TFI
- **Source**: `../source/2026-08-27-miniapp-defined-bot-calls-and-teleprompter.md`

## Context

Fabushi already has ordinary 1:1 WebRTC calls and an MCP-only `MiniAppServiceCallSession` domain contract. The missing product boundary is the Bot call button itself: every MiniApp needs to decide what its associated Bot does when voice/video is clicked. Hardcoding one 10086-like flow in the Messenger would prevent different MiniApps from defining their own service, camera, recording, guided-training or other call experiences.

The platform must also support two simultaneous realities: AI can dynamically understand natural language when available, but a MiniApp's deterministic service must still work when AI quota is exhausted, the AI provider is unavailable, or the user disables AI.

## Decision

1. `bot.calls.voice` and `bot.calls.video` become versioned MiniApp manifest extension points.
2. A call program is declarative and uses one of two host execution forms:
   - `service-call`: deterministic IVR/state-machine + optional constrained AI resolver; business effects still terminate exclusively in that MiniApp's MCP `tools/call`.
   - `miniapp-surface`: the MiniApp supplies the call UI surface while Fabushi supplies constrained camera/microphone/media/conversation bridges.
3. The manifest may declare AI as `optional` or `disabled`; `required` is deliberately not the default because AI quota/provider state must not disable a deterministic service path. An optional AI layer falls back to the declared IVR program when unavailable.
4. IVR states are finite and explicit. DTMF routes can transition state, end the call, go back, or request a MiniApp MCP Tool. Runtime must validate any Tool against the live catalog before invocation.
5. The Messenger routes MiniApp Bot call buttons through the declared program before considering ordinary peer WebRTC. Ordinary peer calls are unchanged.
6. MiniApp-surface call UI runs in a constrained frame/host surface. Camera/microphone are explicit capabilities; the app does not receive arbitrary filesystem access.
7. Recording output crosses a dedicated host message/bridge tied to the active MiniApp call identity. The host, not the MiniApp, owns media persistence and Conversation message creation.
8. The independent teleprompter MiniApp is the reference implementation for `video -> miniapp-surface`: camera preview, script overlay, local scroll controls, MediaRecorder, then host-mediated Conversation video projection.
9. `ConversationId` remains the only durable thread for call transcript/events/results/media. No parallel call-chat database is introduced.

## Open-source-first decision

- LiveKit Rust SDKs (Apache-2.0) were reviewed for mature realtime architecture. Existing Fabushi realtime/WebRTC code remains the implementation base for this slice to avoid parallel media stacks.
- Asterisk (GPLv2) was reviewed for IVR/DTMF concepts only. No Asterisk source is copied or linked; the declarative state-machine contract is implemented independently.
- Phrasa (Apache-2.0) was reviewed as a teleprompter UX reference. No source is copied; standard browser/Electron media primitives are sufficient for the reference MiniApp.

## Security invariants

- A MiniApp cannot claim a Tool that is absent from its live MCP catalog and have the host execute it.
- AI resolver cannot invoke host-native business capabilities as a fallback.
- Fixed IVR cannot bypass MCP approval, payment confirmation, sensitive-input or permission checks.
- A recording-ready event must match the active call id + MiniApp id + Conversation id; cross-app or stale-call events are rejected.
- Camera/microphone are released on stop/end/error/unmount.
- Original raw recording is not silently uploaded outside the user's Conversation/media path.

## Consequences

- MiniApps can design materially different call experiences without forking Messenger.
- AI quota becomes an enhancement concern rather than a hard availability dependency for deterministic services.
- Bot/Marketplace projection must preserve call metadata end-to-end.
- Desktop/mobile hosts require a small, stable call-surface bridge instead of app-specific UI code.
- M8-CALL-002/003/004/005 remain relevant for full STT/MCP Host/Composer wiring; M8-CALL-007 integrates the call-program boundary and first video-surface implementation without creating a competing business executor.

## Rejected alternatives

- Hardcode a universal 10086 menu into Fabushi: rejected; ownership belongs to the MiniApp.
- Give each MiniApp unrestricted native call code: rejected; breaks sandbox and cross-platform governance.
- Let AI directly execute business logic: rejected by existing ADR-0008 service-call MCP-only invariant.
- Require AI for every voice service: rejected because the user explicitly requires deterministic service continuity without AI quota.
