# 64 — 2026-09-05 M6 MAINSAFE Rust blocker WBS

Status: `ARCHITECTURE-RUST-BLOCKER-DIAGNOSED / NEXT-ATOMIC-TASK-FROZEN`

| Order | Task | Purpose | Allowlist | Unlock rule |
| --- | --- | --- | --- | --- |
| B0 | architecture blocker diagnosis | classify #2336 exact-head failures | TFI records only | complete |
| B1 | `TFI-M6-MAINSAFE-001-OWNERSHIP-001` | repair the shared `engine.rs` audit ownership defect | `native/mahayana-messaging/src/engine.rs` + TFI records | exact-head Actions green |
| B2 | fresh independent review for parent 001 | review full main-based #2336 diff after B1 | review/records only | B1 acceptance complete |
| B3 | protected merge queue + canonical readback | finish `TFI-M6-MAINSAFE-001-RUST-CANONICAL` | no bypass | review PASS + all required checks PASS |
| B4 | `TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION` | unchanged upper layer | previously frozen scope | only after B3 canonical readback |
| B5 | `TFI-M6-MAINSAFE-003-P0-CREATE-JOIN` | unchanged upper layer | previously frozen scope | only after 002 canonical readback |

No parallel execution of 002/003, review, merge, test-release or formal-release is authorized while B1 is unresolved.
