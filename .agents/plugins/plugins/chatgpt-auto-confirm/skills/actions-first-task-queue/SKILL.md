---
name: actions-first-task-queue
description: Run long-lived coding, GitHub release, deployment, or plugin-marketplace tasks through the Chat task queue with GitHub Actions as the only place for project tests, builds, packaging, installation, and artifact validation. Use when a task must avoid local resource use, skip unrelated large files, recover from repeated blockers, wait for external jobs, or continue automatically in a new Chat.
---

# Actions-First Task Queue

Use the `chatgpt-auto-confirm` queue as the controller. Send work and independent acceptance to fresh **Chat** conversations only; do not use a Work/worker page as a fallback. One queue-owned ChatGPT process creates an isolated hidden Chat for each running task. Tasks without dependency or resource-lock conflicts may run concurrently; page actions remain isolated inside their owning hidden Chat.

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

Every work and acceptance Chat must end with the machine report. A completed work Chat returns `status=complete` and then a separate acceptance Chat verifies it; the acceptance Chat also returns a same-revision `status=complete` report before the queue marks the task terminal. Do not rely on a natural-language completion or a standalone acceptance marker.

```text
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","task_id":"current task id","applied_task_revision":1,"applied_spec_digest":"current spec digest","status":"complete|incomplete|blocked","summary":"...","completed":["..."],"remaining":[],"blockers":[],"verification":["..."],"wait_seconds":0,"wait_reason":"","next_connector":"GitHub|bhrum2|","next_task":""}
MAHAYANA_TASK_REPORT_V1_END
```

- For completed work, output the complete machine report; the queue then sends the result to a separate acceptance Chat.
- For unfinished work, use `incomplete` or `blocked`, keep `wait_seconds` as `0`, and provide a concrete `next_task` for the next Chat.
- Normal Actions/deployment/network polling is not a reason to end the Chat.
- For a real unsolved blocker, state exactly what is needed: permission, account, tool, environment variable, command, or external service recovery condition.

## Recover safely

Treat a Chat that shows no assistant or tool activity shortly after a verified send as a renderer failure, not as a long-running build. Restart only the queue-owned hidden ChatGPT process and continue from the persisted checkout in a new Chat.

Treat visible GitHub Actions or deployment progress as active work. Do not declare completion merely because a Chat stopped; require the structured report and independently verify the Actions evidence in a separate Chat acceptance pass.

## Update a running task without restarting the Action

The persistent Actions controller treats the task id as stable and the task definition as versioned state. Define `revision`, `specSources`, and an optional `directive` in `tasks/actions-inbox.json`. While the runner is active, it polls the current Git branch for the latest inbox and referenced specification files, computes a SHA-256 specification digest, and applies newer revisions with `queue_update`.

- Increment `revision` whenever the prompt, acceptance criteria, or a referenced specification changes.
- Use `applyMode: "next_chat"` by default; the current Chat may finish its turn, but its result cannot complete the task after a newer revision exists.
- Use `applyMode: "interrupt"` only for urgent safety or architecture corrections. The queue stops only its hidden task-owned response, preserves the checkout, and immediately creates a fresh Chat on the new revision.
- The original task goal is immutable. Current prompts, directives, specification digests, sources, and the last 100 updates are versioned in queue state.
- Every new work Chat and independent review receives the latest specification snapshot and digest.
- Reports based on an older revision or digest are automatically superseded and continued in a fresh Chat.
- Do not cancel and recreate the long-running workflow merely to update task requirements.
