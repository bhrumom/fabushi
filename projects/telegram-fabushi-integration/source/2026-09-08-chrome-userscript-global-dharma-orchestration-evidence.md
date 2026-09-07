# 2026-09-08 Chrome userscript Global Dharma orchestration/evidence requirement

Project: `FAB-P0001 / TFI`
Workstream: Chrome extension Marketplace userscript + Global Dharma end-to-end evidence
Source: user execution round `global-dharma-evidence-video`

## Required outcome

1. The existing ChatGPT auto-confirm workflow must be available as an independent Marketplace-installed Chrome user script. Searching Fabushi Marketplace for `ChatGPT 自动确认` must discover it. Installation must be explicit and the script must remain independent of the desktop app.
2. On ChatGPT Web the script must expose a visible Fabushi launcher button. Clicking it opens a graphical UI where the user can enter the task id, revision, spec digest, platform and goal/next task and control execution.
3. Orchestration is durable and recoverable across ChatGPT tabs. Independent goals may run in parallel in the same browser session. Each work round is followed by a fresh ChatGPT acceptance conversation. Acceptance output is parsed only from a strict `MAHAYANA_TASK_REPORT_V1_BEGIN/END` JSON envelope.
4. A missing or malformed report never completes a goal. `complete` is valid only with `all_tasks_complete=true`, `remaining=[]`, `blockers=[]`, `wait_seconds=0`, and `next_task=""`. `incomplete`/`blocked` require `all_tasks_complete=false` and non-empty `next_task`, which becomes the next work round.
5. Approval automation must fail closed. It may select only a visible session-scoped option such as `允许本次会话` / `Allow for this session` using the approval card's keyboard/arrow selection path. It must not inspect password values, cookies, bearer credentials, API keys, exported credentials, OTP/2FA values, or choose persistent authorization.
6. Final acceptance still requires real browser/UI evidence, not a synthetic/mock substitute: Marketplace search/install, userscript launcher/UI, work->acceptance->next-work loop, Global Dharma search/install/Bot/open app/WebMCP/shared state/account/commerce boundaries, screenshots, complete video, trace/logs and downloadable artifact links tied to exact source SHA.

## This execution round

Close the userscript protocol/safety gap first: add strict report parsing, fresh-chat work/acceptance state transitions, cross-tab coordination, session-only approval selection, and UI fields/launcher. Add dependency-free contract tests. Do not claim the overall Global Dharma goal complete until packaged/live evidence exists.
