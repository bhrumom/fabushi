# M2-SYNC-001 — Durable sequence, idempotent send/ACK, and delta sync

- Project: `FABUSHI-TELEGRAM-FUSION`
- Execution task: `M2-SYNC-001`
- WBS coverage: `M2.T05 reconnect`, `M2.T06 message send/ack`, `M2.T07 server sequence`, `M2.T08 delta sync`, `M2.T09 delivery/read state`
- Stage: `M2 自建实时网络 + 1:1 文本消息`
- Status: `IN_PROGRESS`
- Started: `2026-08-22`
- Updated: `2026-08-22`
- Depends on: `M2-NET-001`, M1 production SQLite

## Objective

Turn the existing snapshot-based recovery into a real durable incremental-sync protocol. A repeated send using the same `client_message_id` must be idempotent, accepted messages must receive a server ACK/sequence, and reconnecting devices must consume only authorized events after their cursor when durable history is available, with a safe full-sync fallback when it is not.

## Security boundary

The durable journal must never become a global unfiltered event feed. Delta events must be filtered using the same actor/conversation visibility rules as full sync. If completeness or visibility cannot be proven for a requested cursor, the server falls back to the existing scoped full `SyncBatch`.

## Scope

- durable SQLite event journal with schema migration from existing SQLite v1;
- monotonically increasing server cursor persisted with state and journal writes;
- idempotent `SendMessage` keyed by deterministic local/server message identity derived from `client_message_id`;
- automatic server ACK moves accepted message from Pending to Sent without client-side duplicate creation;
- `Sync.cursor` honored: delta when journal coverage is sufficient, empty delta when already current, scoped full-sync fallback when history is incomplete;
- conversation/actor visibility filtering for journal replay;
- reconnect and second-device contract tests;
- read-state propagation verification for the 1:1 acceptance path;
- current Messaging Product Gate and Mahayana fast checks.

## Acceptance criteria

1. Retrying the same `client_message_id` does not create a second message and does not fail as a duplicate request.
2. A successful send produces a stable accepted message identity and `Sent` state.
3. Server cursor is monotonic across restart because snapshot and event journal are persisted transactionally.
4. A client reconnecting with a covered cursor receives only later visible events.
5. A client with a cursor older than retained/known journal coverage receives a scoped full sync instead of incomplete deltas.
6. A second device for the same actor can resume from its own cursor and observe the same conversation state.
7. An actor outside a conversation cannot receive its delta events.
8. Mark-read remains scoped to authorized participants and is observable after sync.
9. Rust fmt/test/clippy plus Host/desktop contracts remain green.

## Branch / PR

- Branch: `feat/telegram-m2-durable-delta-sync`
- Base: `feat/telegram-m2-websocket-gateway` while dependency PRs land in order.
- PR: pending

## Evidence

Pending implementation and GitHub Actions.

## Next action

Implement a bounded, visibility-aware SQLite journal and idempotent server ACK path, then add reconnect/multi-device integration tests.
