---
name: actions-first-task-queue
description: Run long-lived coding, GitHub release, deployment, or plugin-marketplace tasks through the Chat task queue with GitHub Actions as the only place for project tests, builds, packaging, installation, and artifact validation. Use when a task must avoid local resource use, skip unrelated large files, recover from repeated blockers, wait for external jobs, or continue automatically in a new Chat.
---

# Actions-First Task Queue

Use the `chatgpt-auto-confirm` queue as the controller. Send work and independent acceptance to fresh **Chat** conversations only; do not use a Work/worker page as a fallback. One queue-owned ChatGPT process serializes page actions while the durable queue holds all pending work.

## Run work remotely

- Make GitHub Actions the source of truth for every project test, build, package, install check, release artifact, and deployment verification.
- Do not run project test/build/package/install commands, dependency downloads, or artifact-producing commands locally. Local work is limited to reading code plus Git and `gh` metadata needed to prepare or inspect the remote run.
- Add or repair workflow configuration when the required remote validation does not exist, then push and inspect the resulting Action run, logs, checks, and artifacts.

## Keep commits small and intentional

Before staging, inspect the changed-file list. Stage named source files, workflow files, configuration, and required documentation only.

Never use blanket staging. Exclude caches, dependency folders, generated build output, local installers, unrelated media, and unrelated LFS objects. Do not wait for a large upload unless the asset is explicitly required by the release goal. Preserve user files rather than deleting them to make a commit clean.

## Handle blockers and waiting

Do not repeat the same failed command or connector path. Diagnose the cause first, then try an appropriate alternative such as local `gh`/`git`, a different authenticated connector, a corrected environment path, or a workflow change.

If the next step depends on an external asynchronous result, end the Chat response instead of leaving it idle. Return an `incomplete` report containing a realistic wait estimate. The queue records the delay, releases the Chat renderer, and creates a new Chat after the time has elapsed to run `next_task` and check the result.

Use this report contract at the end of every task or acceptance response:

```text
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","status":"complete|incomplete|blocked","summary":"...","completed":["..."],"remaining":["..."],"blockers":["..."],"verification":["..."],"wait_seconds":0,"wait_reason":"","next_task":"..."}
MAHAYANA_TASK_REPORT_V1_END
```

- For `complete`, set `remaining`, `blockers`, and `next_task` to empty values and use `wait_seconds: 0` with an empty `wait_reason`.
- For unfinished work without an external wait, use `wait_seconds: 0` and give a nonempty `next_task`; the queue starts a fresh Chat immediately.
- For an external wait, use `status: "incomplete"`, a 30–604800 second estimate, a nonempty `wait_reason`, and a next task that rechecks the external result.
- For a real unsolved blocker, state exactly what is needed: permission, account, tool, environment variable, command, or external service recovery condition.

## Recover safely

Treat a Chat that shows no assistant or tool activity shortly after a verified send as a renderer failure, not as a long-running build. Restart only the queue-owned hidden ChatGPT process and continue from the persisted checkout in a new Chat.

Treat visible GitHub Actions or deployment progress as active work. Do not declare completion merely because a Chat stopped; require the structured report and independently verify the Actions evidence in a separate Chat acceptance pass.
