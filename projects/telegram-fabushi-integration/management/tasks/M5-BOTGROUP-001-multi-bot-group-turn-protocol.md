# M5-BOTGROUP-001 — Canonical multi-Bot group-turn event protocol

- Project: `FAB-P0001 / TFI`
- Task ID: `M5-BOTGROUP-001`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `2`
- Risk: high; canonical event ordering/idempotency

## Single objective

Define/persist the conversation-level protocol that lets one group turn contain multiple Bot participant invocations, ordered steps, tool results, partial results and final results without overwriting or duplicating each other. This task does not implement the Mahayana orchestrator.

## Dependency

`M8-BIND-001` complete/read back so Bot identity semantics are stable.

## Exact implementation allowlist

- `native/mahayana-messaging/src/bot.rs`
- `native/mahayana-messaging/src/conversation.rs`
- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/engine.rs`
- `desktop/src/selfhosted-messaging-client-v2.ts`
- `projects/telegram-fabushi-integration/evidence/M5-BOTGROUP-001/**`

Forbidden: Messenger visual rendering, Mahayana orchestrator/kernel, remote-device code, Marketplace code, workflows/version files.

## Required protocol

`GroupTurn` identity/correlation; initiator; explicit participant allowlist/routing policy; parent message; deadline/budget. Per-Bot invocation events carry Bot actor, invocation/run id and Mahayana session generation supplied by runtime. Child events cover invocation start/terminal, step start/complete, tool request/result, partial/final result. Conversation ordering plus stable event ids provide replay/idempotency.

## Acceptance

1. One group turn can persist two or more Bot invocations and multiple result lanes with deterministic replay order.
2. Re-delivered events are idempotent and cannot duplicate a result lane.
3. Cancellation/failure of one Bot does not erase completed results from other participants; group terminal state is derived from participant terminal states/policy.
4. The protocol carries correlation/causation and target metadata needed to display device/MiniApp tool results, but does not trust client UI state as authority.
5. Backward-compatible snapshot/delta readers handle conversations with no group-turn data.
6. Rust/TypeScript protocol parity tests prove round-trip stability.

## Rollback

New events are additive and feature-gated; old clients ignore/flatten them safely. Revert must not rewrite existing messages or participant membership.
