# TFI-GOV-002 — Align Telegram project with enterprise project standard

- Project: `FABUSHI-TELEGRAM-FUSION`
- Task ID: `TFI-GOV-002`
- Status: `IMPLEMENTED`
- Started: `2026-08-22`
- Updated: `2026-08-22`

## Objective

Bring the existing Telegram integration project folder up to the repository's current enterprise project-folder standard without changing the project's product scope or source-of-truth rules.

## Implemented

- added `OWNERS.md` with product/architecture/client/CI/project-record accountability;
- added `management/06-依赖与阻塞.md` without replacing the existing PR/branch rules file;
- added `management/08-问题与行动项.md`;
- added `runbooks/README.md`, messaging-server, SQLite migration and rollback runbooks;
- moved `PROJECT.yaml` from `PLANNING_BASELINE` to `IMPLEMENTATION_ACTIVE`, current stage M1;
- closed M0 records against PR #1987 protected merge-queue evidence;
- refreshed status report, DOC-20 and file index;
- recorded active M1 tasks #1988 and #1990 as dependencies/actions.

## Acceptance criteria

1. Required enterprise project files exist under the same authoritative project folder: IMPLEMENTED.
2. M0 reflects PR #1987 merged through protected merge queue and verified on `main`: IMPLEMENTED.
3. Active M1 work (#1988/#1990) is represented as current dependencies/actions: IMPLEMENTED.
4. `PROJECT.yaml`, status report and file index agree on active implementation state: IMPLEMENTED.
5. Governance-only CI/merge-queue checks pass and files are verified on `main`: PENDING PR CI/MERGE.

## Branch / PR

- Branch: `project/telegram-enterprise-standard`
- PR: pending creation

## Evidence

- M0 audit PR #1987 merge: `5aeca75a1e9f6c5bd9fc376cf697012004c0766c`.
- Canonical project: `projects/telegram-fabushi-integration/`.
- New governance files: `OWNERS.md`, dependency/blocker register, action register, `runbooks/`.
- Active implementation: M1.T06 #1988; M1.T02 #1990.

## Remaining gate

Do not promote this task to `TESTED` until its PR is green, merges through protected `main`, and the canonical files are re-read from `main`.

## Next action

Create governance PR, pass repository checks, merge through protected main, then close TFI-GOV-002 in canonical project evidence.
