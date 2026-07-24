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

## Route connectors and recover connectivity

- Use the GitHub connector for all cloud repository, pull-request, Actions, artifact, release, and merge evidence after code has reached GitHub.
- Use bhrum2 for the local checkout. Before synchronizing it, inspect the worktree, remote, and branch; fetch first and fast-forward only a clean checkout. Never overwrite local changes to force synchronization.
- If a local bhrum2 step pushes code, return `next_connector: "GitHub"` so the next fresh Chat checks cloud state through the GitHub connector. Return `next_connector: "bhrum2"` only when the next step genuinely needs local checkout work.
- Treat DNS failures, disconnects, connection resets, 502/503/504, and connector timeouts as recoverable. Do not loop the same request. End the Chat with an `incomplete` report and a 30-second-or-greater wait; the queue probes connectivity and starts a fresh Chat when it is available.

## Keep commits small and intentional

Before staging, inspect the changed-file list. Stage named source files, workflow files, configuration, and required documentation only.

Never use blanket staging. Exclude caches, dependency folders, generated build output, local installers, unrelated media, and unrelated LFS objects. Do not wait for a large upload unless the asset is explicitly required by the release goal. Preserve user files rather than deleting them to make a commit clean.

## Handle blockers and waiting

Do not repeat the same failed command or connector path. Diagnose the cause first, then try an appropriate alternative such as local `gh`/`git`, a different authenticated connector, a corrected environment path, or a workflow change.

Do not stop a task just because an external operation is slow. Keep the active Chat working and poll normal asynchronous operations (Actions, deployments, releases, network recovery, remote checks) whenever possible. Do not ask the user to wait and do not return a wait countdown for normal waiting. Only emit an unfinished report when the current execution cannot continue due to a real blocker or the platform requires a handoff.

Use the task report only for unfinished handoff cases. A completed task returns a normal final result and then a separate acceptance Chat verifies it. Do not include the machine report in every successful completion.

```text
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","status":"incomplete|blocked","summary":"...","completed":["..."],"remaining":["..."],"blockers":["..."],"verification":["..."],"wait_seconds":0,"wait_reason":"","next_connector":"GitHub|bhrum2|","next_task":"..."}
MAHAYANA_TASK_REPORT_V1_END
```

- For completed work, do not output this machine report; send the result to a separate acceptance Chat.
- For unfinished work, use `incomplete` or `blocked`, keep `wait_seconds` as `0`, and provide a concrete `next_task` for the next Chat.
- Normal Actions/deployment/network polling is not a reason to end the Chat.
- For a real unsolved blocker, state exactly what is needed: permission, account, tool, environment variable, command, or external service recovery condition.

## Recover safely

Treat a Chat that shows no assistant or tool activity shortly after a verified send as a renderer failure, not as a long-running build. Restart only the queue-owned hidden ChatGPT process and continue from the persisted checkout in a new Chat.

Treat visible GitHub Actions or deployment progress as active work. Do not declare completion merely because a Chat stopped; require the structured report and independently verify the Actions evidence in a separate Chat acceptance pass.
