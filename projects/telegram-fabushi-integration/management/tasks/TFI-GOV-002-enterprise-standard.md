# TFI-GOV-002 — Align Telegram project with enterprise project standard

- Project: `FABUSHI-TELEGRAM-FUSION`
- Task ID: `TFI-GOV-002`
- Status: `IN_PROGRESS`
- Started: `2026-08-22`
- Updated: `2026-08-22`

## Objective

Bring the existing Telegram integration project folder up to the repository's current enterprise project-folder standard without changing the project's product scope or source-of-truth rules.

## Scope

- add explicit ownership;
- add dependency/blocker register;
- add issue/action register;
- add runbook index and initial operational runbooks;
- close M0 post-merge bookkeeping with canonical `main` evidence;
- move project metadata from planning-only to active implementation;
- preserve existing roadmap/WBS/ADR history.

## Acceptance criteria

1. Required enterprise project files exist under the same authoritative project folder.
2. M0 reflects PR #1987 merged through the protected merge queue and verified on `main`.
3. Active M1 work (#1988/#1990) is represented as current dependencies/actions, not hidden in chat.
4. `PROJECT.yaml`, status report, file index and project evidence agree on active implementation state.
5. Governance-only CI/merge-queue checks pass and the files are verified on `main`.

## Branch / PR

- Branch: `project/telegram-enterprise-standard`
- PR: pending

## Evidence

- M0 audit PR #1987 merged at `5aeca75a1e9f6c5bd9fc376cf697012004c0766c`.
- `projects/telegram-fabushi-integration/` is the repository-authoritative source of truth.

## Next action

Add missing standard files and reconcile project status after M0 merge.
