# M2-NET-001 — Self-hosted WebSocket gateway on clean stack

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-NET-001`
- **WBS**: `M2.T01`, `M2.T03`, `M2.T04` (and reuses existing `M2.T02` auth/session foundation)
- **Status**: `IMPLEMENTED`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Depends on**: `M1.T02` current-main SQLite landing

## Objective

Expose the canonical Rust `MessagingService<SqliteStateStore>` over a self-hosted WebSocket transport without creating a second messaging engine, protocol, authorization model, or state store.

## Implementation

- Adds `tungstenite 0.30` WebSocket transport.
- Reuses Messaging Protocol v2 text/JSON envelopes.
- Reuses scoped `FileAccessTokenStore` actor/device/session authorization.
- TCP and WebSocket share the same authenticated command executor.
- Bounded application/message frame size.
- Explicit binary application-frame rejection.
- Server heartbeat Ping/Pong with inactivity timeout.
- Deterministic `serve_one` entrypoint for real localhost socket contract tests.
- Production durable state remains the M1 SQLite store.

## Acceptance criteria

1. A valid account/device/session token can execute Protocol v2 over a real WebSocket connection.
2. Actor/device/session mismatch is rejected as unauthorized.
3. Ping/Pong heartbeat keeps a live connection healthy and timeout logic is configured defensively.
4. Oversized application frames are rejected.
5. Binary application frames are rejected because Protocol v2 is UTF-8 JSON.
6. TCP and WebSocket use the same messaging service and authorization executor.
7. Messaging Product Gate and Mahayana fast checks pass on the clean current stack.
8. Protected merge and canonical-main verification complete.

## Historical evidence

The earlier implementation PR #1993 passed:
- Messaging Product Gate `32560118577`: SUCCESS
- Mahayana fast checks `32560118567`: SUCCESS
- Explicit automerge `32560118574`: SUCCESS
- verified implementation head: `c31943c34b0fbf1b1378f39855cb6e2150d2a33e`

Historical evidence does not replace current clean-stack CI.

## Branch / PR

- Branch: `feat/telegram-m2-websocket-main-sync`
- Base while stacked: `feat/telegram-m1-sqlite-main-sync`
- Clean replacement PR: pending creation.
- Historical PR #1993 will be superseded for landing after the clean PR is accepted.

## Evidence

- `native/mahayana-messaging/src/gateway.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/tests/websocket_gateway_contract.rs`
- `../../evidence/M2-NET-001-current-main/README.md`

## Next action

Open clean stacked PR, run current-head CI, then retarget to `main` after M1.T02 lands and merge through protected-main governance.
