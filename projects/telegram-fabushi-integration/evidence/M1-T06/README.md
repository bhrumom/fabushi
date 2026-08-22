# M1.T06 Evidence — SQLite schema / durable local-first storage

## Scope

Task `M1.T06` implements versioned SQLite persistence behind the canonical `MessagingStateStore` contract in `native/mahayana-messaging`.

## Code evidence

- `native/mahayana-messaging/Cargo.toml`
- `native/mahayana-messaging/src/store.rs`
- PR #1988
- Verified PR head: `fc8197a8b5b1d738ae1a4d1d6110cd3bf5a92f39`

## GitHub Actions evidence

| Gate | Run | Result | Coverage |
|---|---:|---|---|
| Messaging Product Gate | 32559222693 | SUCCESS | rustfmt, all-target messaging tests, Clippy, Feature Host/contact projection, Electron Messenger contract |
| Mahayana fast checks | 32559222679 | SUCCESS | Mahayana source boundary + product Host/protocol/bridge regression |
| Explicit automerge | 32559222681 | SUCCESS | merge-policy automation precondition |

## Acceptance covered

- versioned database initialization;
- transactional save/reopen recovery;
- singleton overwrite semantics;
- full `u64` cursor persistence;
- future SQLite schema rejection;
- unknown snapshot schema rejection;
- compatibility with current Feature Host and Electron Messenger contracts.

## Resolved CI defect

The first implementation used `rusqlite 0.32`, which attempted to link `libsqlite3-sys 0.30` next to the Mahayana/Codex workspace `libsqlite3-sys 0.37`. Because Cargo permits only one crate with `links = "sqlite3"`, the dependency was aligned to `rusqlite 0.39`; both required gates then passed.

## Landing status

Current implementation status: `TESTED` on PR head. Final landed closure requires protected merge queue completion and canonical `main` verification.
