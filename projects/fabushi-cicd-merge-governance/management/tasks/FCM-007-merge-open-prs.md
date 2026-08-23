# FCM-007 — Merge all current PRs into main

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-007
- **Status:** passed
- **Started:** 2026-08-23
- **Updated:** 2026-08-23
- **Completed:** 2026-08-23

## Objective

Integrate all effective work from the 2026-08-23 open-PR intake into canonical `main` without duplicating superseded history, losing stacked changes, or bypassing protected-main checks and GitHub merge-queue behavior.

## Source requirement

User requirement: merge all current PRs into `main`, then continue until all effective work is fully dispositioned.

## Intake

Original open PRs: #1967, #1992, #1995, #2000, #2004, #2014, #2017, #2018, #2022, #2032, #2036, #2037, #2038.

## Final disposition

| PR | Disposition | Canonical evidence |
|---|---|---|
| #1967 | closed; reverse-sync PR, not a main landing | no effective main delta required |
| #1992 | closed; superseded by final Mahayana convergence #2017 | #2017 merge `6ac1f62ada974956e0ba34c275fd56c4b8fd7c63` |
| #1995 | merged | DeepSeek Harness integration is on canonical main |
| #2000 | closed; superseded by #2017 | #2017 merge `6ac1f62ada974956e0ba34c275fd56c4b8fd7c63` |
| #2004 | closed; superseded by #2017 | #2017 merge `6ac1f62ada974956e0ba34c275fd56c4b8fd7c63` |
| #2014 | closed; superseded by #2017 | #2017 merge `6ac1f62ada974956e0ba34c275fd56c4b8fd7c63` |
| #2017 | merged; effective Mahayana convergence | `6ac1f62ada974956e0ba34c275fd56c4b8fd7c63` |
| #2018 | closed duplicate; its effective fix already existed on main | duplicate evidence recorded on PR |
| #2022 | closed; effective M3 carried by #2038; failed `rama-error` workaround excluded | #2038 merge `8220fdd091c9a9303c194a7257029ba9e4191ccc`; failed run `32609265654`, job `97119463578` |
| #2032 | closed; all 11 changed paths covered by final Grok convergence #2036 | #2036 merge `012569a9ad62925ac33311043439787d45072e2a` |
| #2036 | merged; effective Grok M8 convergence | `012569a9ad62925ac33311043439787d45072e2a` |
| #2037 | closed; M4 effective content covered by #2038, post-fork delta only formatting | #2038 merge `8220fdd091c9a9303c194a7257029ba9e4191ccc` |
| #2038 | merged; effective Telegram M3→M4→M5 convergence | `8220fdd091c9a9303c194a7257029ba9e4191ccc` |

Additional governed fixes required by convergence:

- #2040 merged the permanent project-registry repair for DeepSeek / `FAB-P0007` before further convergence.
- #2042 fixed a canonical-main Mahayana default dependency-graph regression discovered by #2038 merge-ref validation. It replaced default `mahayana-cli` reachability to vendor `codex-core-plugins` / `codex-tui` with Mahayana-owned compatibility packages without weakening the source-boundary checker; merged as `79e6ed19185c66aaf25691fd2c1d0dec0565f96c`.

## Acceptance criteria

1. Every intake PR is either merged or explicitly superseded by an effective merged replacement. **Passed.**
2. No required effective code/docs changes are lost from the final canonical lineage. **Passed.** Stacked Grok and Telegram changed-file lineage was explicitly compared before lower PRs were closed.
3. Stacked PRs are handled in dependency order or by a proven final convergence PR containing the stack. **Passed.** Mahayana=#2017, Grok=#2036, Telegram=#2038.
4. Required GitHub Actions and protected-main rules are not bypassed. **Passed.** Effective convergence PRs used GitHub checks/native auto-merge/queue behavior; deterministic blockers were repaired rather than ignored.
5. Final verification shows canonical `main` contains the intended effective changes and no stale intake PR remains open. **Passed.** Canonical main was re-read at `79e6ed19185c66aaf25691fd2c1d0dec0565f96c`; live open-PR search after feature convergence returned only the FCM governance-record PR, not an intake/product PR.
6. FCM WBS/status/changelog/evidence are synchronized with final GitHub facts. **Passed by this closure record once merged.**

## Important rejected workaround

#2022 contained a post-fork `rama-error = 0.2.0-alpha.3` pin that was not propagated to the final Telegram lineage. This was intentional: authoritative Mahayana Fast Checks run `32609265654`, job `97119463578`, failed the pinned crate with Rust `E0658` (`error_generic_member_access`). Closing #2022 therefore did not discard an accepted fix; it prevented a known-failing workaround from re-entering main.

## Final canonical state before closure-record merge

- Canonical `main`: `79e6ed19185c66aaf25691fd2c1d0dec0565f96c` (#2042).
- Original intake PRs still open: **0**.
- Effective product/convergence PRs still open: **0**.
- Only governance closure-record work remains; it does not carry product implementation.

## Verification

- Live PR metadata and changed-file comparisons.
- GitHub Actions workflow/job logs for blockers and final heads.
- Canonical `main` branch re-read after #2017, #2036, #2038 and #2042.
- Live final open-PR search.
