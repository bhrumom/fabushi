# GBF-408 evidence index

Implementation paths: `mahayana-native-engine/src/lib.rs`, `mahayana-host/src/lib.rs`, `mahayana-app-host/src/lib.rs`, `desktop/electron/host-process.cjs`, native readiness tests and packaged Messenger E2E.

Primary dependency provenance: Microsoft `devcontainers/images` (MIT), official MCR Ubuntu 24.04 digest `sha256:c5cc2b45afe06a1df3aba17e58ba0dc4a02b999493198dab37dd0ccd4e2b0705`.

| Gate | Evidence | Status |
|---|---|---|
| Lightweight local inspection | CJS syntax + diff review only | PASSED |
| Rust/Node security tests | PR #2106: security `32725103937`, platform `32725103983`, multi-platform contracts `32725103959` | PASSED; final consolidated rerun pending |
| Windows/macOS/Linux packaged behavior | exact-main workflow/artifacts | PENDING |
| Release | tag/assets/target SHA | PENDING |

The task remains `IMPLEMENTED`, not completed, until all required gates pass.
