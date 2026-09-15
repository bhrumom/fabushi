# MSR-204 — Hermes-style Rust gateway and native transcript

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-204
- **Status:** in-progress
- **Owner:** Fabushi engineering
- **Started:** 2026-09-15
- **Starting canonical main:** `944461ea020966dd76905c7e601d9e6c121ae4b3`
- **Implementation branch:** `feat/msr-204-hermes-turn-transcript`

## Source requirement

Fuse the proven architecture and user experience of `NousResearch/hermes-agent` into Mahayana rather than embedding Hermes as a second runtime. The Mahayana implementation must remain Fabushi-owned and Rust-first: runtime/session/tool/approval/subagent/persistence/protocol ownership belongs to Rust, while Electron/React and native clients render the canonical event stream. The first user-visible requirement is that one real Mahayana run renders `thinking/reasoning -> assistant text stream -> tool start/result -> more assistant text -> complete` as one native assistant turn, not as the current separate “工作完成 / 执行完成，最终结果如下” workbench card.

## Pinned upstream audit

- Hermes repository: `NousResearch/hermes-agent`
- Audited branch: `main`
- Audited commit: `d128ce2e25634105c81dfcc9c7a1678d6c1db038` (2026-09-15)
- Reuse strategy: behavioral/architectural fusion, not Python source embedding.
- Proven patterns selected for adaptation:
  - one dispatcher over transport abstractions rather than separate CLI/Desktop semantics;
  - ordered, fine-grained assistant/tool/reasoning lifecycle events;
  - `message.interim` boundaries during tool-using turns;
  - transcript state as assistant messages composed of ordered parts;
  - replay/sequence metadata so reconnect/restart can reconstruct state;
  - tools/approvals/subagents update existing turn parts rather than creating independent task-completion cards.

## Scope for this atomic task

1. Define a Mahayana-owned versioned turn-event contract that can carry text, reasoning, tool lifecycle, approval/clarify, subagent lifecycle, sequence and replay metadata without depending on Hermes types.
2. Add the Rust gateway/protocol foundation so the same event semantics can be serialized for stdio/CLI and Desktop/native transports.
3. Add a renderer-side `AssistantTurn`/ordered-parts projection and make Desktop Messenger consume the fine-grained events into one turn.
4. Stop using `MahayanaAgentInlineReport` as the default chat-completion surface. Keep workbench information available only as secondary inspector/debug metadata during migration.
5. Add contract/reducer tests that prove one operation can evolve through reasoning -> text -> tool running -> tool complete -> text -> complete while retaining one assistant turn identity.
6. Record the remaining full-Hermes parity surface as follow-up atomic tasks; do not claim repository-wide Hermes parity from this foundation slice.

## Acceptance criteria

- **A1 contract:** a versioned event envelope includes protocol version, session/conversation identity, turn/operation identity, sequence, timestamp, replay epoch and typed payload/event kind.
- **A2 same semantics:** text, reasoning, tool, approval/clarify and subagent lifecycle event names have one canonical Mahayana contract usable by CLI/Desktop/native adapters.
- **A3 transcript:** Desktop projects all events for one operation into one ordered assistant turn with parts; tool completion updates the matching tool part in place.
- **A4 no completion bridge:** successful ordinary runs do not render the legacy “执行完成，最终结果如下” completion bridge as the primary response.
- **A5 compatibility:** existing `chat.message` / `chat.delta` producers continue to work through an adapter during migration.
- **A6 verification:** focused contract/reducer tests and required PR GitHub Actions pass.
- **A7 delivery:** protected merge to canonical `main`, canonical-main readback, packaged Desktop E2E evidence and Release evidence are required before this task can be marked passed under repository governance.

## Non-goals for MSR-204

MSR-204 is not the final claim that every Hermes feature has been ported. Session branching/rewind/compression/steer, voice/wake, all terminal/process/browser/file/artifact surfaces, complete subagent/delegation parity, and full mobile/web rendering parity remain explicit follow-up work until objectively evidenced.

## Evidence log

- 2026-09-15: canonical Fabushi `main` read as `944461ea020966dd76905c7e601d9e6c121ae4b3`.
- 2026-09-15: Hermes `main` read as `d128ce2e25634105c81dfcc9c7a1678d6c1db038`.
- 2026-09-15: current Fabushi contract verified to expose flat `chat.message` + `chat.delta` plus separate `agent.step`/`model.routed`/approval/operation events.
- 2026-09-15: current Desktop inline report verified to hard-render `执行完成，最终结果如下` for completed runs.

## Current blockers / next gate

Implementation and CI are pending. Do not mark passed until PR merge + post-main product delivery gates are satisfied.