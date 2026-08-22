---
name: fabushi-project-governance
description: Govern every Fabushi repository task through durable, enterprise-standard GitHub project folders and immutable portfolio Project IDs. Use for any implementation, bug fix, refactor, investigation, release, migration, documentation change, AGENTS.md change, Skill creation/update, CI/CD or merge-policy change, architecture/governance change, or follow-up round. Treat `bhrumom/fabushi` GitHub `main`, `projects/PORTFOLIO.json`, and `projects/<project-slug>/` as the authoritative engineering project record. Reuse an existing matching project; create the full standard project folder with the next registered `FAB-Pxxxx` ID before substantial work when none exists; and do not declare completion until WBS, acceptance, status, changelog, evidence, and GitHub facts are synchronized.
---

# Fabushi Project Governance

## Core rule

Treat GitHub as Fabushi's durable engineering project system of record.

- Repository: `bhrumom/fabushi` unless the user explicitly names another repository.
- Authoritative branch: `main` after merge.
- Authoritative project registry: `projects/PORTFOLIO.json`.
- Project identity policy: `projects/PROJECT_ID_POLICY.md`.
- Authoritative project root: `projects/<project-slug>/`.
- Canonical cross-project identity: immutable `project_id: FAB-Pxxxx`.
- Human-readable project namespace: stable `project_key` such as `TFI`, `FPG`, `FCM`, `GBF`, or `MSR`.
- Read repository/root/nested `AGENTS.md` instructions before substantial work.
- For an existing project, read `SOURCE_OF_TRUTH.md` first, then `README.md`, `PROJECT.yaml`, `OWNERS.md`, relevant `source/`, `docs/`, `decisions/`, `management/`, `evidence/`, and `runbooks/` files.
- Use chat, Google Drive, Gmail, Calendar, and local files as intake/reference material unless the project explicitly designates otherwise. They must not silently override the GitHub project folder.
- Verify code, PR, CI, release, and deployment facts against GitHub/live systems rather than documentation claims.

Read `references/project-folder-standard.md` whenever creating, restructuring, auditing, or migrating a project folder. Read `references/task-lifecycle.md` for every execution round.

## No meta-work exemptions

Project governance applies to repository infrastructure itself.

The following are normal governed tasks and must locate/reuse or create a project folder before substantial work:

- root or nested `AGENTS.md` changes;
- Skill creation, update, packaging, installation, or removal;
- CI/CD, workflow, merge queue, automerge, branch protection, or release-policy changes;
- repository-wide architecture/governance standards;
- documentation-system changes;
- build/release tooling changes;
- security/governance automation.

If the objective belongs to an existing governance project, reuse it. Do not create a new project just because the task is about agents or Skills.

## Decide whether to reuse or create

1. Read canonical `projects/PORTFOLIO.json` and search `projects/` on `main` before creating anything.
2. Reuse an existing project folder and its existing `FAB-Pxxxx` Project ID when the request is a continuation, refinement, bug fix, implementation stage, verification round, migration, release step, or governance update for the same objective.
3. Create a new `projects/<project-slug>/` folder only when the user starts a genuinely independent objective/workstream with its own scope and completion criteria.
4. For a genuinely new project, allocate exactly the registry's current `next_sequence` as `FAB-P%04d`; in the same change append the registry entry, increment `next_sequence`, and create `PROJECT.yaml` with the same `project_id` and a stable `project_key`.
5. Never edit, swap, compact, recycle, or reassign an allocated Project ID. Rename/archive/cancel/split/merge changes lifecycle metadata, not historical identity.
6. Preserve historical identifiers in `legacy_project_ids`; never assign a legacy alias to a different project.
7. If concurrent project creation causes a `PORTFOLIO.json` merge conflict, re-read canonical `main` and reallocate the later project from the new high-water mark. Do not force or reuse the losing sequence.
8. Do not create duplicate folders because a conversation, branch, PR, or agent session is new.
9. If two folders overlap materially, select one canonical folder and record the consolidation decision; keep all allocated Project IDs registered for historical traceability.

## Enterprise project-folder gate

When a new project is needed, allocate its portfolio Project ID first and create the mandatory scaffold in `references/project-folder-standard.md` before substantial implementation.

The standard includes:

- `README.md`, `PROJECT.yaml`, `SOURCE_OF_TRUTH.md`, `OWNERS.md`;
- original-source intake under `source/`;
- charter, scope/non-goals, requirements/success metrics, architecture/implementation, quality/test strategy, release/migration/rollback, observability/SLO, security/privacy/compliance, and Definition of Done under `docs/`;
- roadmap, WBS, milestones, acceptance traceability, risk register, status report, dependency/blocker register, changelog, issues/actions, and per-task records under `management/`;
- ADRs under `decisions/`;
- acceptance evidence under `evidence/`;
- operational procedures under `runbooks/`.

Do not leave mandatory standard files blank. If a document is not applicable, keep it and record `N/A`, reason, owner, and revisit trigger.

## Start every task from GitHub

Before implementation:

