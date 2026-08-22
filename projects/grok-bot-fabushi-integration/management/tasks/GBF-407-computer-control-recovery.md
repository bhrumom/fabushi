# GBF-407 — Computer-control crash/reconnect

- Project: `FAB-P0004`
- Stage: `M4-computer-control`
- Status: `IN_PROGRESS`
- Dependencies: `GBF-402..406`

## Objective

Make computer-control recovery deterministic across Host/renderer/remote-session reconnects without replaying already-consumed capabilities or duplicating native side effects.

## Acceptance

- Revoked/expired/consumed grants remain unusable after reconnect.
- Pending operations fail or resume according to explicit idempotency semantics.
- Remote session expiry/reconnect cannot duplicate an action.
- Fault-injection tests cover Host crash, transport drop and duplicate command delivery.

## Evidence

Target: `evidence/GBF-407/` plus CI links and merged commit.
