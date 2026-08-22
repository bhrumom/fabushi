# M2-NET-001 — Self-hosted WebSocket gateway on canonical main

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-NET-001`
- **WBS**: `M2.T01`–`M2.T04`
- **Status**: `TESTED`
- **Completed**: `2026-08-22`

## Result

Canonical Rust `MessagingService<SqliteStateStore>` is exposed through a self-hosted WebSocket transport without introducing a second messaging engine, protocol, authorization model or state store.

## Verified implementation

- `tungstenite 0.30` WebSocket transport.
- Protocol v2 UTF-8 JSON frames.
- scoped actor/device/session access-token authorization.
- TCP/WebSocket share one authenticated executor and one messaging service loader.
- bounded frames and explicit binary-frame rejection.
- server Ping/Pong heartbeat and inactivity timeout.
- real localhost handshake/auth/heartbeat/frame contracts.

## Landing evidence

- Clean PR #2001.
- Final head `1030a489a5b4ed12f93464c95325e5d6d2ca7535` passed all required current-head GitHub Actions.
- Protected merge queue landed PR #2001 as `2a4124a7b4b769be1320f88621e4eb3ad7f1a3f6`.
- Post-merge canonical-main reads confirmed `gateway.rs` and `websocket_gateway_contract.rs` are present.
- Historical PR #1993 is closed as superseded landing provenance.

## Evidence

- `../../evidence/M2-NET-001-current-main/README.md`
- `../../evidence/M2-ACCEPT-001/README.md`

## Next action

No M2-NET blocker remains. Desktop interaction completeness proceeds in M3.
