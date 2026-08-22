# Source of Truth

The canonical project record is `bhrumom/fabushi` `main` under `projects/fabushi-project-governance/`.

## Designated requirement sources

- `source/README.md` — original repository-wide project-first governance requirement.
- `source/2026-08-22-FPG-002-enterprise-project-standard.md` — requirement to align Task Orchestration, root `AGENTS.md`, repository Skills, and project folders with an enterprise-standard project-document model.

## Precedence

1. Latest explicit user requirement after being persisted into this project folder.
2. This file and designated source files.
3. Accepted ADRs and current normalized specs under `docs/`.
4. Current roadmap, WBS, milestones, acceptance, risks, dependencies, status, changelog, issues/actions, and task records.
5. Live GitHub code/PR/review/CI/release/deployment/migration facts for implementation state.
6. External portfolio/control/mirror systems such as Google Sheets or Google Drive.
7. Conversation memory.

## Conflict resolution

- Do not silently rewrite source history when a requirement changes; append the new dated source/change and update normalized specs/changelog.
- If project records conflict with live code/CI/release/deployment state, record the discrepancy and correct the project record using verified evidence.
- If two project folders overlap, choose one canonical project and record the consolidation decision before continuing.

## Engineering fact rule

GitHub `main` is authoritative after protected merge. A commit push alone is not equivalent to accepted/released/deployed state unless the project's Definition of Done explicitly says so and evidence proves it.

External copies may inform work but must not silently override this folder. No task is complete until required project-record updates and objective evidence are present.
