# Task lifecycle

## 1. Intake

- Classify the request as continuation vs new independent workstream.
- Search GitHub `projects/` before creating a folder.
- Resolve the canonical project path.

## 2. Reconstruct current state

Read from `main`:

1. `SOURCE_OF_TRUTH.md`
2. `README.md` and `PROJECT.yaml`
3. relevant `source/` and `docs/`
4. relevant ADRs
5. `management/01-WBS原子任务.md`
6. `management/03-验收追踪矩阵.md`
7. `management/05-状态报告.md`
8. `management/07-变更日志.md`
9. current task record, if any

Then verify current GitHub code, open PRs, CI, releases, or deployments that materially affect the task.

## 3. Open/update the task record

Create or update `management/tasks/<task-id>-<slug>.md` before substantial work. Keep planned and completed states separate.

## 4. Implement

- Use a task branch/PR when appropriate.
- Keep code and project-record updates together.
- If requirements change during work, update the durable spec and changelog, not just chat.
- Record architecture decisions as ADRs.

## 5. Verify

Run the objective checks stated in the task/WBS. Capture:

- command/check;
- expected result;
- actual result;
- commit SHA;
- PR;
- CI run/job;
- release/deployment evidence if relevant.

A failed or missing required check blocks `passed` status.

## 6. Close the task record

Before saying “done”:

- update task record;
- update WBS;
- update acceptance matrix if applicable;
- append status report;
- append changelog;
- update risk/roadmap/ADR if affected;
- add evidence index when useful;
- ensure these changes are committed in GitHub.

## 7. Merge and canonical verification

Prefer the same PR for implementation and record updates. After merge, verify the expected files on `main`.

If the implementation is ready but merge/CI/release is still pending, use `in-progress`, `blocked`, or `failed`; do not mark complete.

## 8. Next task

For a continuation, begin from the same project folder and prior task history. For a genuinely different objective, create a new standardized project folder before implementation.
