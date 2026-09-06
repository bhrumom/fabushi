# 59 — 2026-09-05 M6 protected-main-safe recovery risks and dependencies

## R1 Review-scope inflation — critical
Retargeting #2323 to main would silently enlarge the reviewed object from its stacked child delta to all parent product code. Mitigation: immutable #2323; fresh main-based layers only.

## R2 Squash ancestry discontinuity — high
`SQUASH` merge means historical lower-layer SHAs do not become main ancestors. Mitigation: each next task starts from exact accepted canonical main and re-computes semantic residual; do not rely on old SHA ancestry for upper layers.

## R3 Duplicate patch application — high
Blind cherry-pick/replay can duplicate semantics already accepted by a prior squash. Mitigation: ancestry + patch-id/range-diff/equivalent semantic comparison before every task; stop `ALREADY-IN-MAIN` when equivalent.

## R4 Intermediate red CI — high
Historical FMT/MOD/UNREAD/CLIPPY failures show old commit boundaries are not independently green. Mitigation: group repairs into the business-semantic main-safe end-state they belong to, then freshly review/test that object.

## R5 Temporary workflow leakage — critical
#2323 history contains a task-specific workflow whose historical revision removed `--locked`. Mitigation: workflow is excluded from every main-safe product allowlist; existing repository required CI remains authority.

## R6 Authority/privacy regression — critical
Community membership/topic/journal projection is security-sensitive. Mitigation: task 001 fresh full Rust semantic review plus negative contracts; task 002 fresh recipient-projection review.

## R7 Supply-chain/license expansion — stop rule
This recovery plan copies no upstream implementation and adds no dependency. Any external code/dependency/Cargo change triggers `SCOPE-EXPANSION-REQUIRED` and a new license/supply-chain review.

## Dependencies
Strict chain: architecture handoff -> 001 accepted canonical -> 002 accepted canonical -> 003 accepted/equivalent canonical -> test-release eligibility. No upper task may run against an unmerged stacked predecessor.