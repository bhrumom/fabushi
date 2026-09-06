# 66 — 2026-09-05 M6 MAINSAFE Rust blocker acceptance matrix

| Acceptance ID | Evidence required | Current state |
| --- | --- | --- |
| `MS001-OWN-AC01-SCOPE` | #2336 remains canonical-main-based; repair delta only `engine.rs` + TFI records | PENDING |
| `MS001-OWN-AC02-OWNERSHIP` | E0505 at subscription add/remove and E0382 at join-response projection absent | PENDING |
| `MS001-OWN-AC03-MSG-GATE` | Messaging Product Gate Rust job reaches and passes rustfmt, `cargo test --all-targets`, Clippy `-D warnings`; Electron stays green | PENDING |
| `MS001-OWN-AC04-CONTRACTS` | `m6_channels_topics_contract` and `unread_projection_contract` actually execute and pass | PENDING |
| `MS001-OWN-AC05-SELFHOSTED` | Rust messaging core + Mahayana social → messaging Actor exact-head jobs PASS | PENDING |
| `MS001-OWN-AC06-HARNESS` | Mahayana fast reaches and passes Rust-native Mahayana Harness | PENDING |
| `MS001-OWN-AC07-REQUIRED-CI` | all selected/required exact-head repository gates PASS; generic CI does not override Rust workflows | PENDING |
| `MS001-OWN-AC08-REVIEW` | fresh independent review of exact main-based product diff after AC01–07 | BLOCKED |
| `MS001-OWN-AC09-MERGE` | protected merge queue acceptance + exact canonical-main readback | BLOCKED |
| `MS001-OWN-AC10-SEQUENCE` | 002/003/test-release remain locked until frozen predecessors close | ENFORCED |

## Diagnosed failing baseline for comparison
At #2336 exact head `115cd55065d03b66f14d7e086d454709d24d2286`:
- Messaging Product Gate `33914564827`: Rust self-hosted product `101158638727` FAIL; rustfmt PASS; `cargo test --all-targets` fails compiling `fabushi-messaging-core`; Clippy and later Rust steps skipped. Electron Messenger contract current job `101158639006` PASS.
- Fabushi self-hosted messaging `33914564790`: current latest-attempt Rust messaging core `101158721014` FAIL and Mahayana social → messaging Actor `101158720692` FAIL through the same `fabushi-messaging-core` compile diagnostics.
- Mahayana fast `33914564807`: `101158616359` reaches `Test Rust-native Mahayana Harness`, then FAILS because that harness build reaches the same messaging-core compilation defect; no independent harness defect is evidenced at this baseline.
- CI `33914564928`: current `CI result` job `101158917285` PASS. Exact-head auxiliary PASS runs currently read back as Explicit automerge `33914564792`, Developer Fiat Commerce `33914564803`, Project portfolio governance `33914564951`. None substitutes for the failed Rust gates.

Historical formatting-only run `33914142883` belongs to the earlier `219c3e7b...` head and was repaired by the later rustfmt commit; it is not the ownership blocker baseline.
