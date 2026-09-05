# PRD — task-oriented Bot delivery

## User outcome
A Bot conversation is a durable work session rather than a one-shot answer. The user sees ordered steps, streamed reasoning-safe progress summaries and tool events, approvals, errors, artifacts and completion. Work can be paused, stopped, resumed or redirected and remains coherent across desktop and Web.

## Requirements
1. Reuse the single Mahayana Agent runtime and existing MiniApp/Artifact/StepTracker/Sandbox boundaries.
2. Persist conversation/run/step/tool/approval/artifact/delivery state and recover it after restart.
3. Tool actions pass the existing policy/approval/audit boundary; secrets are never emitted in transcripts or audit payloads.
4. Delivery is first-class: files, URLs, runnable HTML/MiniApps, patches/PRs and releases produce artifact/delivery events, durable records, open/download cards and retryable failures.
5. Desktop and Web consume the same canonical event/state model for live progress, pause/stop/resume/redirect, approvals/errors and delivery cards.
6. Background/scheduled tasks and subagents reuse existing scheduler/runtime primitives and retain parent/child correlation.
7. chatgpt-auto-confirm persists per-turn timing and continuation audit and enforces the two same-chat follow-ups / 1200-second rollover rule using a monotonic clock for duration measurement.

## Non-goals
- No second agent executor.
- No wholesale OpenBot/Hermes source import.
- No credential capture in task history.
- No static mock as acceptance evidence.