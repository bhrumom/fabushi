# M1-ACCEPT-001 evidence index

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Stage**: `M1`
- **Status**: `TESTED`

## Canonical implementation

- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/service.rs`
- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/server.rs`
- Electron Messenger V2 / Feature Host bridge covered by the product gate.

## Landed pull requests

- #1961 — canonical self-hosted messaging core foundation; merge `8062abb850020a702b4c8a85d8bd23d6b0470cb2`.
- #1988 — SQLite schema/storage; merge `1b78e4fbc1a666fc725c21450b11d3ab643ac0fa`.
- #1998 — production SQLite current-main cutover; merge `6ad86ccc809a6f00130888087f22cbb201e853fd`.

## Current-head acceptance run

PR #1998 head was validated by:

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | `32563424543` | SUCCESS |
| Mahayana fast checks | `32563424539` | SUCCESS |
| Repository CI | `32563424556` | SUCCESS |
| Project portfolio governance | `32563424574` | SUCCESS |
| Fabushi self-hosted messaging | `32563424511` | SUCCESS |

Messaging Product Gate job evidence:

- `Rust self-hosted product` job `97008408512`: rustfmt, messaging library/server tests, Clippy and Feature Host bridge/contact projection succeeded.
- `Electron Messenger contract` job `97008408644`: Feature Host architecture, self-hosted signaling endpoint policy, Native Edge parity and Messenger V2 typecheck succeeded.

## Canonical-main verification

Post-merge GitHub read confirmed production `MessagingTcpServer` is backed by `SqliteStateStore` and legacy JSON is only an import source while the SQLite database is empty.

## Result

M1.T01-T07 are accepted at `TESTED` for the Rust-core/desktop-host foundation. Cross-mobile and later product-domain E2E remain assigned to their own stages rather than being overclaimed here.
