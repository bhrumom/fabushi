# M2-SYNC-001 — Durable idempotent delta sync on clean stack

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-SYNC-001`
- **WBS**: `M2.T05`–`M2.T09`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Depends on**: M2-NET-001 / PR #2001

## Objective

Complete M2 realtime semantics on the canonical Rust messaging engine: durable reconnect recovery, idempotent send/ACK, durable server cursor, audience-scoped delta sync, and Sent/Delivered/Read state transitions.

## Runtime implementation

- SQLite schema v2 durable event journal.
- Snapshot + audience-scoped journal entries persist transactionally.
- Cursor-group-aware pagination/pruning.
- Stable server message IDs derived from authenticated sender + `client_message_id`.
- Identical retries return the accepted message without duplicating state or advancing cursor again.
- Conflicting reuse of a client message ID is rejected.
- Successful send enters ACK path and reaches `Sent`.
- Direct/secret recipient sync promotes `Sent -> Delivered`.
- Recipient `MarkRead` promotes visible messages to `Read`.
- `Sync.cursor` replays authorized delta events and emits checkpoint cursor.
- Old/incomplete journal history falls back to actor-scoped full sync.
- Journal audiences are captured at mutation time and filtered on replay.

## Clean stack provenance

Historical PR #1994 is implementation provenance only. The clean PR #2002 replays only the intended runtime blobs plus current task/evidence/WBS on top of the clean #2001 stack.

After the final #2001 governance reconciliation, #2002 was restacked again with parent `1030a489a5b4ed12f93464c95325e5d6d2ca7535` and clean runtime replay commit `fd76ebd828f62b82ff0eecf34e85b24860e2a342`. This prevents stale lower-stack project records from entering the M2-SYNC diff.

## Acceptance criteria

1. Process restart preserves state and delta journal sufficiently for reconnect recovery.
2. Repeated identical `client_message_id` is idempotent; conflicting reuse is rejected.
3. Server cursor never silently rolls backward across persisted state.
4. Authorized second-device delta sync recovers changes after known cursor.
5. Outsiders cannot observe journal events for unauthorized conversations.
6. Missing/expired journal coverage falls back to actor-scoped full sync.
7. Delivery/read transitions reach `Sent`, `Delivered`, `Read` in defined recipient flows.
8. Final clean-head Messaging Product Gate, Mahayana fast checks and applicable repository/governance checks pass.
9. #2001 lands first; #2002 is retargeted to final `main`, revalidated, merged and verified on canonical `main`.

## Branch / PR

- Branch: `feat/telegram-m2-delta-main-sync`
- PR: #2002
- Temporary base: `feat/telegram-m2-websocket-main-sync` / #2001
- Historical PR: #1994 — provenance only; to be closed as superseded after clean landing.

## Evidence

- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/service.rs`
- `native/mahayana-messaging/tests/delta_sync_contract.rs`
- `../../evidence/M2-SYNC-001-current-main/README.md`

## Next action

Run final clean-stack CI. After #2001 lands, retarget #2002 to `main`, revalidate the final head/base pair, merge through protected-main governance, then perform canonical-main verification and close M2.T05-T09.
