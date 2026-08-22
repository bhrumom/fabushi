# M2-NET-001 — Self-hosted WebSocket gateway + heartbeat

- Project: `FABUSHI-TELEGRAM-FUSION`
- Execution task: `M2-NET-001`
- WBS coverage: `M2.T01 gateway`, `M2.T03 websocket connection`, `M2.T04 heartbeat`
- Stage: `M2 自建实时网络 + 1:1 文本消息`
- Status: `IN_PROGRESS`
- Started: `2026-08-22`
- Updated: `2026-08-22`
- Depends on: M1.T06 / M1.T02

## Objective

Add a Fabushi-owned WebSocket transport in front of the canonical Messaging Protocol v2 without creating a second messaging state machine. The gateway must reuse account/device/session-scoped access tokens, enforce frame limits, support RFC 6455 ping/pong heartbeat, and preserve the existing server-side MessagingService/SQLite state.

## Scope

- synchronous Rust WebSocket gateway using the canonical `ClientEnvelope` / `ServerEnvelope` JSON schema;
- same `AuthenticatedClientFrame` and scope authorization used by the existing self-hosted server;
- bounded WebSocket message size;
- Ping/Pong heartbeat and clean close handling;
- text JSON frames; binary application frames explicitly rejected rather than silently interpreted;
- listener API that supports production bind and deterministic localhost integration tests;
- tests for authorized message flow, unauthorized access, heartbeat, and frame-size protection;
- no Telegram API/MTProto network dependency.

## Acceptance criteria

1. A WebSocket client can connect to a Fabushi-owned listener and execute Messaging Protocol v2 commands.
2. Actor/device/session token mismatch is rejected.
3. Ping receives/queues a valid Pong and the connection remains usable.
4. Oversized application messages are rejected under the configured gateway limit.
5. The gateway uses the same `MessagingService<SqliteStateStore>` state as the production messaging server; no duplicate chat engine exists.
6. Rust fmt/test/clippy and existing Host/desktop contracts remain green.

## Branch / PR

- Branch: `feat/telegram-m2-websocket-gateway`
- Base: `feat/telegram-m1-sqlite-default` while M1 lands in dependency order.
- PR: pending

## Evidence

Pending implementation and GitHub Actions.

## Next action

Implement the WebSocket transport, add integration tests, then run the Messaging Product Gate and Mahayana fast checks.
