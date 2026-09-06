# 69 — 2026-09-05 M6 MAINSAFE Rust blocker architecture change log

- Re-read canonical main from GitHub and confirmed `688465e94647d4c866f6b1d7b4884145b2f4a9da` remained canonical at diagnosis freeze.
- Re-read #2335 and the protected-main-safe 001→002→003 dependency records; preserved the strict sequence without starting upper layers.
- Re-read #2336 base/head, changed-files, six-commit ancestry and the four execution records. Confirmed no product/test path outside the original 001 allowlist.
- Re-read exact-head Actions instead of trusting stale handoff identifiers. Confirmed Messaging Product Gate, Fabushi self-hosted messaging and Mahayana fast are red; generic CI plus current Explicit automerge, Developer Fiat Commerce and portfolio governance runs are green but non-substitutive.
- Read the failed Rust job logs and located E0505 at `engine.rs:1789` and `engine.rs:1825`, plus E0382 at `engine.rs:2204` caused by prior ownership moves at the audit calls around lines 2171/2185.
- Classified all three diagnostics as one shared audit ownership-boundary defect: a canonical identity must remain available for borrow-based authorization/state/projection while the audit entry independently retains an owned target identity.
- Read current self-hosted social Actor and Mahayana Harness logs and classified their failures as downstream compilation failures through `fabushi-messaging-core`, not independently evidenced defects at this baseline.
- Compared the repair design against Rust official E0505/E0382 guidance and Ruma/Matrix's mature borrowed `UserId` / owned `OwnedUserId` boundary. Adopted the ownership principle only; copied no implementation and added no dependency.
- Rejected type/API/helper redesign, `Copy` for the String-backed `ActorId`, Rc/Arc overengineering, Cargo/dependency changes, test/workflow changes, semantic reorder and broad cleanup.
- Froze `TFI-M6-MAINSAFE-001-OWNERSHIP-001` with one production-file allowlist: `native/mahayana-messaging/src/engine.rs`, plus TFI records.
- Added blocker-specific WBS, milestone, acceptance, risk/dependency, status, evidence and handoff records. Architecture changed no product/test/workflow/Cargo/dependency/version file.
