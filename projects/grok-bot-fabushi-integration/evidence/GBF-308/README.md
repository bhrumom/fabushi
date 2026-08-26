# GBF-308 evidence index

Implementation paths: `mahayana-runtime/src/kernel_conversation.rs`, `mahayana-agent-kernel-bridge/src/lib.rs`, `mahayana-native-engine/src/lib.rs`, `desktop/electron/main.cjs`, `desktop/electron/native-capability-handlers.cjs`.

| Gate | Evidence | Status |
|---|---|---|
| Lightweight local inspection | diff review only; no local build/test | PASSED |
| Rust/Node integration | PR #2106 canonical seven-gate `32731980249` | PASSED |
| Protected-main readback | `f81588d33c1f10610ed0d0e4b147ae239b72b3a3` | PASSED |
| Packaged continuity journey | Electron `32733627050`; native mobile `32733627056`; exact-main visual/debug bundles retained | PASSED |
| Release | delivery `32734915241`; `desktop-1.0.867` targets exact main SHA | PASSED |

GBF-308 is `RELEASED`.
