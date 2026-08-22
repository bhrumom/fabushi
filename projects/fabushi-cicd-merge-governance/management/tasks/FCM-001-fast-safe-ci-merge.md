# FCM-001 — Fast, Safe CI & Merge Queue

- **Task ID:** FCM-001
- **Status:** in-progress
- **Started:** 2026-08-22T13:43:00+08:00
- **Updated:** 2026-08-22T13:43:00+08:00

## Objective

Remove unnecessary CI/CD latency for documentation and low-impact changes while preserving enterprise-grade protected-main and merge-queue safety.

## Source requirement

`../../source/README.md`

## Acceptance criteria

See `../../docs/19-完成定义与验收.md`.

## Planned implementation

- `.github/workflows/ci.yml`
- `.github/workflows/automerge.yml`
- `.github/workflows/deploy-production.yml`
- `.github/workflows/fabushi-pay-production.yml`
- `.github/BRANCH_PROTECTION.md`

## Verification

- PR-head required CI result.
- Inspect selected/skipped job set.
- Merge through GitHub merge queue.
- Inspect merge-group selected/skipped job set.
- Verify canonical main workflow files.

## Branch / PR

Pending.

## Evidence

Pending.

## Next action

Create governed implementation branch and patch workflows.
