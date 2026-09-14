# MSR-107 — Hermes-style Rust gateway and native transcript foundation

- **Project:** FAB-P0005 / MSR
- **Status:** in-progress
- **Risk tier:** 1
- **Base:** `main@387ae731c3677d9d3023d400f1da60d7ac958a4f`
- **Working branch:** `feat/msr-hermes-gateway-transcript-20260914`
- **Pinned design source:** `NousResearch/hermes-agent@09b74dea642782da2bc24ecc3fafd340de8fc982`
- **Source record:** `projects/mahayana-sovereign-runtime/source/2026-09-14-hermes-agent-rust-fusion.md`

## Goal

Make the existing Mahayana runtime the single Rust-owned execution server for Hermes-class interaction semantics. A real assistant turn must render as an ordered native transcript (reasoning/text/tools/results/text/completion) rather than a separate "work completed" report/workbench card. Fabushi must not require the user to install Hermes, Python, Node packages, or a second agent runtime after installing the application.

This task is the protocol/transcript foundation for the broader Hermes capability-parity program. It must reuse the current Mahayana runtime, tool/MCP/policy/session implementations and may not create a second agent kernel.

## Atomic scope

1. Add a Rust Mahayana gateway contract that normalizes existing runtime events into typed session/turn events with a per-session sequence number and process replay epoch.
2. Add bounded reconnect replay with a truncation signal so a client either replays all missing events or performs an authoritative history refetch; it must never silently accept a hole.
3. Expose a CLI-package stdio JSON-RPC gateway entrypoint using the installed Mahayana runtime. The same contract is the future WebSocket/native bridge contract; stdio must not contain UI-only semantics.
4. Preserve one `turn_id` / operation identity across streamed text, agent activity/tool updates, approvals, completion and failure.
5. Add a desktop transcript projection that groups all runtime rows for one assistant operation into ordered parts and renders them inline with the assistant response. Legacy Workbench/report projection may remain available only as an inspector/compatibility surface, not the primary reply.
6. Stop normal assistant completion from producing the prominent `工作完成 / 执行完成，最终结果如下` inline report in the Messenger transcript.
7. Add contract tests for ordered text segments separated by tools, idempotent activity updates, completion preserving earlier interim text, replay after reconnect, replay truncation, and operation failure.
8. Record the remaining Hermes capability matrix; capabilities not implemented in this atomic task remain explicitly pending and must not be represented as complete.

## Gateway event minimum

Every emitted session-scoped event must include:

- `protocol_version`
- `replay_epoch`
- `session_id`
- `turn_id`
- monotonic per-session `seq`
- `timestamp_ms`
- `type`
- typed/JSON payload

The minimum event family for this task is:

- `message.start`
- `message.delta`
- `message.interim`
- `message.complete`
- `reasoning.delta` / `thinking.delta` when available
- `tool.start` / `tool.progress` / `tool.complete` projected from Mahayana activity/tool events
- `approval.request`
- `session.usage`
- `turn.complete`
- `turn.failed`
- `gateway.ready`

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| MSR-107-A01 | Gateway/replay implementation is Rust-owned and has no Hermes runtime dependency | dependency/source audit | pending |
| MSR-107-A02 | stdio JSON-RPC client can submit a prompt/session operation to the installed Mahayana runtime and receives session-scoped event notifications | Rust/CLI integration test | pending |
| MSR-107-A03 | per-session `seq` is monotonic; replay includes every retained event exactly once | Rust unit test | pending |
| MSR-107-A04 | replay overflow/truncation is explicit and forces history refetch semantics | Rust unit test | pending |
| MSR-107-A05 | one assistant operation can render text -> activity/tool -> result -> more text -> completion without creating separate assistant cards for lifecycle metadata | Desktop reducer/renderer tests + packaged E2E | pending |
| MSR-107-A06 | duplicate activity updates update the same part by stable step/tool identity | projection unit test | pending |
| MSR-107-A07 | final completion cannot erase already-sealed interim assistant text | projection unit test | pending |
| MSR-107-A08 | normal Messenger path no longer shows the legacy completion report as the primary reply | packaged screenshot/video | pending |
| MSR-107-A09 | current PR passes required Actions and merges through repository governance | PR/merge evidence | pending |
| MSR-107-A10 | post-main packaged Desktop run proves real Mahayana streaming/activity/completion in one transcript and survives restart/reopen | production packaged video + screenshots + trace/log | pending |

## Required packaged scenario

After protected merge, bind to the resulting exact canonical main SHA and build a fresh production packaged Desktop. In one fresh run:

1. open a Mahayana bot conversation;
2. send a request that causes at least one real runtime activity/tool event;
3. observe assistant text/thinking + running activity/tool + completed activity/tool + later assistant text + final completion in the same transcript turn;
4. verify no large `工作完成` bridge card is used as the final reply;
5. close/reopen the app or conversation and prove the completed transcript remains visible without duplicate parts;
6. retain full-session video, before/during/after screenshots, runtime/gateway event trace, and exact source/package SHA mapping.

## Explicit non-closure

MSR-107 does **not** by itself claim full Hermes parity. Full parity remains pending for session branch/rewind/compress, steer/queue controls, complete clarification/secret flow, subagent trees/delegation, terminal/process control, browser/voice/wake surfaces, ACP/API adapters and all mobile/web consumers unless separately evidenced. The project may only claim "Hermes fully fused" after the capability matrix has no required pending rows and packaged cross-surface evidence passes.