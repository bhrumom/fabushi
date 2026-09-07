# 2026-09-05 — M6 MAINSAFE VERSION exact-head review state sync

This record is the minimal reviewer-side synchronization for the existing acceptance/status/changelog/risk/dependency/action registers. It does not rewrite unrelated historical rows. The detailed evidence lives in the task/evidence/handoff review records for the same round.

## Identity

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement: `M6-PM-VEHC-R01`
- Acceptance: `M6-PM-VEHC-A01`
- Product PR / exact reviewed head: `#2345@9c46c1d8f030be390995cc78f321aac0d96b7f44`
- Product base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Review result: `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`

## Acceptance-matrix synchronization

The existing `management/03-验收追踪矩阵.md` PR-stage row was previously `BLOCKED UNTIL EXECUTION`. Reviewer evidence now advances only the PR/review portion as follows:

| Acceptance slice | Reviewer state | Evidence / next gate |
|---|---|---|
| `M6-PM-VEHC-A01 / PR` | `REVIEW-PASSED` | final head `9c46...`; CI `33937479501`; canonical job `101228105692`; aggregate `101228236513`; reviewer task/evidence records |
| `M6-PM-VEHC-A01 / merge_group` | `BLOCKED UNTIL PROTECTED QUEUE` | test-release owner must obtain current group-SHA raw proof after this review |
| `M6-PM-VEHC-A01 / canonical main` | `BLOCKED UNTIL QUEUE MERGE` | exact canonical-main readback after protected merge |

No packaged test-release or stable-release acceptance is advanced by this review.

## Status synchronization

The existing architecture/status wording that the successor was merely `FROZEN / NEXT-ONLY-EXECUTABLE` is superseded for this exact execution lineage by the following reviewer state:

- #2345 exact product head `9c46...`: `EXECUTION-PASSED / INDEPENDENT-REVIEW-PASSED / OPEN / UNMERGED`.
- Protected canonical-main merge gate: `AUTHORIZED-NEXT`, but only for the exact unchanged reviewed head and only via the downstream test-release owner / protected merge queue.
- Packaged test release: `NOT STARTED / STILL BLOCKED BY DOWNSTREAM MAINSAFE PREREQUISITES`.
- Stable release: `NOT STARTED / NOT AUTHORIZED`.

## Changelog synchronization

2026-09-05 independent review established that replacement PR #2345 fixes the #2343 evidence-identity defect without changing canonical version logic:

- PR checkout is explicit to event PR head;
- worktree identity is asserted fail-closed before the unchanged canonical script;
- merge-group remains bound to the current group SHA;
- required `CI result` fails unless the canonical child is exact `success`;
- iOS mirror is the single semantic version change `28 -> 29`;
- final raw automatic evidence is bound to exact head `9c46...`.

## Risk synchronization

Existing risks `RISK-M6-VEHC-001` through `RISK-M6-VEHC-005` are not deleted. Reviewer disposition for the exact #2345 PR stage:

- `RISK-M6-VEHC-001` (metadata green but synthetic checkout): **MITIGATED FOR PR STAGE** by explicit exact-head checkout + actual HEAD assertion + raw proof on `9c46...`.
- `RISK-M6-VEHC-002` (incorrectly reusing PR head for merge_group): **OPEN DOWNSTREAM**; static semantics pass, but real merge-group evidence is intentionally pending protected queue.
- `RISK-M6-VEHC-003` (skipped/neutral/manual/historical substitution): **MITIGATED FOR PR STAGE**; canonical child exact-success is required and automatic attempt-1 raw evidence is used.
- `RISK-M6-VEHC-004` (scope expansion): **MITIGATED FOR THIS PR**; exact changed-file allowlist passes.
- `RISK-M6-VEHC-005` (historical provenance mutation): **MITIGATED FOR THIS REVIEW**; #2341/#2342/#2343/#2344 remain OPEN / UNMERGED and unchanged.

Non-blocking INFO: repository-existing `actions/checkout@v5` major-tag pinning is weaker than full immutable SHA pinning. It is not introduced by this task and is left for a separately scoped supply-chain hardening task.

## Dependency synchronization

- `DEP-M6-VEHC-002 independent code review`: **SATISFIED** for exact `#2345@9c46...` by `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`.
- `DEP-M6-VEHC-003 protected merge queue`: **UNBLOCKED AS NEXT GATE**, not executed by reviewer. Requires current `merge_group` actual HEAD == group SHA + canonical child SUCCESS + same-group required `CI result` SUCCESS.
- `DEP-M6-VEHC-004 canonical readback`: remains **BLOCKED UNTIL PROTECTED MERGE**.
- `DEP-M6-VEHC-005 broader MAINSAFE test-release prerequisites`: remains **BLOCKED** independently of this code-review PASS.

## Action synchronization

- `ACT-M6-VEHC-004 independent review`: **CLOSED FOR EXACT HEAD 9c46...** with reviewer task/evidence/handoff records.
- `ACT-M6-VEHC-005 protected merge queue`: **READY / NEXT OWNER = test-release project group**; reviewer does not enqueue.
- `ACT-M6-VEHC-006 canonical readback`: remains **BLOCKED** pending queue merge.
- `ACT-M6-VEHC-007 test/stable release`: remains **BLOCKED / NOT STARTED**.
- `ACT-M6-VEHC-008 historical provenance`: remains **ACTIVE DISCIPLINE / SATISFIED THIS ROUND**; no old PR was modified.

## ADR index synchronization

`decisions/README.md` is updated in this reviewer branch to index the directly governing `ADR-0014 — Event-aware exact-head checkout gate`. No ADR is created or superseded by this code review.

## Binding review records

- `management/tasks/TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001-REVIEW-001.md`
- `evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-REVIEW-2026-09-05.md`
- `management/91-2026-09-05-M6-MAINSAFE-001-VERSION-EXACT-HEAD-独立代码审查交接.md`

Any later product-head commit invalidates the synchronized PASS and reopens the PR-stage evidence/review dependency.
