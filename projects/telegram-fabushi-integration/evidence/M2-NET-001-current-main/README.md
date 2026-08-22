# M2-NET-001 clean-stack evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M2-NET-001`
- **Status**: `IMPLEMENTED / CURRENT-HEAD CI PENDING`
- **Branch**: `feat/telegram-m2-websocket-main-sync`

## Runtime evidence

- `gateway.rs`: self-hosted WebSocket gateway, frame bounds, Ping/Pong heartbeat, timeout, text-only Protocol v2 application frames.
- `server.rs`: shared `MessagingService<SqliteStateStore>` loader and shared authenticated executor for TCP and WebSocket.
- `websocket_gateway_contract.rs`: real localhost WebSocket handshake and protocol execution; identity mismatch rejection; heartbeat; frame-size and binary-frame rejection.
- `Cargo.toml`: `tungstenite 0.30`.
- `lib.rs`: gateway is part of the canonical messaging crate API.

## Historical verified evidence

Equivalent implementation on historical PR #1993:

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | 32560118577 | SUCCESS |
| Mahayana fast checks | 32560118567 | SUCCESS |
| Explicit automerge | 32560118574 | SUCCESS |

Verified historical implementation head: `c31943c34b0fbf1b1378f39855cb6e2150d2a33e`.

## Current clean-stack evidence

Pending clean PR current-head GitHub Actions, protected merge, and canonical-main verification.

## Completion rule

Do not close M2-NET-001 from historical CI alone. The clean stack must pass current CI after M1.T02 is landed/retargeted and must be verified on canonical `main`.
