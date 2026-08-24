# GBF-308 evidence index

Implementation paths: `mahayana-runtime/src/kernel_conversation.rs`, `mahayana-agent-kernel-bridge/src/lib.rs`, `mahayana-native-engine/src/lib.rs`, `desktop/electron/main.cjs`, `desktop/electron/native-capability-handlers.cjs`.

| Gate | Evidence | Status |
|---|---|---|
| Lightweight local inspection | diff review only; no local build/test | PASSED |
| Rust/Node integration | PR #2106: CI `32725104017`, messaging `32725103886`, Host `32725104003`; Rust fast `32725103949` found and drove repair of a feature-gated import | FINAL RERUN PENDING |
| Protected-main readback | exact merge SHA | PENDING |
| Packaged continuity journey | screenshots/video/trace/report/log for exact main SHA | PENDING |
| Release | tag/assets/target SHA | PENDING |

The task remains `IMPLEMENTED`, not completed, until all required gates pass.
