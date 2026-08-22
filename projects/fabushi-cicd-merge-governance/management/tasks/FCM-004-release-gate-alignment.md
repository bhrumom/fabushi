# FCM-004 — Release gate alignment

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-004
- **Status:** in-progress
- **Started:** 2026-08-22
- **Updated:** 2026-08-22

## Objective

Align manual store delivery workflows with canonical release validation evidence so a store upload cannot start from an unprotected or platform-unverified source commit.

## Acceptance criteria

1. Store delivery workflows resolve an exact source SHA and verify it belongs to protected `main` history.
2. macOS delivery requires successful `CI result` and `Electron desktop result` for that exact SHA.
3. iOS/Android delivery requires successful `CI result` and `Native mobile result` for that exact SHA.
4. Apple `both` requires all three canonical gates.
5. Gate failure occurs before expensive build/sign/upload work.
6. GitHub Release evidence continues to target the exact delivered source SHA.
7. Delivery remains manually dispatched and does not weaken protected main.
8. Delivery-governance contract and canonical PR/merge-group CI pass before merge.

## Implementation

- Added `.github/scripts/require-release-source-gates.sh` with protected-main ancestry and exact-SHA check-run validation.
- Updated `.github/workflows/apple-store-delivery.yml` with `actions: read`, `checks: read`, and pre-build release-source gate.
- Updated `.github/workflows/google-play-delivery.yml` with the same permissions and Android pre-build gate.
- Added `.github/workflows/delivery-governance-contract.yml` to statically assert required release invariants.

## Branch / PR

- Branch: `fcm/fab-p0003-finalize`
- PR: #1999

## Evidence

Implementation commits are present on PR #1999. GitHub Actions and merge-queue acceptance evidence pending.

## Risks

- Store delivery from a historical main commit predating the gate script is intentionally prevented unless that source also contains the current release-governance script; the default supported release source is current protected `main`/post-policy history.
- Missing/failed quality gates are a release blocker, not a reason to bypass the check.

## Next action

Run PR contract/canonical CI, resolve failures, merge through protected queue, then verify the exact workflows on canonical `main`.
