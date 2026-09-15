# Hermes Agent upstream audit — 2026-09-15

## Pinned source

- Repository: `https://github.com/NousResearch/hermes-agent`
- Branch: `main`
- Commit: `d128ce2e25634105c81dfcc9c7a1678d6c1db038`
- License: MIT, copyright Nous Research (2025).
- License obligation if source or substantial portions are copied: preserve the upstream copyright notice and MIT permission notice.
- Provenance action for MSR-204: adapt architecture, protocol semantics and behavior behind Mahayana-owned contracts; do not wholesale-copy Python runtime source into the product. The new Rust/TypeScript implementation in this branch is Fabushi-authored rather than a bundled Hermes runtime.

## Relevant upstream paths inspected

- `tui_gateway/transport.py`: transport abstraction lets one dispatcher emit over stdio and WebSocket semantics; includes ordered fanout/backpressure behavior.
- `tui_gateway/ws.py`: WebSocket surface preserves ordering around high-frequency token events.
- `tui_gateway/contracts/events.py`: typed payload/event contracts.
- `tui_gateway/prompt_turn.py`: emits fine-grained message stream events such as `message.delta` and interim/final boundaries.
- `apps/desktop/src/app/session/hooks/use-message-stream/gateway-event/message-stream.ts`: Desktop folds message/reasoning events into one session transcript and finalizes the same assistant turn on `message.complete`.
- `apps/desktop/src/lib/gateway-events.ts`: shared event-name contract for the Desktop gateway.

## Proven design decisions selected for Mahayana

1. **Transport-independent semantic dispatcher.** CLI/stdio and Desktop/WebSocket should not invent different event meanings.
2. **Turn-scoped ordered events.** Text/reasoning/tool/approval/subagent lifecycle events share session + turn identity and sequence order.
3. **Interim text boundaries.** Text emitted before/around tools can be sealed without ending the logical turn.
4. **In-place tool state.** `tool.start` creates/updates one tool part; `tool.complete` resolves that same part.
5. **Replay-aware stream.** Clients can recover from reconnect/restart without renderer-local journals becoming authority.
6. **Renderer as projection, not runtime authority.** Desktop receives events and projects state; execution truth remains in the gateway/runtime.

## Fabushi gap observed on starting main

Fabushi currently exposes a flat `chat.message` / `chat.delta` transcript contract and separately projects `agent.step`, `model.routed`, approvals, operation lifecycle and workbench state. Desktop then bridges the workbench back into chat through `MahayanaAgentInlineReport`, which explicitly renders a completion banner. This makes ordinary agent execution look like a task monitor/card instead of one natural assistant turn.

## Adaptation boundary

Mahayana will use its existing Rust workspace (`mahayana-host-protocol`, runtime, conversation/session, tool host, MCP runtime, orchestrator and native agent crates) as the implementation substrate. Hermes is an architecture/reference upstream for this work, not a bundled runtime dependency.