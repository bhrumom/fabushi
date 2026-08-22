# Source of Truth

The canonical project record is `bhrumom/fabushi` `main` under `projects/fabushi-project-governance/`.

The canonical repository-wide project identity registry is `projects/PORTFOLIO.json`; its lifecycle/allocation policy is `projects/PROJECT_ID_POLICY.md`. This governance project is registered as `FAB-P0002` with Project Key `FPG`.

## Designated requirement sources

- `source/README.md` — original repository-wide project-first governance requirement.
- `source/2026-08-22-FPG-002-enterprise-project-standard.md` — requirement to align Task Orchestration, root `AGENTS.md`, repository Skills, and project folders with an enterprise-standard project-document model.
- `source/2026-08-22-FPG-004-global-project-identifiers.md` — requirement to establish immutable numbering between Fabushi projects.

## Precedence

1. Latest explicit user requirement after being persisted into this project folder.
2. For cross-project identity/allocation: canonical `projects/PORTFOLIO.json` and `projects/PROJECT_ID_POLICY.md` on `main`.
3. This file and designated source files.
4. Accepted ADRs and current normalized specs under `docs/`.
5. Current roadmap, WBS, milestones, acceptance, risks, dependencies, status, changelog, issues/actions, and task records.
6. Live GitHub code/PR/review/CI/release/deployment/migration facts for implementation state.
7. External portfolio/control/mirror systems such as Google Sheets or Google Drive.
8. Conversation memory.

## Conflict resolution

- Do not silently rewrite source history when a requirement changes; append the new dated source/change and update normalized specs/changelog.
- If project records conflict with live code/CI/release/deployment state, record the discrepancy and correct the project record using verified evidence.
- If a `PROJECT.yaml` identity conflicts with `projects/PORTFOLIO.json`, stop and reconcile to the canonical registry. Never mint a replacement ID from memory.
- If two project folders overlap, choose one canonical project and record the consolidation decision before continuing; already allocated portfolio IDs remain registered for historical traceability and are never reused.

## Engineering fact rule

GitHub `main` is authoritative after protected merge. A commit push alone is not equivalent to accepted/released/deployed state unless the project's Definition of Done explicitly says so and evidence proves it.

Project IDs become canonical only after their registry/project metadata change is merged and verified on `main`. External copies may inform work but must not silently override the portfolio registry or project folder. No task is complete until required project-record updates and objective evidence are present.