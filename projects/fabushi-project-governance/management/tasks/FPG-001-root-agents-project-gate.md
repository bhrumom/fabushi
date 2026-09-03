# FPG-001 — Root AGENTS Project-First Gate

- **Task ID:** FPG-001
- **Status:** passed
- **Started:** 2026-08-22T13:32:00+08:00
- **Updated:** 2026-08-22T13:38:00+08:00
- **Completed:** 2026-08-22T13:38:00+08:00

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

## Acceptance result

1. `AGENTS.md` mandates project lookup on every task — **passed**.
2. Existing project is reused and read before work — **passed**.
3. Missing project triggers standardized project folder/files before substantial work — **passed**.
4. Task record/WBS/acceptance/status/changelog/evidence closure is mandatory — **passed**.
5. Rule references the governance skill — **passed**.
6. New governance project exists on `main` — **passed**.
7. PR CI passes and merge queue completes — **passed**.

## Verification

- Root `AGENTS.md` fetched from `main` after merge and contains the Project-First repository gate.
- Required `CI result` on PR #1976 concluded success.
- PR #1976 merged through merge queue.
- Merge commit: `eaf273dafc140619b06b46a4d7d234997acde05d`.

## Branch / PR

- Branch: `project/fabushi-project-governance-agents`
- Initial commit: `b537329ed9fc0bdadcd8c51e27a92956b09181fd`
- Final PR head: `1a14b963f727dd98bbc73de414afbb13897d270d`
- PR: #1976
- Merge commit: `eaf273dafc140619b06b46a4d7d234997acde05d`

## Implementation summary

- Added repository-wide Project-First task governance to root `AGENTS.md`.
- Added canonical `projects/fabushi-project-governance/` project scaffold.
- Linked root governance gate to `.agent/skills/fabushi-project-governance/SKILL.md` and lifecycle references.
- Preserved existing local-disk and Faliu workflow instructions.

## Evidence

See `../../evidence/FPG-001/README.md`.

## Blockers / risks

None for FPG-001.

## Next action

Use this project for future repository-governance refinements; every other Fabushi task must resolve its own canonical project folder according to root `AGENTS.md`.
