# MSR-001 — Establish project baseline

- **Task ID:** MSR-001
- **Status:** passed
- **Started:** 2026-08-22T15:00:00+08:00
- **Updated:** 2026-08-22T15:24:00+08:00
- **Completed:** 2026-08-22T15:17:22+08:00

## Objective
Create the canonical enterprise project folder for the already-started Codex + Grok Build -> sovereign Mahayana convergence work, preserving existing implementation evidence and preventing duplicate PR streams.

## Source requirements
User requirement in `source/README.md`; GitHub PRs #1963/#1968/#1971; upstream repositories; `docs/mahayana-sovereign-kernel.md`; `SOURCES.lock`.

## In scope
Project identity, source-of-truth, architecture/requirements, roadmap/WBS, acceptance, risks, ADR/evidence/runbook indexes, historical PR reconciliation.

## Out of scope
New runtime code in this task.

## Acceptance criteria
1. Mandatory project scaffold exists and is non-empty. **Passed.**
2. #1971 is recorded as canonical merged implementation baseline. **Passed.**
3. Superseded/obsolete PRs are distinguished from canonical work. **Passed.**
4. Initial requirements, milestones, tasks, risks and acceptance matrix exist. **Passed.**
5. Project-baseline PR passes required CI, merges, and is verified on main. **Passed.**

## Verification
- PR: #1989 `docs(project): establish Mahayana sovereign runtime project`.
- PR head: `a78de9b728ea2bdb9669aa1a6b57fa693479d711`.
- CI run: `32559149040`, conclusion `success`.
- Protected merge: `88db63c328c3cba39971f3942509cb0b582502bc`.
- Post-merge verification: project folder and this task were re-read from GitHub `main`.

## Branch / commit / PR
Branch: `docs/mahayana-sovereign-runtime-project`
Commit: `a78de9b728ea2bdb9669aa1a6b57fa693479d711`
PR: #1989
Merge: `88db63c328c3cba39971f3942509cb0b582502bc`

## Implementation summary
The enterprise project scaffold is canonical on `main`, with M0-M6 roadmap, stable MSR requirement/task IDs, historical PR reconciliation, acceptance/risk/dependency records, ADR/evidence/runbook indexes, and #1971 as the implementation baseline.

## Evidence
See `evidence/MSR-001/README.md`.

## Blockers / risks
None for MSR-001.

## Next action
Continue MSR-101/MSR-102 upstream capability audit and MSR-103 native auth/secrets boundary work in the same canonical project.
