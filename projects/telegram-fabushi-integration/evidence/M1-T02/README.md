# M1.T02 Evidence — Production local-first storage

## Scope

Make SQLite the production persistence boundary for the canonical Fabushi messaging server while preserving a one-time, non-destructive migration path from the legacy JSON snapshot.

## Code evidence

- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/src/bin/messaging-server.rs`
- PR #1990
- Original implementation head: `031f49d015f5d51900e6003a8f2c46c839a64d7c`
- Main-retarget verification head: `174e1a0fdae82914f1f6e1c295870282ba6abcb1`

## GitHub Actions evidence

### Final verification against canonical `main`

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | 32559833779 | SUCCESS |
| Mahayana fast checks | 32559833770 | SUCCESS |
| Explicit automerge | 32559833763 | SUCCESS |

### Earlier stacked verification

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | 32559372311 | SUCCESS |
| Mahayana fast checks | 32559372278 | SUCCESS |
| Explicit automerge | 32559372304 | SUCCESS |

## Acceptance covered

- new installs choose `fabushi-messaging.sqlite3` by default;
- `FABUSHI_MESSAGING_DATABASE` selects the production DB explicitly;
- legacy `FABUSHI_MESSAGING_SNAPSHOT` is import-only;
- JSON is imported only if SQLite is empty;
- stale JSON cannot overwrite existing SQLite state;
- production service compiles/tests through the current Messaging Product Gate;
- current Mahayana Host and Electron Messenger contracts remain compatible;
- M1.T06 / PR #1988 has landed in canonical `main`, so the implementation no longer has a storage-foundation dependency blocker;
- #1990 was retargeted directly to `main` and the required gates passed again.

## Landing status

Implementation status: `TESTED` against canonical `main`. Remaining closure gate is protected merge-queue completion for #1990 and post-merge verification of the production SQLite path and this evidence record on `main`.
