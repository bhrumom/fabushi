# M2-NET-001 — Self-hosted WebSocket gateway + heartbeat

- Project: `FABUSHI-TELEGRAM-FUSION`
- Execution task: `M2-NET-001`
- WBS coverage: `M2.T01 gateway`, `M2.T03 websocket connection`, `M2.T04 heartbeat`
- Stage: `M2 自建实时网络 + 1:1 文本消息`
- Status: `TESTED`
- Started: `2026-08-22`
- Updated: `2026-08-22`
- Depends on: M1.T02 production SQLite landing

## Objective

Add a Fabushi-owned WebSocket transport in front of the canonical Messaging Protocol v2 without creating a second messaging state machine. The gateway reuses account/device/session-scoped access tokens, enforces frame limits, supports RFC 6455 ping/pong heartbeat, and preserves the existing server-side MessagingService/SQLite state.

## Implemented

- `tungstenite 0.30` synchronous RFC 6455 server transport;
- `MessagingWebSocketGatewayConfig` with heartbeat interval/timeout validation;
- production `serve`, injectable listener `serve_listener`, deterministic one-client `serve_one` for real socket tests;
- shared authenticated command executor used by both TCP and WebSocket transports;
- exact reuse of `MessagingService<SqliteStateStore>` and Messaging Protocol v2 envelopes;
- scoped access-token authorization for actor/device/session and command scope;
- bounded WebSocket message/frame configuration plus exact application payload limit;
- text JSON application protocol; binary application frames explicitly rejected;
- Ping/Pong liveness and heartbeat timeout;
- clean close handling;
- real localhost integration tests for authorized Sync, session mismatch, server heartbeat, oversized text frame, binary frame rejection.

## Acceptance result

1. Real WebSocket client handshake + Protocol v2 command execution: PASS.
2. Actor/device/session mismatch rejection: PASS.
3. Ping/Pong liveness with connection still usable afterward: PASS.
4. Oversized application frame rejection: PASS.
5. Same canonical messaging service/state, no second chat engine: PASS.
6. Rust fmt/test/clippy, Feature Host/contact projection and Electron Messenger contract regression: PASS.

## CI evidence

- PR: #1993 `feat(messaging): add self-hosted WebSocket gateway`
- Verified implementation head: `c31943c34b0fbf1b1378f39855cb6e2150d2a33e`
- Messaging Product Gate `32560118577`: SUCCESS.
- Mahayana fast checks `32560118567`: SUCCESS.
- Explicit automerge `32560118574`: SUCCESS.

## Branch / PR

- Branch: `feat/telegram-m2-websocket-gateway`
- Current base: `feat/telegram-m1-sqlite-default` until #1990 lands.
- PR: #1993

## Evidence

- `../../evidence/M2-NET-001/README.md`
- `native/mahayana-messaging/src/gateway.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/tests/websocket_gateway_contract.rs`

## Remaining landing gate

Implementation is `TESTED` on the stacked branch. After #1990 enters canonical `main`, retarget #1993 directly to `main`, re-run required gates, then use protected merge queue and verify canonical main.

## Next action

Maintain dependency order: #1990 -> main, then #1993 -> main. Continue M2-SYNC-001 on top for reconnect/idempotency/server-sequence/delta-sync semantics.
