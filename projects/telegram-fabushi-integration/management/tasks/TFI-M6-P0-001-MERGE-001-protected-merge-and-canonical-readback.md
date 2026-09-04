# TFI-M6-P0-001-MERGE-001 — protected merge and canonical-main readback

## Identity
- Project: `FAB-P0001 / TFI`
- Parent: `TFI-M6-P0-001`
- Type: atomic integration task
- Status: `BLOCKED_BY_FMT_001`

## Goal
Integrate the accepted P0-001 repair through the repository's protected path and prove the exact accepted content exists on canonical `main`. A merge of PR #2323 into its current base branch `codex/tfi-m6-repair` is not by itself canonical-main closure.

## Preconditions
All must be true on the same exact execution head:
1. `TFI-M6-P0-001-FMT-001` accepted.
2. Fresh independent review after the formatter source change returns `REVIEW-PASS`.
3. Every required GitHub Actions check is `SUCCESS`, including the Rust steps that were previously skipped behind formatter failure.
4. PR #2323 remains conflict-free and its exact base/head/changed-files are reread immediately before integration.

## Allowed scope
- protected PR/merge-queue/integration operations needed to carry the already reviewed P0-001 commit set to canonical `main`;
- TFI project/evidence write-back.

## Forbidden scope
- no new product/runtime/test/workflow implementation;
- no force-push that discards reviewed history;
- no bypass/admin merge around required checks or review requirements;
- no unrelated M6/P0-002+ changes;
- no declaration of FULL-CLOSE merely because an intermediate branch merge succeeded.

## Procedure contract
1. Record the exact #2323 head and required-check suite that earned the fresh REVIEW-PASS.
2. Complete #2323's protected integration to its base only if repository protection permits it.
3. Use the repository's existing protected consolidation path from `codex/tfi-m6-repair` to canonical `main`; do not invent a parallel implementation PR.
4. After canonical merge, read canonical `main` from GitHub and record the exact main SHA containing the accepted P0-001 changes.
5. Verify the three authorized P0-001 Rust files and task/evidence records at that exact main SHA match the accepted lineage.

## Acceptance
- no required gate/review bypass occurred;
- exact merge/integration PR numbers, merge commits and canonical-main SHA are recorded;
- GitHub readback proves the P0-001 accepted content exists on canonical main;
- canonical-main required checks associated with the integration path are green where the protected process requires them;
- there is no merge conflict or unreviewed semantic delta between the accepted P0-001 head and canonical-main landed content;
- project state advances only to `CANONICAL_MAIN_MERGED / PACKAGED_E2E_PENDING`, not FULL-CLOSE.

## Evidence
Record PR/merge-queue URLs or IDs, before/after SHAs, changed-file readback, required-check conclusions, and canonical-main commit provenance under `evidence/TFI-M6-P0-001/`.

## Rollback / risk
- Any conflict resolution that changes application/test semantics requires fresh code review and required CI before merge.
- If canonical main has moved such that the integration requires non-trivial code edits, stop with `BLOCKED: rebase/merge semantic delta` and return to architecture/review.
- Never reset canonical main to solve this task.

## Handoff
On acceptance, hand the exact canonical-main SHA to `TFI-M6-P0-001-E2E-001`. `TFI-M6-P0-002` remains blocked.