1. Read canonical `main` `projects/PORTFOLIO.json`, resolve the project's immutable `project_id` and `project_key`, then read the current project folder and reconstruct scope/state.
2. Read current requirements, WBS, milestones, acceptance matrix, risks, dependencies, status report, changelog, open issues/actions, and relevant ADRs.
3. Inspect current code/branches/PRs/CI/releases/deployments needed for the task.
4. Assign or reuse a stable Task ID within the project's `project_key` namespace when applicable.
5. Create/update `management/tasks/<task-id>-<slug>.md` with source requirements, scope, dependencies, acceptance checks, planned evidence, branch/PR, status, risks, and next action.
6. Record newly discovered requirements in `source/` and/or the normalized specification before or alongside implementation.

Do not rely on remembered requirements or remembered `next_sequence` values when GitHub `main` can resolve them.

## Execute with documentation in the same change stream

- Prefer one task branch/PR containing implementation and project-record updates.
- Avoid a second documentation-only PR when the active task PR can carry the records.
- Keep project documentation factual: planned work is not completed work.
- Use stable requirement/task/milestone/risk/ADR identifiers.
- Never mutate the project's registered `project_id`; validate project metadata changes against the base-branch registry.
- Record durable architecture, protocol, security, data, deployment, CI/CD, governance, or vendor decisions as ADRs.
- Record scope/requirement/design changes in source/spec plus `management/07-变更日志.md`.
- Track dependencies/blockers in `management/06-依赖与阻塞.md` and open questions/actions in `management/08-问题与行动项.md`.
- Store durable evidence or indexes under `evidence/<task-id>/`; link large build artifacts, workflow runs, releases, PRs, commits, or deployment checks instead of copying binaries.
- Update runbooks when a task changes repeatable operational procedures.
- CI classification note: repository-governance files under `.agent/skills/**` are governance/docs-safe inputs; runtime plugin code under `.agents/plugins/**` remains an MCP product-domain input and unknown non-document paths must continue to fail safe.

## Completion gate

Do not tell the user a task is finished until implementation, verification, evidence, protected merge state, and project records agree.

Before completion:

1. Run or inspect the defined objective acceptance checks, including `Project portfolio governance` when project identity/registry metadata is affected.
2. Update `management/tasks/<task-id>-<slug>.md` with actual result/evidence.
3. Update `management/01-WBS原子任务.md` for affected task states.
4. Update `management/02-里程碑.md` when a milestone gate changes.
5. Update `management/03-验收追踪矩阵.md` when requirement/acceptance status changes.
6. Append the round/result to `management/05-状态报告.md`.
7. Append material changes to `management/07-变更日志.md`.
8. Update risks, dependencies/blockers, issues/actions, roadmap, specs, ADRs, security docs, release/rollback docs, SLOs, or runbooks when affected.
9. Record branch, commit SHA, PR number, CI/run/test/release/deployment evidence where applicable.
10. Commit project-record changes in the same task change stream when possible.
11. Merge through the repository's required protected-main process.
12. Verify the canonical result on GitHub `main` after merge, including registry/project metadata parity when identity changed.

If CI, review, merge queue, release, deployment, migration, or another required acceptance gate is pending, keep the task `in-progress`, `blocked`, or `failed`; do not mark it complete.

A code push alone is not completion. A passing test without required project records is not completion. A project record claiming completion without live evidence is not completion.

## Source-of-truth precedence

Use this precedence unless the project documents a stricter rule:

1. User's latest explicit requirement, once persisted into the GitHub project folder.
2. For portfolio identity/allocation: canonical `projects/PORTFOLIO.json` and `projects/PROJECT_ID_POLICY.md` on `main`.
3. `projects/<slug>/SOURCE_OF_TRUTH.md` and designated source files.
4. Accepted ADRs and current normalized project specs.
5. Current management/WBS/milestone/acceptance/status records.
6. GitHub code/PR/CI/release/deployment facts for implementation state.
7. External mirrors/control views such as Google Drive/Sheets.
8. Conversation memory.

If documentation conflicts with actual implementation evidence, do not rewrite history silently. Record the discrepancy and correct project state with verified evidence. If project identity fields conflict, stop and reconcile them with the canonical portfolio registry rather than inventing a replacement ID.

## Task Orchestration alignment

When Task Orchestration is available, use the same immutable `FAB-Pxxxx` Project ID, Project Key, Stage ID, Task ID, requirement IDs, acceptance criteria, and evidence links across the repository project folder and external control view.

For Fabushi engineering work:

- GitHub `projects/PORTFOLIO.json` + `projects/<slug>/` are the authoritative durable portfolio/project specification and execution record.
- Google Sheets may be used as portfolio/control-plane view, not as a replacement for repository specifications or live engineering evidence.
- Gmail/Drive/Calendar remain intake, external specification, scheduling, or reporting systems as appropriate.

## Final response requirements

For engineering work governed by this skill, report:

- immutable portfolio Project ID and project folder path;
- Project Key / task ID;
- implementation result;
- acceptance/test result;
- commit/PR/CI/release/deployment evidence;
- project documentation files updated;
- remaining blocker or next action.

Never claim project records, Skill updates, CI changes, Project ID allocation, or canonical main state were updated unless the corresponding write/merge/verification actually succeeded.