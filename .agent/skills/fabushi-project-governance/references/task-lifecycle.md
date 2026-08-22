# Task lifecycle

## 1. Intake and project routing

- Read the user's originating source first.
- Read root/nested `AGENTS.md` instructions before substantial repository work.
- Search GitHub `projects/` before creating a folder.
- Classify the request as continuation vs genuinely independent workstream.
- Resolve the canonical project path.
- Treat AGENTS.md, Skill, CI/CD, repository-governance, architecture-standard, documentation-system, release-tooling, and security-governance work exactly like product work for project routing.

## 2. Create or audit the project folder

If no matching project exists, create the enterprise scaffold in `project-folder-standard.md` before substantial implementation.

If a project exists, audit whether it has the current mandatory standard files. Add missing standard files as part of the active governance/project task; do not fork a second project solely to migrate the folder standard.

Required standard areas include ownership, source, charter/scope/requirements, architecture, quality, release/rollback, SLO/operations, security, DoD, roadmap, WBS, milestones, acceptance, risks, dependencies, status, changelog, issues/actions, ADRs, evidence, runbooks, and per-task records.

Use `N/A` with reason/owner/revisit trigger when a standard document genuinely does not apply.

## 3. Reconstruct current state

Read from `main`:

1. `SOURCE_OF_TRUTH.md`;
2. `README.md`, `PROJECT.yaml`, `OWNERS.md`;
3. relevant `source/` and `docs/`;
4. relevant ADRs;
5. `management/00-路线图.md`;
6. `management/01-WBS原子任务.md`;
7. `management/02-里程碑.md`;
8. `management/03-验收追踪矩阵.md`;
9. `management/04-风险登记.md`;
10. `management/05-状态报告.md`;
11. `management/06-依赖与阻塞.md`;
12. `management/07-变更日志.md`;
13. `management/08-问题与行动项.md`;
14. current task record and evidence index, if any;
15. relevant runbooks.

Then verify live GitHub code, open PRs, CI, releases, or deployments that materially affect the task.

## 4. Open/update the task record

Create or update `management/tasks/<task-id>-<slug>.md` before substantial work.

Keep planned and completed states separate. Include stable requirement IDs, dependencies, acceptance criteria, verification, branch/PR, evidence plan, risks, blockers, timestamps, and next action.

## 5. Implement

- Use a task branch/PR when appropriate.
- Keep implementation and project-record updates together.
- If requirements change during work, update source/spec and changelog, not just chat.
- Record durable decisions as ADRs.
- Update dependency/risk/action registers when new facts emerge.
- Update release/rollback, security, SLO/observability, and runbooks when the implementation changes operational behavior.

## 6. Verify

Run the objective checks stated in the task/WBS/DoD. Capture:

- check/test name;
- expected result;
- actual result;
- commit SHA;
- PR/review;
- CI run/job/check;
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

If implementation is ready but review/CI/merge/release/deployment/migration is still pending, use `in-progress`, `blocked`, or `failed`; do not mark complete.

## 9. Synchronize external control views

When Task Orchestration/Google Sheets/Drive/Calendar/Gmail are used:

- preserve the same Project/Stage/Task/Requirement IDs;
- keep GitHub engineering specifications/evidence authoritative for Fabushi repository work;
- synchronize verified state into the external portfolio/control view;
- use Drive/Gmail as source/intake or mirror, Calendar as schedule, not as silent overrides of GitHub project state.

## 10. Next task

For a continuation, begin from the same project folder and prior task history. For a genuinely different objective, create a new enterprise-standard project folder before substantial implementation.
