# M1.T02 Evidence — Production local-first storage

## Scope

Make SQLite the production persistence boundary for the canonical Fabushi messaging server while preserving a one-time, non-destructive migration path from the legacy JSON snapshot.

## Code evidence

- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/src/bin/messaging-server.rs`
- PR #1990
- Verified code head: `031f49d015f5d51900e6003a8f2c46c839a64d7c`

## GitHub Actions evidence

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
- production service compiles/tests through current Messaging Product Gate;
- current Mahayana Host integration remains compatible.

## Landing status

Implementation is `TESTED` on the stacked PR head. It remains dependency-blocked from landing until M1.T06 / PR #1988 is in canonical `main`; after retargeting to `main`, current-head checks must pass again before protected merge queue completion.
