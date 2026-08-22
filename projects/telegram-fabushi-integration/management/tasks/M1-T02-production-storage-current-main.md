# M1.T02 — Production local-first storage on current main

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M1.T02`
- **Stage**: `M1 Rust Core 骨架`
- **Status**: `IMPLEMENTED`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Source**: `../../source/完整telegram融合进fabushi.txt`; `../wbs/M1.md`
- **Depends on**: `M1.T06` (PR #1988, landed on canonical `main`)

## Objective

Make SQLite the authoritative production store for the canonical `native/mahayana-messaging` server while preserving a safe one-time import path for historical JSON snapshots.

## Current-main reconciliation

The original implementation PR #1990 had successful product CI on its implementation head, but its branch also carried project-document snapshots created before the repository-wide immutable `FAB-Pxxxx` portfolio-ID governance landed. Because those stale documents must not overwrite the canonical `FAB-P0001 / TFI` project state, this task is re-landed from the latest `main` on `feat/telegram-m1-sqlite-main-sync` with only the intended runtime changes plus current project evidence.

## Implemented

- `MessagingTcpServer` uses `SqliteStateStore` for authoritative durable product state.
- `FABUSHI_MESSAGING_DATABASE` selects the production SQLite database; default is `fabushi-messaging.sqlite3`.
- `FABUSHI_MESSAGING_SNAPSHOT` is a legacy import source, not the continuing production store.
- If only a legacy snapshot path is supplied, the SQLite path is derived as the sibling `.sqlite3` file.
- `SqliteStateStore::import_json_if_empty` imports only when SQLite has no state.
- Existing SQLite state always wins over stale JSON on later starts.
- `snapshot_path()` remains a compatibility accessor but resolves to the production database path.
- Unit coverage includes one-time import and protection against stale legacy overwrite.

## Acceptance criteria

1. New production starts default to SQLite.
2. Existing valid JSON state can be imported exactly once into an empty SQLite database.
3. Existing SQLite state cannot be overwritten by stale legacy JSON.
4. Database/access-registry configuration rejects invalid empty paths.
5. Rust formatting, all-target messaging tests, Clippy and product bridge contracts pass in GitHub Actions.
6. Required repository/project-governance checks pass.
7. The change merges through the protected-main process and is verified on canonical `main`.

## Verification

- Historical implementation evidence from #1990: Messaging Product Gate `32559833779` SUCCESS; Mahayana fast checks `32559833770` SUCCESS; Explicit automerge `32559833763` SUCCESS.
- Historical evidence proves the intended code path was tested, but **does not replace current-head CI** for this clean main-based landing.
- Current-head CI / PR / merge evidence: pending.

## Branch / PR

- Branch: `feat/telegram-m1-sqlite-main-sync`
- Base: latest canonical `main`
- Replacement PR: pending creation.
- Supersedes landing path of PR #1990; #1990 remains historical implementation evidence until the replacement is merged.

## Evidence locations

- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/src/bin/messaging-server.rs`
- `../../evidence/M1-T02-current-main/README.md`

## Next action

Open the clean current-main PR, obtain current GitHub Actions evidence, merge through protected-main governance, then verify and close the M1 storage gate on canonical `main`.
