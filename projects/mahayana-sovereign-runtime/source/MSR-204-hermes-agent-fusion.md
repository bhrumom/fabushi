# MSR-204 source — Hermes Agent fusion

## User requirement

Reference: `[Fabushi:56d8581d-9da2-412d-b924-58eb88efbb56]`, 2026-09-14.

The requested outcome is to study and fuse `NousResearch/hermes-agent` into the existing Mahayana/Fabushi architecture rather than embedding a second Python runtime. Required behavior includes:

- Mahayana CLI/runtime owns the agent, session, tool, approval, MCP, subagent, recovery and persistence logic in Rust.
- CLI/TUI/Desktop/Web/mobile consumers share one event-driven communication contract, following Hermes' proven single-dispatcher stdio/WebSocket architecture.
- Assistant output renders as one natural transcript turn containing ordered reasoning/text/tool/result/approval parts. Agent lifecycle metadata must not appear as a separate oversized "work complete" card in normal chat.
- The installed Fabushi application must be self-contained; it must not require a Hermes-style post-install download/bootstrap of the Hermes runtime.
- Existing Mahayana capabilities are reused. This task must not create a second agent kernel, second UI runtime, or vendor-owned product protocol.
- Full Hermes capability parity is a multi-round objective and may only be marked complete with source-backed capability mapping plus objective CI/E2E evidence.

## Pinned upstream

- Repository: `https://github.com/NousResearch/hermes-agent`
- Audited revision: `5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04` (current upstream `main` when this task started)
- License: MIT, copyright Nous Research (2025). Substantial copied/ported implementation would require preserving the upstream notice; this task primarily adapts architecture/event semantics in first-party Rust/TypeScript code.

## Upstream design evidence used for this round

- `tui_gateway/AGENTS.md`: one JSON-RPC backend serves TUI, Desktop and dashboard; renderer owns presentation while backend owns sessions/tools/model calls.
- `tui_gateway/transport.py`: transport abstraction allows the same dispatcher over stdio and WebSocket, including bounded fanout/replay recovery semantics.
- `tui_gateway/ws.py`: token events are coalesced (~30 fps) while non-streaming terminal/tool/approval events flush buffered tokens first to preserve order.
- `apps/shared/src/gateway-events.ts` and `gateway-events.json`: typed shared event catalog with drift tests; key events include `message.start`, `message.delta`, `reasoning.delta`, `message.interim`, `tool.start`, `tool.complete`, `approval.request`, `clarify.request`, subagent events and `message.complete`.

## Fabushi baseline at intake

Canonical `main`: `13188628da46b88db843c9c5b4d59100233e3a21`.

Observed current mismatch:

- `desktop/src/messaging-shell-v2.tsx` models an assistant response primarily as one `DisplayMessage.text` plus `kind = message | action | thinking`.
- `chat.delta` appends plain text into a streaming message, while `operation.started`, `model.routed` and `agent.step` are separately projected as thinking/action rows.
- `mahayana-agent-workbench.tsx` maintains a second `AgentRunProjection` state model.
- `mahayana-agent-inline-report.tsx` and DOM compatibility/semantic layers portal that second model back into chat, producing the oversized task/report card instead of a native assistant turn.

This task starts by replacing that split transcript model with a Mahayana-owned ordered-part turn contract and a Rust gateway event contract, while preserving a narrow legacy-event adapter during migration.
