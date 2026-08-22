# M1.T02 — Production local-first storage

- Project: `FABUSHI-TELEGRAM-FUSION`
- Task ID: `M1.T02`
- Stage: `M1 Rust Core 骨架`
- Status: `TESTED`
- Started: `2026-08-22`
- Updated: `2026-08-22`
- Depends on: `M1.T06`

## Objective

Switch the canonical `native/mahayana-messaging` production server from JSON snapshot persistence to SQLite, while preserving a safe one-time import path for existing JSON snapshots.

## Implemented

- `MessagingTcpServer` now uses `SqliteStateStore` as its production state store.
- New `FABUSHI_MESSAGING_DATABASE`; default database is `fabushi-messaging.sqlite3`.
- Legacy `FABUSHI_MESSAGING_SNAPSHOT` is treated as an import source, not the ongoing production store.
- If no explicit DB path is supplied but a legacy snapshot path is supplied, the DB path is derived as the sibling `.sqlite3` file.
- `SqliteStateStore::import_json_if_empty` imports the validated JSON snapshot only while SQLite has no state.
- Existing SQLite state always wins over stale JSON on later starts.
- The compatibility `snapshot_path()` accessor remains, but now aliases the production database path.
- Tests cover one-time import and stale legacy data not overwriting existing SQLite state.

## Acceptance result

1. New installs default to SQLite: PASS.
2. Existing JSON snapshot can be imported once without changing persisted snapshot semantics: PASS.
3. Existing SQLite state wins over stale JSON: PASS.
4. Rust fmt/test/clippy and Feature Host/desktop contract gates: PASS.
5. Project evidence is attached; WBS final landed status will be updated after dependency merge and retarget: IN PROGRESS.

## CI evidence

- PR: #1990 `feat(messaging): make SQLite production storage default`
- Verified code head: `031f49d015f5d51900e6003a8f2c46c839a64d7c`
- Messaging Product Gate run `32559372311`: SUCCESS.
- Mahayana fast checks run `32559372278`: SUCCESS.
- Explicit automerge run `32559372304`: SUCCESS.

## Branch / PR

- Branch: `feat/telegram-m1-sqlite-default`
- Current base: `feat/telegram-m1-sqlite-storage` until #1988 lands.
- PR: #1990

## Evidence

- `../../evidence/M1-T02/README.md`
- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/src/bin/messaging-server.rs`
- GitHub Actions runs above.

## Remaining landing gate

The implementation is `TESTED`, but it must not merge before M1.T06. After #1988 enters `main`, retarget #1990 directly to `main`, re-run the required checks against that base, then use the protected merge queue and verify canonical `main`.

## Next action

Wait only for the dependency landing order: #1988 -> main, then retarget #1990 -> main and re-verify current-head checks before merge queue.
