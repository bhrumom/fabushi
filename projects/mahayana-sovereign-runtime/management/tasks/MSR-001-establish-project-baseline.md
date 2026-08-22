# MSR-001 — Establish project baseline

- **Task ID:** MSR-001
- **Status:** in-progress
- **Started:** 2026-08-22T15:00:00+08:00
- **Updated:** 2026-08-22T15:14:00+08:00
- **Completed:** null

## Objective
Create the canonical enterprise project folder for the already-started Codex + Grok Build -> sovereign Mahayana convergence work, preserving existing implementation evidence and preventing duplicate PR streams.

## Source requirements
User requirement in `source/README.md`; GitHub PRs #1963/#1968/#1971; upstream repositories; `docs/mahayana-sovereign-kernel.md`; `SOURCES.lock`.

## In scope
Project identity, source-of-truth, architecture/requirements, roadmap/WBS, acceptance, risks, ADR/evidence/runbook indexes, historical PR reconciliation.

## Out of scope
New runtime code in this task.

## Acceptance criteria
1. Mandatory project scaffold exists and is non-empty.
2. #1971 is recorded as canonical merged implementation baseline.
3. Superseded/obsolete PRs are distinguished from canonical work.
4. Initial requirements, milestones, tasks, risks and acceptance matrix exist.
5. Project-baseline PR passes required CI, merges, and is verified on main.

## Verification
Repository path audit; PR metadata checks; required GitHub Actions; post-merge fetch from main.

## Branch / commit / PR
Branch: `docs/mahayana-sovereign-runtime-project`
Commit: pending
PR: pending

## Implementation summary
Enterprise project scaffold prepared with M0-M6 roadmap and stable MSR task/requirement IDs.

## Evidence
See `evidence/MSR-001/README.md`.

## Blockers / risks
Protected-main CI/merge pending.

## Next action
Commit tree, open PR, inspect required checks, merge through protected flow, verify main; then begin MSR-101.
