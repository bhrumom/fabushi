# Task lifecycle

## 1. Intake and project routing

- Read the user's originating source first.
- Read root/nested `AGENTS.md` instructions before substantial repository work.
- Read canonical GitHub `main` `projects/PORTFOLIO.json` and search `projects/` before creating a folder.
- Classify the request as continuation vs genuinely independent workstream.
- Resolve the canonical project path, immutable `FAB-Pxxxx` Project ID, and Project Key.
- Treat AGENTS.md, Skill, CI/CD, repository-governance, architecture-standard, documentation-system, release-tooling, and security-governance work exactly like product work for project routing.

## 2. Create or audit the project folder

If no matching project exists, allocate a global Project ID and create the enterprise scaffold in `project-folder-standard.md` before substantial implementation.

For a new independent project, the allocation is atomic:

1. Re-read `projects/PORTFOLIO.json` from canonical `main`; never use a remembered/stale `next_sequence`.
2. Allocate exactly the current `next_sequence` as `FAB-P%04d`.
3. Choose a stable uppercase mnemonic `project_key` for project-internal requirement/task namespaces.
4. In the same branch/PR, append the registry entry, increment `next_sequence`, and create matching `projects/<slug>/PROJECT.yaml`.
5. Run the portfolio validator and preserve the new ID after allocation.
6. If a concurrent project consumes the same sequence first, re-read `main`, resolve the registry conflict, and move the later project to the new next sequence before merge.
7. Never reuse an ID from an archived, cancelled, renamed, split, merged, superseded, or otherwise historical project. Preserve legacy IDs as aliases.

If a project exists, reuse its registered Project ID and audit whether it has the current mandatory standard files. Add missing standard files as part of the active governance/project task; do not fork a second project solely to migrate the folder standard.

Required standard areas include ownership, source, charter/scope/requirements, architecture, quality, release/rollback, SLO/operations, security, DoD, roadmap, WBS, milestones, acceptance, risks, dependencies, status, changelog, issues/actions, ADRs, evidence, runbooks, and per-task records.

Use `N/A` with reason/owner/revisit trigger when a standard document genuinely does not apply.

## 3. Reconstruct current state

Read from `main`:

1. `projects/PORTFOLIO.json` and resolve the project's registered `project_id`/`project_key`;
2. `SOURCE_OF_TRUTH.md`;
3. `README.md`, `PROJECT.yaml`, `OWNERS.md`;
4. relevant `source/` and `docs/`;
5. relevant ADRs;
6. `management/00-路线图.md`;
7. `management/01-WBS原子任务.md`;
8. `management/02-里程碑.md`;
9. `management/03-验收追踪矩阵.md`;
10. `management/04-风险登记.md`;
11. `management/05-状态报告.md`;
12. `management/06-依赖与阻塞.md`;
13. `management/07-变更日志.md`;
14. `management/08-问题与行动项.md`;
15. current task record and evidence index, if any;
16. relevant runbooks.

Then verify live GitHub code, open PRs, CI, releases, or deployments that materially affect the task. If project identity fields disagree with the canonical portfolio registry, stop and reconcile the inconsistency before implementation.

## 4. Open/update the task record

Create or update `management/tasks/<task-id>-<slug>.md` before substantial work.

Record the immutable portfolio Project ID and Project Key in addition to the stable Task ID. Keep planned and completed states separate. Include stable requirement IDs, dependencies, acceptance criteria, verification, branch/PR, evidence plan, risks, blockers, timestamps, and next action.

## 5. Implement

- Use a task branch/PR when appropriate.
- Keep implementation and project-record updates together.
- Do not mutate an already-registered Project ID or reassign a Project Key/legacy alias to another project.
- If requirements change during work, update source/spec and changelog, not just chat.
- Record durable decisions as ADRs.
- Update dependency/risk/action registers when new facts emerge.
- Update release/rollback, security, SLO/observability, and runbooks when the implementation changes operational behavior.

## 6. Verify

Run the objective checks stated in the task/WBS/DoD. If project identity, the project registry, project metadata, AGENTS/governance controls, or project creation behavior changed, the `Project portfolio governance` workflow (or its successor) is required.

Capture:

- check/test name;
- expected result;
- actual result;
- commit SHA;
- PR/review;
- CI run/job/check;
- portfolio-validator result when applicable;
- security/performance evidence when required;
- release/deployment/migration evidence when relevant.

A failed or missing required check blocks `passed` status.

## 7. Close project records

Before saying “done”:

- update task record;
- update WBS;
- update milestone state when affected;
- update acceptance traceability;
- append status report;
- append changelog;
- update risks, dependencies, issues/actions, roadmap, specs, ADRs, security, release/rollback, SLOs, or runbooks when affected;
- add evidence index when useful;
- ensure these changes are committed in GitHub.

## 8. Merge and canonical verification

Prefer the same PR for implementation and record updates. Use the repository's protected branch/required checks/merge queue policy. After merge, verify expected project and implementation files on `main`.

For project-ID/registry changes, explicitly re-read canonical `projects/PORTFOLIO.json` and affected `PROJECT.yaml` files and verify the registry high-water mark after merge.

If implementation is ready but review/CI/merge/release/deployment/migration is still pending, use `in-progress`, `blocked`, or `failed`; do not mark complete.

## 9. Synchronize external control views

When Task Orchestration/Google Sheets/Drive/Calendar/Gmail are used:

- preserve the same immutable `FAB-Pxxxx` Project ID, Project Key, Stage ID, Task ID, and Requirement IDs;
- keep GitHub portfolio/project engineering specifications/evidence authoritative for Fabushi repository work;
- synchronize verified state into the external portfolio/control view;
- use Drive/Gmail as source/intake or mirror, Calendar as schedule, not as silent overrides of GitHub project state.

## 10. Next task

For a continuation, begin from the same registered Project ID/project folder and prior task history. For a genuinely different objective, re-read canonical `projects/PORTFOLIO.json`, allocate the current next Project ID atomically, and create a new enterprise-standard project folder before substantial implementation.