---
name: fabushi-project-governance
description: Govern Fabushi engineering work through durable GitHub project folders. Use for any Fabushi task that starts, continues, finishes, changes scope, creates a new independent workstream, updates a project plan, merges code, verifies CI, or needs a persistent execution record. Treat `bhrumom/fabushi` GitHub `main` and its `projects/project-slug/` folders as the authoritative project documentation source. Reuse an existing project folder for continuations; create a new standardized project folder for a genuinely different task/workstream. Before declaring work complete, update the project status, WBS/acceptance state, changelog, evidence, and GitHub commit/PR references in that folder.
---

# Fabushi Project Governance

## Core rule

Treat GitHub as the durable project system of record.

- Repository: `bhrumom/fabushi` unless the user explicitly names another repository.
- Authoritative branch: `main` after changes are merged.
- Authoritative project root: `projects/<project-slug>/`.
- For an existing project, read `SOURCE_OF_TRUTH.md` first, then `README.md`, `PROJECT.yaml`, relevant `docs/`, `decisions/`, and `management/` files.
- Use chat messages, Google Drive files, emails, and local files as intake/reference material. Do not let them silently override the GitHub project folder.
- Verify code, PR, CI, release, and deployment facts against GitHub rather than documentation claims.

Read `references/project-folder-standard.md` when creating or restructuring a project folder. Read `references/task-lifecycle.md` for every execution round.

## Decide whether to reuse or create

1. Search `projects/` on `main` before creating anything.
2. Reuse an existing project folder when the request is a continuation, refinement, bug fix, implementation stage, verification round, or release step for the same objective.
3. Create a new `projects/<project-slug>/` folder when the user starts a genuinely different objective/workstream with its own scope and completion criteria.
4. Do not create duplicate folders just because the conversation is new.
5. If two folders overlap materially, select one canonical folder and record the consolidation decision before further work.

## Start every task from GitHub

Before implementation:

1. Read the current `main` project folder and reconstruct scope from it.
2. Read current WBS, status, acceptance criteria, changelog, and relevant ADRs.
3. Inspect current code/branches/PRs/CI needed for the task.
4. Assign or reuse a stable task ID.
5. Create/update `management/tasks/<task-id>-<slug>.md` with objective, dependencies, acceptance checks, planned evidence, status, and next action.
6. Record any newly discovered requirement in the appropriate project document before or alongside implementation.

Do not rely on remembered requirements when the GitHub project folder can resolve them.

## Execute with documentation in the same change stream

- Prefer one task branch/PR containing both implementation and its project-record updates.
- Avoid a second documentation-only PR when the active task PR can carry the records.
- Keep project documentation factual: planned work is not completed work.
- Record important architecture changes as ADRs under `decisions/`.
- Record scope changes in source/requirements plus `management/07-变更日志.md`.
- Store durable textual evidence or evidence indexes under `evidence/<task-id>/`; link large build artifacts, workflow runs, releases, PRs, or commits instead of copying binaries into the project folder.

## Completion gate

Do not tell the user that a task is finished until the project folder has been updated for that task.

At minimum, before completion:

1. Run the defined acceptance checks.
2. Update `management/tasks/<task-id>-<slug>.md` with actual result and evidence.
3. Update `management/01-WBS原子任务.md` for affected task states.
4. Update `management/03-验收追踪矩阵.md` when an acceptance item changed.
5. Append the execution result to `management/05-状态报告.md`.
6. Append a dated entry to `management/07-变更日志.md`.
7. Update risk/ADR/roadmap documents if the task changed them.
8. Record branch, commit SHA, PR number, CI/run/release evidence, blockers, and next action where applicable.
9. Commit the record updates to GitHub in the same task change stream.
10. Verify the resulting canonical state on GitHub `main` after merge. If merge is blocked, report the task as pending/blocked rather than complete.

A code push alone is not completion. A passing test without the required project record is not completion.

## New independent task/workstream

When a new request does not belong to an existing project:

1. Create a unique lowercase kebab-case slug.
2. Create `projects/<slug>/` using the minimum scaffold in `references/project-folder-standard.md`.
3. Put the user's original requirement or linked source into `source/` or record a durable source pointer.
4. Create `SOURCE_OF_TRUTH.md` defining precedence.
5. Establish scope, architecture/implementation notes as needed, acceptance criteria, WBS, status, changelog, risks, and task log before substantial implementation.
6. Add the first task record and begin work from that folder.

## Source-of-truth precedence

Use this precedence unless the project explicitly documents a stricter rule:

1. User's latest explicit scope change, once persisted into the GitHub project folder.
2. `projects/<slug>/SOURCE_OF_TRUTH.md` and files it designates.
3. Accepted ADRs and current project specs.
4. Current management/WBS/status records.
5. GitHub code/PR/CI/release facts for implementation state.
6. External mirrors such as Google Drive.
7. Conversation memory.

If documentation conflicts with actual code/CI state, do not rewrite history silently. Record the discrepancy and update the project record with verified evidence.

## Final response requirements

For engineering work governed by this skill, report:

- project folder path;
- task ID;
- implementation result;
- acceptance/test result;
- commit/PR/CI evidence;
- project documentation files updated;
- remaining blocker or next action.

Never claim the project record was updated unless the GitHub write actually succeeded.
