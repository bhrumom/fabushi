# TFI-M6-MAINSAFE-003-P0-CREATE-JOIN — rebuild reviewed P0 create/join boundary on accepted main

- Project: `FAB-P0001 / TFI`
- Type: product-code atomic task
- Priority: P0 / layer 3
- Status: `BLOCKED-BY-TFI-M6-MAINSAFE-001/002`
- Owner model: one fresh execution-group session; then one fresh independent code-review session

## Dependency
Start only after tasks 001 and 002 are protected-merged and their exact accepted canonical main has been read back. This task does not retarget #2323 and does not inherit #2323 review coverage.

## Historical provenance
Use the #2323 base-relative P0 product repair (`30c6104...` / repair through `726b4210...`) as source provenance, together with later validated end-state constraints. Historical R3 PASS is evidence about that old base-relative object only; the new main-based residual must receive fresh independent review.

## Frozen file allowlist
Production:
- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/service.rs`

Tests:
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`

No `.github/workflows/tfi-m6-p0-001-atomic-gate.yml`; no other workflow; no Cargo/dependency/version/release file; no Electron file.

## Frozen behavior boundary
- Community-backed generic `CreateConversation` is an explicit idempotent no-op rather than an authority bypass.
- Community-backed generic `UpdateConversation` remains metadata-only and cannot replace Community membership/topics.
- `RequestCommunityJoin` for a missing Community returns `CommunityNotFound`; no placeholder Community is synthesized.
- Community join/creation response semantics preserve correct ownership and event projection on the now-accepted M6 Rust boundary.
- Focused positive/negative contract regressions cover only this create/join boundary.
- CLIPPY cleanup and MOD/UNREAD semantics already accepted through task 001 must not be duplicated or reverted.

## Execution method
1. Re-read canonical main after 001+002 and compute the residual of old #2323 product semantics.
2. If residual is empty/equivalent, stop `ALREADY-IN-MAIN` and close #2323 as obsolete only in a separately authorized governance step; do not create duplicate code.
3. Otherwise reconstruct only the residual three-file semantic patch with exact old-SHA/hunk provenance. Do not cherry-pick temporary workflow/history.
4. Open a fresh main-based product PR; #2323 remains immutable evidence until residual equivalence is established.

## Acceptance / Actions
- Product diff uses only the three allowlisted files plus TFI execution records.
- Fresh independent review explicitly compares the new residual with historical #2323 reviewed semantics and accepted canonical main; prior R3/CLIPPY PASS is not treated as review of the new main-based object.
- Required current Actions and `CI result` pass on exact head; focused M6 contract, all-target Rust tests, formatter/clippy and other required messaging gates must execute/pass.
- Protected merge queue only after fresh review PASS + all required checks.
- Exact canonical-main readback proves the residual is accepted before test-release resumes.

## Stop rules
STOP `ALREADY-IN-MAIN` if no product residual remains.
STOP `SCOPE-EXPANSION-REQUIRED` if any fourth product/test file, any Electron/workflow/Cargo/dependency/version change, or additional product behavior is needed.
STOP `ARCHITECTURE-MERGE-BLOCKED` on new semantic/security failure, non-equivalent residual, review rejection, red required CI, conflict, or inability to form an independently reviewable main-based diff.