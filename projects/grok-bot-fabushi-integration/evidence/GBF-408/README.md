# GBF-408 evidence index

Implementation paths: `mahayana-native-engine/src/lib.rs`, `mahayana-host/src/lib.rs`, `mahayana-app-host/src/lib.rs`, `desktop/electron/host-process.cjs`, native readiness tests and packaged Messenger E2E.

Primary dependency provenance: Microsoft `devcontainers/images` (MIT), official MCR Ubuntu 24.04 digest `sha256:c5cc2b45afe06a1df3aba17e58ba0dc4a02b999493198dab37dd0ccd4e2b0705`.

| Gate | Evidence | Status |
|---|---|---|
| Lightweight local inspection | CJS syntax + diff review only | PASSED |
| Rust/Node security tests | PR #2106 canonical seven-gate `32731980249` | PASSED |
| Windows/macOS/Linux packaged behavior | exact-main Electron `32733627050`; Windows Docker-ready state and cross-platform fallback behavior verified | PASSED |
| Release | delivery `32734915241`; `desktop-1.0.867` targets `f81588d3...` | PASSED |

GBF-408 is `RELEASED`.
