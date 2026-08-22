# M2-SYNC-001 clean-stack evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M2-SYNC-001`
- **Status**: `IN_PROGRESS / FINAL-HEAD CI PENDING`
- **PR**: #2002
- **Branch**: `feat/telegram-m2-delta-main-sync`

## Runtime provenance

Historical #1994 supplied the original durable-sync implementation, but stale historical project-document snapshots are not imported. The final current-main landing keeps the canonical current `Message` schema and reuses the intended durable store/service/test behavior.

## Current-main compatibility reconciliation

Final current-head CI on the historical replay exposed two real compatibility deltas:

1. Rust stable/rustfmt advanced to 1.98; the three M2-SYNC Rust files were reformatted with current stable rustfmt.
2. Current canonical `Message` no longer has a `client_message_id` field. Idempotent replay already derives a deterministic `stable_message_id(actor_id, client_message_id)` (with legacy local-key lookup), so the obsolete field comparison was removed without extending or reverting `Message` schema. Sender/content/reply/thread/schedule/silent/protected-content conflict checks remain.

## Final clean landing

- M2-NET prerequisite: PR #2001 merged through the protected queue as `2a4124a7b4b769be1320f88621e4eb3ad7f1a3f6`.
- Final base: canonical `main` at `2a4124a7b4b769be1320f88621e4eb3ad7f1a3f6`.
- Clean runtime commit: `5602f96bcb806b2c09981241ab88d99c15f07fc9`.
- Compare immediately after rebuild: ahead by 1, behind by 0, exactly six changed files.
- Final runtime blobs include corrected `service.rs` blob `d05ec7160997ff449bbfcf5aa4151ce7938d8a03`, formatted `store.rs` blob `2ffb60eab5986e92e6a296a9c8c90e05ba37fb8a`, and formatted `delta_sync_contract.rs` blob `3e31d0a0e3f566b0b7606d12ece863ed535048b9`.
- Temporary workflow experiments are absent from the final current-main commit history.

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

M2-SYNC-001 is not complete merely because historical code was replayed. The final #2002 head must pass fresh current GitHub Actions on canonical `main`, merge through protected-main governance, and be re-read from canonical `main` before M2.T05-T09 or the M2 stage can be closed.
