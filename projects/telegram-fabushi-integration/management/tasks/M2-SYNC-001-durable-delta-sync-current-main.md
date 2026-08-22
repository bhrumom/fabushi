# M2-SYNC-001 — Durable idempotent delta sync on canonical main

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-SYNC-001`
- **WBS**: `M2.T05`–`M2.T09`
- **Status**: `TESTED`
- **Completed**: `2026-08-22`
- **Depends on**: M2-NET-001 — resolved

## Result

The canonical Rust messaging engine now provides durable reconnect recovery, idempotent send/ACK, durable server cursor, audience-scoped delta sync and Sent/Delivered/Read transitions.

## Verified implementation

- SQLite schema v2 durable event journal.
- transactional snapshot + audience-scoped journal entries.
- complete cursor-group pagination/pruning.
- deterministic stable message IDs from authenticated sender + client message id.
- identical retry is idempotent; conflicting payload reuse is rejected.
- successful send reaches `Sent`; recipient sync reaches `Delivered`; recipient `MarkRead` reaches `Read`.
- cursor delta replay with checkpoint; old/incomplete history safely falls back to scoped full sync.
- outsider isolation, process restart, second-device and migration-floor contracts.

## Current-main compatibility reconciliation

Historical #1994 referenced a removed `Message.client_message_id`. The final clean implementation preserves the current canonical Message schema because deterministic stable-message lookup already binds actor + client message id. The obsolete field comparison was removed while all payload-conflict checks remain. Current rustfmt, all-target Rust tests and Clippy proved the reconciled implementation.

## Final GitHub evidence

PR #2002 final head `b4d56161a4b409e04e9a0a0850900ac9cf3fae08` passed:

- Messaging Product Gate `32575120937` — SUCCESS.
- Mahayana fast checks `32575120857` — SUCCESS.
- Fabushi self-hosted messaging `32575120877` — SUCCESS.
- Repository CI `32575120874` — SUCCESS.
- Project portfolio governance `32575120961` — SUCCESS.
- Explicit automerge `32575120853` — SUCCESS.

PR #2002 merged as `d4611f9433eb4d6cbfa934c574cec1da96210edb`. Canonical-main re-read confirmed the corrected deterministic-idempotency code and all durable-sync artifacts.

## Evidence

- `../../evidence/M2-SYNC-001-current-main/README.md`
- `../../evidence/M2-ACCEPT-001/README.md`

## Next action

No M2-SYNC blocker remains. M3 consumes these realtime semantics in the desktop interaction layer.
