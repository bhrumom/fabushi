# M2-SYNC-001 clean-stack evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M2-SYNC-001`
- **Status**: `IN_PROGRESS / FINAL-HEAD CI PENDING`
- **PR**: #2002
- **Branch**: `feat/telegram-m2-delta-main-sync`

## Runtime provenance

Historical #1994 runtime blobs are replayed exactly; historical project-document snapshots are not imported:

- `native/mahayana-messaging/src/service.rs` → `24037aa3892ad61c17f95441185e612b02a2ee43`
- `native/mahayana-messaging/src/store.rs` → `1e46a1c52931ed58da10b803c9d0cf8231e17618`
- `native/mahayana-messaging/tests/delta_sync_contract.rs` → `6a437b8ce7c4d2266b152fff26639774e670d632`

## Final clean-stack restack

- Lower-stack parent: #2001 head `1030a489a5b4ed12f93464c95325e5d6d2ca7535`.
- Clean runtime replay commit: `fd76ebd828f62b82ff0eecf34e85b24860e2a342`.
- Subsequent #2002 commits only refresh current FAB-P0001 task/evidence records before final CI.
- PR compare against #2001 remains intended M2-SYNC runtime/test/task/evidence/WBS scope.

## Behavior covered

- SQLite schema v2 event journal and migration from v1.
- Transactional snapshot + journal persistence.
- Restart/reconnect recovery and journal-floor fallback.
- Idempotent send/ACK and conflicting client-message-ID rejection.
- Durable server cursor/checkpoint semantics.
- Audience-scoped delta replay and outsider isolation.
- Second-device synchronization.
- `Sent -> Delivered -> Read` transitions.
- Cursor-group-aware journal pagination and pruning.

## Completion rule

M2-SYNC-001 is not complete merely because historical code was replayed. The final #2002 head must pass current GitHub Actions, #2001 must land, #2002 must be retargeted/revalidated on `main`, then merged and verified on canonical `main`.
