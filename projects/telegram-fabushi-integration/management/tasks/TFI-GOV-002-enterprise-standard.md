# TFI-GOV-002 — Align Telegram project with enterprise project standard

- Project: `FABUSHI-TELEGRAM-FUSION`
- Task ID: `TFI-GOV-002`
- Status: `TESTED`
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
- refreshed status report, DOC-20, changelog and file index;
- recorded active M1 tasks #1988 and #1990 as dependencies/actions.

## Acceptance result

1. Required enterprise project files exist under the same authoritative project folder: PASS.
2. M0 reflects PR #1987 protected merge queue + canonical main evidence: PASS.
3. Active M1 work (#1988/#1990) is represented in durable dependencies/actions: PASS.
4. `PROJECT.yaml`, status report, file index and evidence agree on active implementation state: PASS.
5. Current-head governance CI: PASS.

## Branch / PR

- Branch: `project/telegram-enterprise-standard`
- PR: #1991 `docs(telegram): align project with enterprise governance standard`
- Current verified head before this evidence-only update: `181a198e81aba8747cd613e55b38de8313701a5b`

## CI evidence

- CI run `32559675024`: SUCCESS.
- Explicit automerge run `32559675098`: SUCCESS.
- Earlier implementation head CI `32559613482`: SUCCESS.

## Durable evidence

- `../../evidence/TFI-GOV-002/README.md`
- M0 audit PR #1987 merge: `5aeca75a1e9f6c5bd9fc376cf697012004c0766c`.
- Canonical project: `projects/telegram-fabushi-integration/`.

## Remaining landing gate

`TESTED` records current-head validation. Final landed closure still requires protected merge queue completion and canonical `main` verification.

## Next action

Enter protected merge queue for #1991; after merge, re-read the canonical project files from `main` and close landing evidence.
