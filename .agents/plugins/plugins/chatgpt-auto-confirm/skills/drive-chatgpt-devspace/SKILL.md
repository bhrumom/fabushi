---
name: drive-chatgpt-devspace
description: Drive a coding task through the actual Chat surface of a hidden second ChatGPT.app instance using the devspace1 connector. Use when an AI must create a fresh Chat for every outbound message, select devspace1, verify the send, auto-confirm authorization cards, stream user-visible thinking/tool progress, recover from a stall in another new Chat, and wait for ChatGPT's final reply before independently validating the repository.
---

# Drive ChatGPT Devspace

Use the `chatgpt-auto-confirm` plugin as the only controller. It operates a hidden second `ChatGPT.app` instance so the user's visible Work task is not switched or clicked.

For long-lived release, deployment, marketplace, or CI work, also apply the bundled `actions-first-task-queue` skill: project tests, builds, packages, installs, and artifacts belong in GitHub Actions, and unrelated large files must not be staged or uploaded.

## Non-negotiable boundaries

- Operate the desktop app's real **Chat** surface. Do not use ChatGPT web, Chrome, the visible Codex/Work composer, macOS coordinate clicks, or a worker task as the message destination.
- Require `backgroundOnly: true`, `workerUsed: false`, `surface: "chat"`, and `chatMode: true` before sending.
- If the hidden Chat surface is unavailable, stop with an error. Never fall back to the visible Work/worker page.
- Re-check the hidden surface throughout polling, before every approval scan or follow-up. If it ever ceases to report `chatMode: true` and `surface: "chat"`, return `chat_surface_drift` immediately with a screenshot and page diagnostics. Never approve, type, or continue on Work.
- Never append an outbound message to an existing conversation. Every actual send, including a stall recovery, must first create a fresh **Chat**. Existing conversations are read-only monitoring targets only.
- Treat returned `thinking` as user-visible reasoning summaries and tool activity, not private model chain-of-thought. Redact credentials before relaying it.
- Once `send_and_watch` starts, only consume its progress and final output. Do not inspect, edit, build, or validate the target repository in parallel.

## Run the workflow

1. Call `chat_status` and enforce the four hidden-Chat fields above. Do not bind an old `conversationId` when a message will be sent.
2. Call `send_and_watch` with:
   - the complete task in `message`;
   - `connector: "devspace1"`;
   - `newChat: true` and no old `conversationId` for every outbound message;
   - `approveAll: true`;
   - `timeout: 7200` unless the user requests another total limit;
   - `stagnationTimeout: 1200` for 20 minutes without new visible progress;
   - `maxRecoveryAttempts: 5`;
   - select GPT-5.6 Sol and High reasoning effort for complex implementation tasks when the model selector is available;
   - `autoContinueIncomplete: true`;
   - `maxTaskContinuations: 0` (continuous report-driven new-Chat continuation; `0` means no fixed cap);
   - `pollIntervalMs: 500`.
3. Require `preparation.newChatClicked: true` before accepting any send.
4. Read `thinking_progress` events as live status. Important fields are `thinking`, `activityCharCount`, `devspaceActivity`, `devspaceWaiting`, and `waitingForApproval`.
5. Keep waiting. Authorization cards are confirmed internally, including repeated cards that appear after edits, shell commands, formatting, or builds.

Keep the persistent watcher running at a short interval while a task is active. It must combine hidden-renderer approval scanning with all loaded ChatGPT app windows, so a clean hidden page can never suppress a pending card in another loaded window. This scan must not activate ChatGPT, move the pointer, switch tasks, or alter the user's visible page.

For long-running supervision, maintain a 10-minute heartbeat. Each heartbeat checks watcher health, the active hidden Chat target, pending approval cards, new thinking/tool content, final-reply state, and devspace1 connectivity. Restart the already-built watcher when unhealthy, but never send from the heartbeat.

Before treating the request as sent, require every `sendVerification.stages` entry to succeed. In particular, require `connectorConfirmed`, `inputConfirmed`, `messageConfirmed`, and `sent` to be true. The input step replaces any stale draft already present in a new Chat. The message step must observe a new user message bubble containing the submitted instruction; a button click or Enter key event alone is not success.

