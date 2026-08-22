# FCM-005 — Ownership policy automation

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-005
- **Status:** in-progress
- **Started:** 2026-08-22
- **Updated:** 2026-08-22

## Objective

Add explicit ownership automation for sensitive delivery and governance paths without adding a repository-wide review tax to ordinary product changes.

## Acceptance criteria

1. CI/CD workflows, scripts, governance, release identity and high-risk payment surfaces have explicit CODEOWNERS ownership.
2. Low-risk paths are not covered by a repository-wide catch-all owner.
3. Ownership rules are objectively validated in GitHub Actions.
4. Existing merge queue and sensitive-automerge invariants remain intact.
5. The change passes canonical PR CI and protected merge-group validation.

## Implementation

- Added `.github/CODEOWNERS` with narrow sensitive-path ownership targeting `@bhrum`.
- Explicitly did not add `* @owner` or equivalent catch-all coverage.
- Added `Delivery governance contract` workflow to verify required ownership entries, release gates, merge-queue policy documentation and automerge sensitive prefixes.

## Branch / PR

- Branch: `fcm/fab-p0003-finalize`
- PR: #1999

## Evidence

Implementation is present on PR #1999; workflow and merge-queue evidence pending.

## Next action

Run delivery-governance/canonical CI, correct any policy-contract failures, merge through protected queue, and re-read CODEOWNERS on `main`.
