# FCM-001 — Fast, Safe CI & Merge Queue

- **Task ID:** FCM-001
- **Status:** in-progress
- **Started:** 2026-08-22T13:43:00+08:00
- **Updated:** 2026-08-22T13:51:00+08:00

## Objective

Remove unnecessary CI/CD latency for documentation and low-impact changes while preserving enterprise-grade protected-main and merge-queue safety.

## Source requirement

`../../source/README.md`

## Acceptance criteria

See `../../docs/19-完成定义与验收.md`.

## Implementation

- `.github/workflows/ci.yml`
  - merge-group now uses exact `base_sha..head_sha` impact classification instead of force-all;
  - classifier no longer needs repository checkout for path discovery;
  - Tier-0 documentation/project paths select no unrelated product suites;
  - unknown non-document paths fail safe by selecting all canonical domains;
  - merge-group trigger is explicitly limited to `checks_requested`.
- `.github/workflows/automerge.yml`
  - removes direct protected-branch REST merge behavior;
  - arms GitHub-native auto-merge/protected merge so merge queue owns final merge-group validation.
- `.github/workflows/deploy-production.yml`
  - lightweight source-impact resolver skips Worker staging/migration/deploy when Worker inputs did not change.
- `.github/workflows/fabushi-pay-production.yml`
  - lightweight source-impact resolver skips payment migration/deploy when payment inputs did not change.
- `.github/BRANCH_PROTECTION.md`
  - codifies risk tiers, aggregate `CI result`, merge-queue ownership, change-aware CD and latency policy.

## Verification

- PR-head required `CI result`.
- Inspect selected/skipped job set for this CI/CD-only change.
- Merge through GitHub merge queue.
- Inspect merge-group selected/skipped job set; it should not force Frontend/Worker/MCP/Electron solely because of `merge_group`.
- Verify canonical main workflow files.

## Branch / PR

- Branch: `project/fabushi-cicd-merge-governance`
- Bootstrap commit: `c7581c7b21070e17e3a344d1b079bec51f59d46a`
- PR: pending creation.

## Evidence

Pending PR/CI/merge evidence.

## Risks

Workflow files are sensitive delivery infrastructure, so this task must not use unattended automerge. It requires explicit authorization plus required CI and merge-queue validation.

## Next action

Create the implementation PR, inspect workflow parsing and required CI, fix any failures, then enqueue explicitly after green checks.
