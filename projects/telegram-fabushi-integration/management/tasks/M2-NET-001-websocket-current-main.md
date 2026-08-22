# M2-NET-001 — Self-hosted WebSocket gateway on clean stack

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-NET-001`
- **WBS**: `M2.T01`, `M2.T02`, `M2.T03`, `M2.T04`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Depends on**: M1 tested foundation — resolved

## Objective

Expose the canonical Rust `MessagingService<SqliteStateStore>` over a self-hosted WebSocket transport without creating a second messaging engine, protocol, authorization model, or state store.

## Implementation

- `tungstenite 0.30` self-hosted WebSocket transport.
- Messaging Protocol v2 text/JSON envelopes.
- Existing scoped `FileAccessTokenStore` actor/device/session authorization.
- TCP and WebSocket share one authenticated command executor and one `MessagingService<SqliteStateStore>` loader.
- Bounded application/message frames and explicit binary-frame rejection.
- Server Ping/Pong heartbeat with inactivity timeout.
- Deterministic `serve_one` entrypoint for real localhost socket contracts.

## Clean-current-main landing

Historical PR #1993 contained the intended implementation and passed its product gates, but it was stacked on older project history. Clean PR #2001 was created instead.

After #1998 landed, unrelated Fabushi projects advanced `main`; therefore #2001 was rebuilt again from canonical `main` commit `c9bfa320ac4e3e27cc2dee3e80bbd558c08f4cb5`. Runtime/project delta was replayed into one clean code commit `c1ddb97a16df5eccab7310ba1fb3fe17b161a003`, after which project governance/acceptance records were reconciled on the same branch.

The clean compare at that point was `main` + one M2-NET delta with only the intended gateway/server/test/project files; no historical M1 commit stack remained.

## Acceptance criteria

1. Valid actor/device/session token executes Protocol v2 over a real WebSocket — implementation present; current-head CI required.
2. Identity mismatch is rejected — contract test present; current-head CI required.
3. Ping/Pong keeps healthy connection alive and invalid heartbeat configuration is rejected — contract/unit tests present.
4. Oversized application frames are rejected — contract test present.
5. Binary application frames are rejected — contract test present.
6. TCP/WebSocket share one messaging service and authorization executor — implementation present.
7. Messaging Product Gate, Mahayana fast checks, repository/self-hosted/governance checks pass on the final clean head — **PENDING final-head results**.
8. Protected merge and canonical-main verification complete — **PENDING**.

## Branch / PR

- Branch: `feat/telegram-m2-websocket-main-sync`
- PR: #2001
- Base: `main`
- Historical PR: #1993 — provenance only; to be closed as superseded after #2001 lands.

## Evidence

- `native/mahayana-messaging/src/gateway.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/tests/websocket_gateway_contract.rs`
- `../../evidence/M2-NET-001-current-main/README.md`

## Next action

Use the final branch head after governance reconciliation, require fresh current-head GitHub Actions, merge #2001, re-read canonical `main`, then update this record to `TESTED` and retarget #2002.
