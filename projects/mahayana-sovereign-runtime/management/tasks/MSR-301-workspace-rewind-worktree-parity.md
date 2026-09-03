# MSR-301 — Workspace, worktree, checkpoint and rewind parity

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-301
- **Status:** in-progress
- **Started:** 2026-08-22T16:56:00+08:00
- **Updated:** 2026-08-22T16:56:00+08:00
- **Completed:** null

## Objective
Make Mahayana workspace rewind exact and managed worktrees Git-aware, isolated and objectively recoverable.

## Source requirements
MSR-R03, MSR-R08; Grok Build checkpoint/rewind and managed-worktree capabilities.

## In scope
Exact restore for created/modified/deleted files; checkpoint manifest validation; Git-aware worktree creation/registration; cleanup metadata; conformance tests.

## Out of scope
Remote Git hosting operations.

## Dependencies
MSR-102.

## Acceptance criteria
1. Restoring a checkpoint recreates checkpoint files and removes files created after the checkpoint within managed scope.
2. Restore does not cross the workspace root or symbolic-link boundaries.
3. In Git repositories, managed worktrees are registered through Git and isolated from the source checkout.
4. Non-Git workspaces retain deterministic projected-worktree fallback.
5. CI proves create/delete/modify rewind and Git worktree behavior.
6. Protected merge and canonical-main verification complete.

## Verification
`mahayana-workspace-engine` tests in Mahayana Fast Checks; Git fixture tests; source audit.

## Branch / commit / PR
Branch: `feat/msr-native-runtime-parity`
Commit: pending
PR: pending

## Implementation summary
Pending implementation.

## Evidence
Pending CI/merge evidence.

## Blockers / risks
Destructive restore must be limited to the checkpoint-managed workspace file set and exclude `.git`, `.mahayana`, build caches and symlinks.

## Next action
Harden checkpoint manifests/restore and add Git-aware worktrees.
