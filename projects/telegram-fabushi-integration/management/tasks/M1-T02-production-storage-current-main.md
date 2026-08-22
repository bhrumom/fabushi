# M1.T02 — Production local-first storage on current main

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M1.T02`
- **Stage**: `M1 Rust Core 骨架`
- **Status**: `TESTED`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Completed**: `2026-08-22`
- **Source**: `../../source/完整telegram融合进fabushi.txt`; `../wbs/M1.md`
- **Depends on**: `M1.T06` — resolved by PR #1988

## Objective

Make SQLite the authoritative production store for the canonical `native/mahayana-messaging` server while preserving a safe one-time import path for historical JSON snapshots.

## Implemented result

- `MessagingTcpServer` uses `SqliteStateStore` for authoritative durable product state.
- `FABUSHI_MESSAGING_DATABASE` selects the production SQLite database; default `fabushi-messaging.sqlite3`.
- `FABUSHI_MESSAGING_SNAPSHOT` remains a legacy import source only.
- `SqliteStateStore::import_json_if_empty` imports legacy state only when SQLite has no snapshot.
- Existing SQLite state always wins over stale JSON on later starts.
- `snapshot_path()` remains a compatibility accessor resolving to the authoritative database path.
- Config validation rejects empty database/access-registry paths.

## Acceptance result

1. New production starts default to SQLite — **PASS**.
2. Existing JSON state imports exactly once into empty SQLite — **PASS**.
3. Existing SQLite state cannot be overwritten by stale JSON — **PASS**.
4. Invalid database/access-registry paths are rejected — **PASS**.
5. Rust formatting, all-target messaging tests, Clippy and bridge contracts pass — **PASS**.
6. Repository/project governance checks pass — **PASS**.
7. Change is merged and verified on canonical `main` — **PASS**.

## Current-head verification

Clean replacement PR #1998 passed:

- Messaging Product Gate `32563424543` — SUCCESS.
- Mahayana fast checks `32563424539` — SUCCESS.
- Repository CI `32563424556` — SUCCESS.
- Project portfolio governance `32563424574` — SUCCESS.
- Fabushi self-hosted messaging `32563424511` — SUCCESS.
- Product Gate jobs `97008408512` and `97008408644` — SUCCESS.

PR #1998 merged as `6ad86ccc809a6f00130888087f22cbb201e853fd`. A post-merge GitHub read confirmed canonical `main` production `MessagingTcpServer` uses `SqliteStateStore` and performs legacy import only while the database is empty.

## Historical provenance

PR #1990 remains historical implementation/CI provenance and is closed as superseded for landing. Its stale project-document snapshot was intentionally not merged.

## Evidence

- `../../evidence/M1-T02-current-main/README.md`
- `../../evidence/M1-ACCEPT-001/README.md`
- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/src/bin/messaging-server.rs`

## Next action

No M1.T02 blocker remains. M2-SYNC-001 may migrate the same authoritative SQLite store to schema v2 durable event journaling through its own acceptance gate.