If preparation, Apps selection, text entry, or message confirmation fails, stop immediately. Report `failedStage`, `errorCode`, `stages`, `screenshotPath`, redacted `pageContent`, and `pageButtons`. Do not start a reply timeout for a message that the page did not confirm.

For an interrupted controller process, `resumeExisting: true` may bind the same Chat only to monitor it without sending. If another message is required, start a fresh Chat instead.

## Stall and recovery behavior

A stall requires 20 continuous minutes with no change in the visible thinking summary, devspace tool activity, or central Chat content. Do not treat a slow build as stalled while its visible activity changes.

The 20-minute timer applies only while ChatGPT still appears to be running. If generation has stopped and the stable response explicitly says the task is unfinished, blocked, or failed, return immediately with `chat_finished_incomplete`, the visible response, and diagnostics. Never wait for the stall timer after the Chat has ended.

Every unfinished handoff requires a `MAHAYANA_TASK_REPORT_V1` JSON report with `status`, `summary`, `completed`, `remaining`, `blockers`, `verification`, `wait_seconds`, `wait_reason`, `next_connector`, and `next_task`. A successful task result is sent to an independent acceptance Chat and does not require the machine report. When the report says `incomplete` or `blocked`, stop monitoring that finished Chat immediately and continue in a fresh Chat built from the original goal plus the report; never append to the finished conversation. A zero continuation cap means continue until complete or until the report lacks `next_task`. Repeated blockers must trigger diagnosis and an alternative path, or an exact list of required prerequisites, rather than merely stopping on a matching fingerprint.

Do not end a working Chat merely because Actions, deployments, releases, or remote checks are still running. Continue polling inside the task Chat. Use a handoff report only when continuation is impossible. The report must then use `incomplete` or `blocked`, keep `wait_seconds` as 0, and include a concrete `next_task`.

For GitHub-backed work, use the GitHub connector for cloud state and bhrum2 for the local checkout. Set `next_connector` when the next fresh Chat must switch between those contexts. Treat disconnects, DNS failures, upstream 502/503/504, and connector timeouts as a recoverable wait, not as completion or an instruction to repeat a failed request.

Treat `complete` as a candidate for controller handoff only when the structured report exists and all normal completion checks pass. A reply without the report is `task_report_missing`, not success. Attach the completed Chat to the user's current Worker only after this candidate is returned; the controlling AI must independently validate it before declaring the goal accepted. The Worker attachment is a result handoff, never an instruction-sending fallback.

On the first or second stall, the plugin must:

1. Capture a screenshot and the central Chat text.
2. Classify the event as `devspace_timeout` when the latest visible activity belongs to devspace1; otherwise classify it as `page_stalled`.
3. Click ChatGPT's stop control inside the hidden Chat and wait until the stop control has remained absent long enough to confirm the old response actually stopped. If this cannot be confirmed, return `old_chat_stop_not_confirmed` with diagnostics and do not create another Chat.
4. Only after stop confirmation, create a fresh Chat, select devspace1 again, and send a continuation that identifies the same checkout and tells ChatGPT to inspect whether the last action returned or landed, retry only that step if necessary, preserve completed work, and finish verification.
5. Reset the idle timer and continue streaming progress.

After `maxRecoveryAttempts`, stop instead of looping forever. Return the error, screenshots, `pageContent`, `pageButtons`, visible thinking, and recovery history.

Devspace itself independently returns `DEVSPACE_TOOL_TIMEOUT` when a tool invocation fails to return within its own 5-minute limit. This is separate from the Chat page's 20-minute visible-stall timer; shell commands can also use a shorter tool-specific timeout.

## Decide whether the task completed

Accept success only when all conditions hold:

- `ok: true`;
- `reply.done: true`;
- `reply.content` is non-empty;
- `timedOut: false`;
- `stalled: false`.

If any condition fails, report the plugin evidence and do not claim the coding task completed. A visible authorization card means ChatGPT is waiting for permission, not that devspace1 itself is hung.

Tool-activity rows such as `Link ... bash`, `Link ... read`, or `已使用 devspace1 集成` are not a final answer. A collapsed `思考` section is also not final when its visible text says the task is unfinished (`尚未完成`, `还需要继续`, or equivalent). Require substantive assistant content and a stable completion signal across consecutive polls.

Only after a valid final reply may the controlling AI inspect the target checkout, review the diff, run independent tests, and compare the implementation with the original request. Preserve unrelated user changes throughout validation.
