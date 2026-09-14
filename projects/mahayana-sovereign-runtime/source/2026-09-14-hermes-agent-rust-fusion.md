# 2026-09-14 Hermes Agent -> Mahayana Rust fusion source

- **Project:** FAB-P0005 / MSR
- **Source type:** user requirement + open-source architecture/provenance audit
- **Fabushi base:** `bhrumom/fabushi@387ae731c3677d9d3023d400f1da60d7ac958a4f`
- **Upstream:** `NousResearch/hermes-agent@09b74dea642782da2bc24ecc3fafd340de8fc982`
- **Upstream license:** MIT (`LICENSE`, Copyright (c) 2025 Nous Research)
- **Recorded:** 2026-09-14

## Source requirement

Fuse the useful capabilities and interaction semantics of Hermes Agent into the existing Mahayana architecture rather than shipping Hermes as a separately installed runtime. The installed Fabushi application must carry the required runtime itself. Mahayana remains the sole product/runtime identity and the implementation of the imported runtime semantics is Rust-owned.

The first acceptance-critical user experience is a native assistant transcript in which one real Mahayana turn can show ordered reasoning/thinking, streamed assistant text, tool start/progress/result, additional assistant text, approval/clarification when needed, and final completion without projecting the run as a separate "work completed" report card.

The long-term scope is full capability parity where compatible with Fabushi: sessions/resume/interrupt/branch/rewind/compress, streaming, reasoning, tools, approvals/clarification/secrets, subagents/delegation, terminal/process, MCP, artifacts/preview/files, model switching, browser control, voice/wake, multi-client fanout/replay, API/ACP-compatible integration surfaces, and cross-surface transcript parity. Existing Mahayana capabilities must be reused; no second agent kernel or second desktop runtime may be created.

## Open-source-first audit

Pinned Hermes main was read from GitHub at `09b74dea642782da2bc24ecc3fafd340de8fc982` so this task does not depend on a moving `main`.

Key proven design points to adapt:

1. `tui_gateway/transport.py`: one dispatcher can write through stdio or WebSocket transports; live sessions can fan events out to multiple attached clients. A slow subscriber is bounded/detached rather than blocking the producing turn.
2. `tui_gateway/event_replay.py`: per-session monotonically increasing `seq`, process-scoped `replay_epoch`, bounded replay rings, byte/session caps, and a truncation watermark force history refetch when replay is incomplete.
3. `apps/shared/src/gateway-events.ts`: one typed event-name/payload map covers `message.*`, `reasoning.*`, `tool.*`, approval/clarify/secret, session, subagent, terminal, browser, voice and other events; backend and frontend registries are contract-tested against each other.
4. `website/docs/developer-guide/programmatic-integration.md`: ACP, TUI JSON-RPC (stdio/WebSocket), and HTTP/SSE expose the same core rather than separate agent implementations.
5. Desktop message stream: `message.delta` appends assistant text; `reasoning.delta` updates reasoning; `message.interim` seals already-streamed commentary so later tool calls and final text do not overwrite it; `message.complete` settles the active turn.

## Known upstream failure modes that Mahayana must not copy

Recent Hermes issue history shows failures where intermediate assistant commentary was persisted but not rendered, or WebSocket/reconnect behavior caused a completed reply to be absent until reload. Therefore Mahayana acceptance must explicitly cover:

- multiple text segments separated by tools in the same turn;
- idempotent tool start/update/complete by `tool_id`;
- reconnect/replay without duplicate or missing parts;
- replay truncation -> authoritative history refetch;
- slow-client isolation/backpressure;
- completion never replacing earlier interim text;
- a completed run remaining visible without app restart.

## Fabushi starting-state diagnosis

At the pinned Fabushi base, `desktop/src/messaging-shell-v2.tsx` still models a transcript row as one flat `DisplayMessage` containing `text`, `kind = message | action | thinking`, `operationId` and action status. `chat.delta` mutates one streaming text row.

In parallel, `desktop/src/mahayana-agent-workbench.tsx` builds a second run projection, while `mahayana-agent-inline-report.tsx`, `mahayana-agent-inline-compat.ts`, `mahayana-agent-transcript-semantics.ts` and parity CSS/DOM hooks project that run back into Messenger. This split is the structural reason normal assistant work appears as a report/workbench card instead of one ordered assistant turn.

## Architectural decision for this source

Adapt Hermes semantics, not its Python runtime identity:

- Rust owns gateway event contracts, ordering/replay, session truth and transcript-part projection.
- Existing Mahayana agent/tool/MCP/session implementations remain the executors.
- stdio, Electron/native bridge, WebSocket/API/ACP adapters consume the same Rust gateway semantics.
- React/Swift/Kotlin render ordered transcript parts; they do not invent lifecycle truth.
- Existing Workbench may remain as an optional inspector during migration but is not the normal assistant reply surface.
- The legacy Hermes installer mini-app is not the architecture for this fusion and must not be required for product use.

## Traceability

Initial implementation task: `MSR-107-hermes-gateway-transcript-foundation.md`.
Full Hermes capability parity remains a multi-task MSR program; completion is allowed only when the capability matrix and cross-surface packaged E2E evidence have no required gaps.