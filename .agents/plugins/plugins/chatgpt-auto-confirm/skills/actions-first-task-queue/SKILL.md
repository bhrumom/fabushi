---
name: actions-first-task-queue
description: "Run long-lived coding, release, deployment, or plugin-marketplace tasks through the Chat task queue. Build and test where the queue is running: local queues use the local checkout and local toolchain; GitHub Actions queues build and test only inside Actions. Use when work must recover from blockers, wait for external jobs, or continue automatically in a new Chat."
---

# Continuous Task Queue

Use `chatgpt-auto-confirm` as the controller. Work only in queue-owned **Chat** conversations, never Work. An unchanged task continues from its previous Chat branch; an updated goal always starts a new Chat and a new project-email thread.

## What every round must do

Before the first, continuation, or review message is sent, select and verify GPT-5.6 Sol with Extra High reasoning. Repeat the GitHub repository, repository-relative task-document directory, and repository-relative code directory in every message, and require use of the GitHub connector to read and modify that repository. A round may not end after only reading, inspecting, planning, emailing, or summarizing. Unless it is waiting for an already-started external operation or a genuine human blocker, it must make a verifiable code change and run the relevant test before ending.

At the start of every round:

1. Re-read this skill and every current file in the task directory. Files may have changed since the previous Chat.
2. Read `.mahayana-project-email.json`, then use the Gmail connector to read the recorded project thread. Apply any new requirements sent by `1315518325@qq.com`; persist material goal changes into the task definition so later rounds retain them.
3. Inspect the existing checkout, changes already on disk, branch state, and any operation still running.
4. Continue the remaining implementation. Do not restart, merely review results, rewrite plans, or stop after saying what should happen next.
5. Keep working until all task files, acceptance checks, tests, releases, and required evidence are complete.

The first Chat must receive the complete current goal, the task directory/file location, revision/digest, this skill path, and the project-initiation requirement. A continuation instruction is forbidden until that first Chat has actually established the task context. From the second unfinished round onward, the controller sends only a short instruction to continue; branch history supplies prior context.

The miniapp, not Chat, detects task updates. Before every dispatch it reads `tasks/actions-inbox.json` and all declared `specSources`, then compares the current prompt and SHA-256 digest with the applied round. Chat reads files to do the work, but it never decides whether a revision changed.

## Build and test where the controller runs

- When the queue controller and target checkout are running locally, run the required tests, builds, packaging, install checks, and runtime replacement locally. Do not send a local build to GitHub Actions merely because a workflow exists.
- When the queue controller is running inside GitHub Actions, keep project tests, builds, packaging, install checks, artifacts, and deployment verification inside that Actions run. Do not move them onto a user's machine.
- Use GitHub Actions as the source of truth for releases, deployments, protected-branch checks, cloud credentials, or acceptance evidence that inherently belongs to GitHub, regardless of where the controller runs.
- Detect execution location from the actual runtime (`GITHUB_ACTIONS=true` for Actions), not from the task's repository hosting or connector name.
- Add or repair workflow configuration only when cloud validation is genuinely required or the controller is already running in Actions.

## Route connectors and recover connectivity

- Use the GitHub connector for all cloud repository, pull-request, Actions, artifact, release, and merge evidence after code has reached GitHub.
- Use bhrum2 for the local checkout. Before synchronizing it, inspect the worktree, remote, and branch; fetch first and fast-forward only a clean checkout. Never overwrite local changes to force synchronization.
- If a local bhrum2 step pushes code, return `next_connector: "GitHub"` so the next fresh Chat checks cloud state through the GitHub connector. Return `next_connector: "bhrum2"` only when the next step genuinely needs local checkout work.
- Treat DNS failures, disconnects, connection resets, 429/502/503/504, and connector timeouts as recoverable. Do not loop the same request. Use the one-line wait directive; the queue probes connectivity and starts a fresh Chat when it is available.

## Keep commits small and intentional

Before staging, inspect the changed-file list. Stage named source files, workflow files, configuration, and required documentation only.

Never use blanket staging. Exclude caches, dependency folders, generated build output, local installers, unrelated media, and unrelated LFS objects. Do not wait for a large upload unless the asset is explicitly required by the release goal. Preserve user files rather than deleting them to make a commit clean.

## Completion, waiting, and blockers

Do not repeat the same failed command or connector path. Diagnose the cause first, then try an appropriate alternative such as local `gh`/`git`, a different authenticated connector, a corrected environment path, or a workflow change.

