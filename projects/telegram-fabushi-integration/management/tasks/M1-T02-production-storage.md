# M1.T02 — Production local-first storage

- Project: `FABUSHI-TELEGRAM-FUSION`
- Task ID: `M1.T02`
- Stage: `M1 Rust Core 骨架`
- Status: `IN_PROGRESS`
- Started: `2026-08-22`
- Updated: `2026-08-22`
- Depends on: `M1.T06`

## Objective

Switch the canonical `native/mahayana-messaging` production server from JSON snapshot persistence to SQLite, while preserving a safe one-time import path for existing JSON snapshots.

## Scope

Use `SqliteStateStore` in `MessagingTcpServer`; default to `fabushi-messaging.sqlite3`; support `FABUSHI_MESSAGING_DATABASE`; treat legacy `FABUSHI_MESSAGING_SNAPSHOT` as an import source; import only when SQLite is empty; never overwrite existing SQLite state from legacy JSON; add Rust tests; verify through GitHub Actions.

## Acceptance criteria

1. New installs default to SQLite.
2. Existing JSON snapshot can be imported once without changing state/cursor/timestamp.
3. Existing SQLite state wins over stale JSON on later starts.
4. Rust fmt/test/clippy and Host bridge gates pass in GitHub Actions.
5. WBS/status/acceptance/evidence are updated before completion.

## Branch / PR

- Branch: `feat/telegram-m1-sqlite-default`
- Base: `feat/telegram-m1-sqlite-storage` until M1.T06 merges.
- PR: pending

## Evidence

Pending implementation and CI.

## Next action

Implement production SQLite selection and one-time legacy JSON import.
