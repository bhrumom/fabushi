# MSR-204 source — Hermes Agent fusion

## User requirement

Primary intake: `[Fabushi:56d8581d-9da2-412d-b924-58eb88efbb56]`, 2026-09-14.
Current continuation: `[Fabushi:8480b44e-a7a0-4474-95d2-c23f64789e37]`, 2026-09-15.

The requested outcome is to study and fuse `NousResearch/hermes-agent` into the existing Mahayana/Fabushi architecture rather than embedding a second Python runtime. Required behavior includes:

- Mahayana CLI/runtime owns the agent, session, tool, approval, MCP, subagent, recovery and persistence logic in Rust.
- CLI/TUI/Desktop/Web/mobile consumers share one event-driven communication contract, following Hermes' proven single-dispatcher stdio/WebSocket architecture.
- Assistant output renders as one natural transcript turn containing ordered reasoning/text/tool/result/approval parts. Agent lifecycle metadata must not appear as a separate oversized "work complete" card in normal chat.
- The installed Fabushi application must be self-contained; it must not require a Hermes-style post-install download/bootstrap of the Hermes runtime.
- Existing Mahayana capabilities are reused. This task must not create a second agent kernel, second UI runtime, or vendor-owned product protocol.
- Full Hermes capability parity is a multi-round objective and may only be marked complete with source-backed capability mapping plus objective CI/E2E evidence.

## Pinned upstream

- Repository: `https://github.com/NousResearch/hermes-agent`
- Original audited revision: `5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04` (upstream `main` when MSR-204 started).
- Continuation re-audit revision: `4d55ca91656ac5f83e1506679b7f81e0238e5e16` (upstream `main` observed on 2026-09-15 before continuing `[Fabushi:8480b44e-a7a0-4474-95d2-c23f64789e37]`).
- License: MIT, copyright Nous Research (2025). Substantial copied/ported implementation would require preserving the upstream notice; this task primarily adapts architecture/event semantics in first-party Rust/TypeScript code.

## Upstream design evidence used for this round

- `tui_gateway/AGENTS.md`: newline-delimited JSON-RPC over stdio with server→client requests and event notifications; the gateway, not the renderer, owns execution/session semantics.
- `website/docs/developer-guide/programmatic-integration.md` at `4d55ca91656ac5f83e1506679b7f81e0238e5e16`: the same TUI Gateway JSON-RPC protocol is available over stdio or WebSocket and drives the same `AIAgent` core.
- The current Hermes method catalog includes prompt submission/background work, session create/list/activate/close/interrupt/history/compress/branch/title/usage/status, clarify/config/command dispatch, MCP reload, process stop, delegation/subagent controls, spawn-tree persistence, terminal resize, clipboard and image attachment.
- Current streamed event semantics include `message.delta`, `message.complete`, `tool.start`, `tool.generating`, `tool.complete`, `gateway.ready`, `request.cancel`, plus session/error events.
- Approvals, clarification, sudo/secret, vault and desktop read/act interactions are server→client JSON-RPC requests with matching response ids; reconnect surfaces still-open requests rather than silently losing them.
- Hermes rewind is a guarded destructive transcript operation with durable row ids and explicit confirmation flags; this remains a parity item for Mahayana session ownership rather than something to emulate in renderer state.

## Fabushi baseline at intake

Canonical `main` at original intake: `13188628da46b88db843c9c5b4d59100233e3a21`.
Canonical `main` observed for the 2026-09-15 continuation: `944461ea020966dd76905c7e601d9e6c121ae4b3`.

Original mismatch:

- `desktop/src/messaging-shell-v2.tsx` modeled an assistant response primarily as one `DisplayMessage.text` plus `kind = message | action | thinking`.
- `chat.delta` appended plain text into a streaming message, while `operation.started`, `model.routed` and `agent.step` were separately projected as thinking/action rows.
- `mahayana-agent-workbench.tsx` maintained a second `AgentRunProjection` state model.
- `mahayana-agent-inline-report.tsx` and DOM compatibility/semantic layers portaled that second model back into chat, producing the oversized task/report card instead of a native assistant turn.

## Current branch state before this continuation repair

PR `#2620`, branch `feat/msr-204-hermes-gateway-transcript`, had already advanced beyond the stale task text:

- Messenger has an `assistant-turn` projection and renders `MahayanaAssistantTurnView` as the primary owned-agent transcript path.
- The default Desktop bootstrap no longer mounts `MahayanaAgentInlineReport`.
- Rust `mahayana-gateway` projects native `mahayana_core::RuntimeEvent` values into the versioned gateway envelope, including reasoning/text/tool/approval/completion events and bounded replay.
- `mahayana-gateway` dispatches `prompt.submit`, session list/history/interrupt, approval response and replay RPCs against the existing Mahayana runtime rather than a second kernel.
- `mahayana-cli/src/bin/mahayana-gateway.rs` runs the production Mahayana runtime through FFI, pumps native runtime events into the gateway projection, and exposes newline-delimited JSON-RPC over stdio with immediate flushing.

Exact-head E2E at `471da853c4f6d531b78ec971c0a67a01d8b897b2` exposed two remaining transcript-wiring bugs that this continuation is repairing rather than hiding:

1. the final legacy assistant `chat.message` reconciled text but did not mark the `AssistantTurn` completed when that producer path did not emit a later renderer-visible `operation.completed`;
2. self-hosted Bot invocation is accepted through the existing Workbench command bridge, so Messenger must observe command dispatch/acceptance and bind the accepted operation id into the same `AssistantTurn` lifecycle.

The broader objective is still not complete: WebSocket transport parity, the larger Hermes method/capability matrix, authoritative Rust recovery/persistence parity, exceptional-state Inspector separation, protected-main merge and canonical packaged E2E/release evidence remain required before full Hermes fusion can be claimed.