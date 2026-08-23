# FCM-007 — Merge all current PRs into main

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-007
- **Status:** in-progress
- **Started:** 2026-08-23
- **Updated:** 2026-08-23

## Objective

Integrate all pull-request work from the 2026-08-23 intake into canonical `main` without duplicating superseded history, losing stacked changes, or bypassing protected-main checks and merge queue rules.

## Source requirement

User request: merge all current PRs into `main`, then continue until all effective work is fully dispositioned.

## In scope

- Inspect every intake PR and current open PR against live GitHub state.
- Merge effective convergence PRs through required checks/merge queue.
- Repair deterministic CI or merge-conflict blockers when necessary.
- Close stacked/superseded PRs only after their effective changes are represented on canonical `main`.
- Re-read canonical `main` and verify no stale intake PR remains open.

## Out of scope

- Bypassing required CI, branch protection, or merge queue.
- Claiming a product release that its project-specific release acceptance has not proven.

## Acceptance criteria

1. Every intake PR is either merged or explicitly superseded by an effective merged replacement.
2. No required effective code/docs changes are lost from the final canonical lineage.
3. Stacked PRs are handled in dependency order or by a proven final convergence PR containing the stack.
4. Required GitHub Actions and protected-main rules are not bypassed.
5. Final verification shows canonical `main` contains the intended effective changes and no stale intake PR remains open.
6. FCM WBS/status/changelog/evidence are synchronized with the final GitHub facts.

## Verification

- Live PR metadata, diff lineage, mergeability and changed-file comparisons.
- GitHub Actions workflow/check evidence at each final landing point.
- Merge commit SHA for each effective convergence PR.
- Final `main` head SHA and final open-PR search.

## Intake inventory

Original open PRs: #1967, #1992, #1995, #2000, #2004, #2014, #2017, #2018, #2022, #2032, #2036, #2037, #2038.

Verified before this round:

- #1995 merged into `main`; registry repair #2040 also merged.
- #2017 merged and is the effective Mahayana convergence; #1992/#2000/#2004/#2014 were closed as superseded.
- #1967 was a reverse synchronization PR and was closed.
- #2018 was already represented on `main` and was closed as duplicate.
- Remaining effective work is Grok convergence #2036 and Telegram convergence stack #2022/#2037/#2038.

## Current blockers / risks

- `main` can advance while final PR checks run, requiring mergeability to be re-evaluated.
- Telegram #2038 was temporarily closed while applying a deterministic Rust exhaustive-match repair and must be reopened only after its final head is valid.
- Lower stacked PRs must not be closed until the final convergence lineage is verified on `main`.

## Next action

Finish Grok #2036 through protected merge, finish/reopen Telegram #2038 with its two exhaustive-match fixes, then close lower stacked PRs only after their effective changes are canonical. Finally update this task and merge the FCM-007 closure record.
