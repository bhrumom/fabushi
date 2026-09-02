---
name: in-app-browser-task-queue
description: "Use the plugin-owned in-app Browser queue for one complete goal, recover a disconnected Browser host, and keep dispatching fresh Chat conversations until a verified completion certificate is received."
---

# Plugin-owned in-app Browser queue

Use `dispatch_goal` as the only outbound entry point for a long-running goal. The caller supplies one complete goal; ChatGPT may decompose it internally, but it must keep implementing, testing, and verifying every part until the whole goal is complete. Do not send a plan, milestone, partial result, or historical progress as a substitute for the goal.

The plugin owns the task state and completion decision. Every Chat dispatch is restricted to the in-app Browser Chat surface, GPT-5.6 Sol, Extra High reasoning, a fresh Chat, and one concise all-in-one prompt containing only the original goal. The plugin appends a fixed completion-certificate instruction to that prompt; callers must not carry historical progress or write their own continuation message. Never use Devspace, Work mode, a generic CDP endpoint, or a manually typed continuation message for this queue.

## Start or recover

1. Call `browser_watch` to start or resume the plugin's persistent supervisor from the local task state.
2. Call `browser_capability_status` and `browser_job_status` when a job id is available. Treat `waiting_for_browser_host`, `reattaching_browser_host`, and `reattachRequired=true` as recoverable, not complete.
3. A stale tab binding is repaired inside the plugin host: it first rebinds an exact controlled conversation, then claims an exact released user tab, and only then opens a new background tab at the saved URL. It keeps the same job id and never dispatches the goal again during reattachment.
4. If `browser_watch` returns `reattachRequired=true`, use only the authorized in-app Browser and the returned `reattach.modulePath`, `reattach.factory`, `reattach.startUrl`, and `reattach.runMethod`. Resolve the Browser by its stable `iab` id; do not require an enumerated browser array. If discovery is empty, undefined, or temporarily unavailable during a handoff, retry with backoff and reuse the same Browser binding. Invoke that plugin factory with the existing in-app Browser binding, then **await the returned host's `runUntilTerminal()` method in the same long-running Browser execution**. Do not merely create the host and let that execution end; the awaited host pump is the lease that lets the plugin continue by itself.
5. After the long-running host is attached, the plugin restores the exact saved conversation and automatically approves its authorization cards. Prefer the session-scoped option; when that option is absent, close the scope menu and click the card's direct Allow control. Browser-list failures and lease rotations are recoverable: the host retries discovery, persists the same job, and keeps pumping or reattaches without resending the goal. Rotate to fresh Chat only after an incomplete finished reply, and continue until the same persisted job becomes terminal.

The long-running host bootstrap is the sole permitted recovery exception to plugin-tool-only monitoring. It is plugin-supplied reattachment, not manual page control: do not type messages, click page controls, select another browser, or construct a replacement goal outside the plugin.

## Handoff and completion

While Chat is responding, do not send another message. When a response ends, the plugin independently checks the latest reply. The task ends only when the latest reply contains a valid `MAHAYANA_TASK_REPORT_V1` completion certificate with `status=complete`, `all_tasks_complete=true`, non-empty completion and verification evidence, empty `remaining` and `blockers`, `wait_seconds=0`, and an empty `next_task`. Natural-language claims without a valid certificate are not completion. If the reply is incomplete, vague, blocked, malformed, missing the certificate, or ends early, the plugin increments the attempt, opens a fresh Chat, and sends only the original complete goal again. It never carries the previous response into the next prompt.

The queue stops only after the plugin's completion detector confirms the whole goal is complete and verified, or the user explicitly stops it. A host disconnect, plugin restart, incomplete response, authorization card, Browser/CDP/UI automation error, transient Browser error, or partial implementation must leave the task recoverable and must not be treated as completion.