Do not stop merely because an operation is slow. Poll Actions, deployments, releases, and remote checks inside the same Chat whenever possible. Do not stop while useful work can continue.

Whenever a Chat must end, use the single report envelope below for complete, incomplete, blocked, and cross-Chat waiting states (plain text, not a Markdown code block). `completed` records finished items and never means the whole task is complete. The queue stops only when `status=complete` and `all_tasks_complete=true`, with `remaining=[]`, `blockers=[]`, `wait_seconds=0`, and `next_task=""`.

```text
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","task_id":"current task id","applied_task_revision":1,"applied_spec_digest":"current spec digest","status":"incomplete","all_tasks_complete":false,"summary":"...","completed":["finished item"],"remaining":["unfinished item"],"blockers":[],"verification":["..."],"wait_seconds":0,"wait_reason":"","next_connector":"","next_task":"specific work for the next round"}
MAHAYANA_TASK_REPORT_V1_END
```

When everything is genuinely complete, use the same envelope with `status=complete`, `all_tasks_complete=true`, empty `remaining`/`blockers`/`next_task`, and zero wait. For an external result that genuinely requires a long cross-Chat wait, use the same envelope with `all_tasks_complete=false`, a realistic `wait_seconds`, `wait_reason`, and non-empty `next_task`. The queue will re-read updated files and continue afterward. For human intervention, first send the exact requirement through the task's Gmail thread, then return the same envelope with `status=blocked` and `all_tasks_complete=false`.

## Project email thread

Every task directory contains `.mahayana-project-email.json`. The recipient is `1315518325@qq.com`.

- At task start, read the record. If it has no Gmail thread ID, use the Gmail connector to send one project-initiation email with subject `[立项][task-id] task title`, then write the returned thread/message identity and timestamp into the record.
- When the miniapp detects an updated goal/specification, the old Chat and old email thread belong to the superseded revision. The new first Chat must create `[立项][task-id][vN] task title` and overwrite the record with the new thread identity.
- At the start of every first, continuation, and review Chat, use Gmail to read the recorded thread and check for new requirements from `1315518325@qq.com` before implementation or validation.
- Do not send an email merely because a Chat round ended. Reply only after substantive, verifiable progress such as implemented code, a meaningful test/build/deployment milestone, a commit/PR/release, or full task completion; also reply whenever human-only information, permission, credentials, or a decision is required.
- A read-only round, repeated status check, plan, summary, failed no-op attempt, or unchanged wait is not substantive progress and must not generate an email. Avoid duplicate progress emails for the same evidence.
- When a qualifying reply is sent, include actual changed files/commits, validation evidence, current state, and the next awaited result if any. Update the record's last-round/progress fields.
- If human action is required, reply to the same thread with `[需人工介入]`, the exact permission/account/input needed, and how work resumes afterward.
- Never create a second project thread within the same unchanged revision.

## Recover safely

Treat a Chat that shows no assistant or tool activity shortly after a verified send as a renderer failure, not as a long-running build. Restart only the queue-owned hidden ChatGPT process and continue from the persisted checkout in a new Chat.

Treat visible GitHub Actions or deployment progress as active work. Do not declare completion merely because a Chat stopped. A fast unfinished reply is backed off before another branch is sent so the queue cannot spin or trigger rate limits.

## Miniapp-owned task update detection

The task id is stable and the task definition is versioned state. Define `revision`, `specSources`, and an optional `directive` in `tasks/actions-inbox.json`. Before each round, the miniapp reads the inbox and referenced files itself and computes a SHA-256 specification digest.

- Increment `revision` whenever possible. If file content or the goal changes without a revision bump, the miniapp still creates an internal next revision from the changed digest.
- Use `applyMode: "next_chat"` by default; the current Chat may finish its turn, but its result cannot complete the task after a newer revision exists.
- Use `applyMode: "interrupt"` only for urgent safety or architecture corrections. The queue stops only its hidden task-owned response, preserves the checkout, and immediately creates a fresh Chat on the new revision.
- Current prompts, directives, specification digests, sources, and the last 100 updates are versioned in queue state.
- An unchanged second-or-later round stays on its branch and receives only the short continuation instruction.
- A changed prompt or digest clears the old branch identity. The next Chat is a true first round containing the complete updated goal and task directory, and it creates a new project-email thread.
- Reports based on an older revision or digest are automatically superseded and cannot complete the updated task.
- Do not cancel and recreate the long-running workflow merely to update task requirements.
