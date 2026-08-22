# M2-NET-001 clean-stack evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M2-NET-001`
- **Status**: `IN_PROGRESS / FINAL-HEAD CI PENDING`
- **PR**: #2001
- **Branch**: `feat/telegram-m2-websocket-main-sync`

## Runtime evidence

- `native/mahayana-messaging/src/gateway.rs`: self-hosted WebSocket gateway, frame bounds, Ping/Pong heartbeat, timeout, Protocol v2 UTF-8 JSON application frames.
- `native/mahayana-messaging/src/server.rs`: TCP/WebSocket share one `MessagingService<SqliteStateStore>` loader and one authenticated executor.
- `native/mahayana-messaging/tests/websocket_gateway_contract.rs`: real localhost handshake/protocol execution, identity mismatch rejection, heartbeat, frame-size and binary rejection.
- `native/mahayana-messaging/Cargo.toml`: `tungstenite 0.30`.
- `native/mahayana-messaging/src/lib.rs`: gateway exported by the canonical messaging crate.

## Clean rebase evidence

- Canonical rebase base: `c9bfa320ac4e3e27cc2dee3e80bbd558c08f4cb5` (`main` at rebase time).
- Clean M2-NET runtime/project replay commit: `c1ddb97a16df5eccab7310ba1fb3fe17b161a003`.
- Compare immediately after rebuild: branch ahead by exactly one commit and behind by zero; diff contained only the intended M2-NET runtime/test/task/evidence/WBS files.
- Additional commits on the same branch only reconcile current FAB-P0001 project acceptance/governance records and therefore require a fresh final-head CI round before closure.

## Historical verified evidence

Equivalent implementation on historical PR #1993:

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | `32560118577` | SUCCESS |
| Mahayana fast checks | `32560118567` | SUCCESS |
| Explicit automerge | `32560118574` | SUCCESS |

Historical evidence is provenance only; it does not satisfy the final clean-head gate.

## Completion rule

Do not close M2-NET-001 until the final #2001 head passes required GitHub Actions, merges to `main`, and canonical `main` is re-read to verify the gateway/shared executor/test files are present without project-state regression.
