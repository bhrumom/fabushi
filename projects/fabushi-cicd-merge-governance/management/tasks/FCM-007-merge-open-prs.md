# FCM-007 — Merge all current PRs into main

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-007
- **Status:** in-progress
- **Started:** 2026-08-23
- **Updated:** 2026-08-23

## Objective

Integrate all currently open Fabushi pull-request work into canonical `main` without duplicating superseded history or bypassing stacked dependencies, then close obsolete PRs only after their effective changes are represented by the final merged lineage.

## Source requirement

User request on 2026-08-23: merge all current PRs into `main`.

## In scope

- Inspect every currently open PR and its base/head relationship.
- Identify stacked PRs and superseded/convergence PRs.
- Merge effective final changes through the repository's protected-main process.
- Retarget stacked PRs to `main` after prerequisite layers land.
- Close obsolete/superseded PRs only when their changes are fully represented by a replacement/final convergence PR.
- Re-read canonical `main` and open-PR state after execution.

## Out of scope

- Rewriting unrelated feature scope.
- Claiming release/project completion when project-specific acceptance or release gates remain open.

## Acceptance criteria

1. Every open PR at intake is dispositioned as merged or explicitly superseded/closed with an effective merged replacement.
2. No required effective code/docs changes are lost from the canonical final lineage.
3. Stacked PRs are processed in dependency order and retargeted to `main` when their prerequisite layer has landed.
4. Required GitHub Actions/merge-queue protections are not bypassed.
5. Final verification shows the intended changes on canonical `main` and no stale open PR remains from the intake set.

## Verification

- Live GitHub PR metadata and mergeability.
- GitHub Actions workflow/check evidence at each landing point.
- Merge result SHA for each effective PR.
- Final `main` head SHA and final open-PR search.

## Intake inventory

Open PRs at start: #1967, #1992, #1995, #2000, #2004, #2014, #2017, #2018, #2022, #2032, #2036, #2037, #2038.

Known convergence/supersession relationships from live PR descriptions:

- #2017 is the canonical final convergence for FAB-P0005 and supersedes #2014; once merged it makes #2000 unnecessary as a separate landing step. #2000 already replaced polluted #1992. #2004 is an earlier stacked runtime continuation covered by the later final convergence lineage.
- #2037 is stacked on #2022; #2038 is stacked on #2037.
- #2036 is stacked on #2032.
- #1967 merges `main` into an older Mahayana feature branch rather than targeting `main`; it is a synchronization PR, not a product change landing PR to canonical main.

## Blockers / risks

- Several PRs currently report merge conflicts against their present base.
- Stacked PRs cannot be correctly retargeted until prerequisite layers land.
- Project-specific CI/release gates may prevent immediate merge even when Git conflicts are resolved.

## Next action

Land the governed task record, then process effective PRs in dependency order using live CI/merge evidence and close superseded synchronization/history PRs only after canonical coverage is verified.
