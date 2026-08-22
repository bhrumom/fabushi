# M1.T02 current-main landing evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M1.T02`
- **Status**: `IMPLEMENTED / CURRENT-HEAD CI PENDING`
- **Branch**: `feat/telegram-m1-sqlite-main-sync`

## Why this landing exists

PR #1990 contains the intended production-SQLite implementation and previously passed its product gates, but it also contains older project-document snapshots that predate the repository-wide immutable `FAB-Pxxxx` governance. The current landing starts from canonical `main` and carries only the runtime delta plus fresh project evidence so it cannot regress `FAB-P0001 / TFI` metadata or newer governance records.

## Runtime evidence in branch

- `native/mahayana-messaging/src/store.rs`
  - `SqliteStateStore::import_json_if_empty`
  - validates legacy snapshot through the existing store contract
  - imports only when SQLite is empty
  - preserves SQLite authority after first import
  - unit test proves stale JSON cannot overwrite existing SQLite state
- `native/mahayana-messaging/src/server.rs`
  - production `MessagingTcpServer` uses `SqliteStateStore`
  - optional legacy JSON import source
  - explicit database-path validation
  - blob root remains adjacent to authoritative production state
- `native/mahayana-messaging/src/bin/messaging-server.rs`
  - `FABUSHI_MESSAGING_DATABASE`
  - default `fabushi-messaging.sqlite3`
  - compatibility import from `FABUSHI_MESSAGING_SNAPSHOT`

## Historical verified evidence

The same intended implementation path in PR #1990 passed:

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | 32559833779 | SUCCESS |
| Mahayana fast checks | 32559833770 | SUCCESS |
| Explicit automerge | 32559833763 | SUCCESS |

These runs are historical implementation evidence only. Completion still requires green current-head checks on this clean branch, protected merge, and canonical-main verification.

## Current-head evidence

Pending replacement PR creation and GitHub Actions runs.

## Completion gate

Do not mark M1.T02 landed/closed until current-head CI is green, protected-main merge completes, and canonical `main` is re-read to verify SQLite is the production default without project-governance regression.
