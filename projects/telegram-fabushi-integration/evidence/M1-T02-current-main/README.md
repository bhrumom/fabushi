# M1.T02 current-main landing evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M1.T02`
- **Status**: `TESTED / LANDED`
- **Clean PR**: #1998
- **Merge**: `6ad86ccc809a6f00130888087f22cbb201e853fd`

## Runtime evidence

- `native/mahayana-messaging/src/store.rs`
  - `SqliteStateStore::import_json_if_empty`
  - legacy snapshot validation
  - import only while SQLite is empty
  - SQLite remains authoritative after import
- `native/mahayana-messaging/src/server.rs`
  - production `MessagingTcpServer` uses `SqliteStateStore`
  - optional legacy JSON import source
  - explicit database-path validation
- `native/mahayana-messaging/src/bin/messaging-server.rs`
  - `FABUSHI_MESSAGING_DATABASE`
  - default `fabushi-messaging.sqlite3`
  - compatibility import from `FABUSHI_MESSAGING_SNAPSHOT`

## Current-head GitHub Actions

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | `32563424543` | SUCCESS |
| Mahayana fast checks | `32563424539` | SUCCESS |
| Repository CI | `32563424556` | SUCCESS |
| Project portfolio governance | `32563424574` | SUCCESS |
| Fabushi self-hosted messaging | `32563424511` | SUCCESS |

Messaging Product Gate details:

- Rust self-hosted product job `97008408512`: rustfmt, messaging library/server tests, Clippy and Feature Host bridge/contact projection succeeded.
- Electron Messenger contract job `97008408644`: Feature Host architecture, signaling endpoint policy, Native Edge parity and Messenger V2 typecheck succeeded.

## Canonical-main verification

After #1998 merged, GitHub `main` was re-read and confirmed that production `MessagingTcpServer` is backed by `SqliteStateStore`; legacy JSON is consulted only as an import source when the authoritative database is empty.

## Historical provenance

PR #1990 contains the same intended production cutover and earlier successful CI, but was closed as superseded because its branch carried pre-portfolio-governance project-document snapshots. Its runtime evidence is retained without allowing those stale records to replace the canonical `FAB-P0001 / TFI` baseline.

## Result

All M1.T02 acceptance criteria are satisfied. This evidence is also referenced by `M1-ACCEPT-001` for M1 stage closure.
