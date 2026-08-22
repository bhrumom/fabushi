# FPG-001 — Root AGENTS Project-First Gate

- **Task ID:** FPG-001
- **Status:** in-progress
- **Started:** 2026-08-22T13:32:00+08:00
- **Updated:** 2026-08-22T13:34:00+08:00

## Objective

Make root `AGENTS.md` require every Fabushi repository task to locate/reuse a project folder, or create the standardized folder/files when no matching project exists, and to close the task by updating project records and evidence.

## Source requirement

`../../source/README.md`

## In scope

- root `AGENTS.md` repository-wide rule;
- new `projects/fabushi-project-governance/` scaffold;
- linkage to existing governance skill;
- GitHub PR/CI/merge evidence.

## Out of scope

- product runtime behavior;
- changing unrelated Faliu or disk-safety rules;
- automatic CI enforcement beyond this task.

## Dependencies

- existing `.agent/skills/fabushi-project-governance/` merged on main via PR #1975;
- repository merge queue and required `CI result`.

## Acceptance criteria

1. `AGENTS.md` mandates project lookup on every task.
2. Existing project is reused and read before work.
3. Missing project triggers standardized project folder/files before substantial work.
4. Task record/WBS/acceptance/status/changelog/evidence closure is mandatory.
5. Rule references the governance skill.
6. This new governance project exists on `main`.
7. PR CI passes and merge queue completes.

## Verification

- Review changed files and root AGENTS section.
- Confirm required CI job `CI result` succeeds.
- Confirm PR merges through merge queue.
- Fetch `AGENTS.md` and this project folder from `main` after merge.

## Branch / PR

- Branch: `project/fabushi-project-governance-agents`
- Initial commit: `b537329ed9fc0bdadcd8c51e27a92956b09181fd`
- PR: #1976

## Implementation summary

- Added repository-wide Project-First task governance to root `AGENTS.md`.
- Added the canonical `projects/fabushi-project-governance/` project scaffold.
- Linked the root governance gate to the existing `.agent/skills/fabushi-project-governance/SKILL.md` and lifecycle references.
- Preserved existing local-disk and Faliu workflow instructions.

## Evidence

- PR #1976 contains 19 changed files and the complete initial governance bootstrap.
- CI and canonical `main` verification are still pending.

## Blockers / risks

None currently; task remains in-progress until required CI and merge-queue verification complete.

## Next action

Run required GitHub checks, enter merge queue, then verify canonical `main` and close project records.
