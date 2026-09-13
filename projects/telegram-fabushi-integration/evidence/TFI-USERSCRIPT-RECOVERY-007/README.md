# TFI-USERSCRIPT-RECOVERY-007 证据索引

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-007`
- Scope: 独立 ChatGPT 自动确认油猴脚本的任务目标图片、视频及其他文件输入；不改变 Fabushi 应用媒体平面。
- Evidence status: `SOURCE_RELEASED / PARENT_RECORD_PENDING / LIVE_EVIDENCE_PENDING`

## Source delivery

- Source repository: [bhrumom/fabushi-chatgpt-auto-confirm-userscript](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript)
- Implementation commit: `08771783680f6a2fcae6a1abc67be15ea8867800`
- Source PR: [#11](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/11), merged `2026-09-13T01:43:48Z`
- Canonical source main: `4e6340e380f5c6c9b22b4a5b4352ad08e8d67ba2`
- PR CI: [run 34731199307](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/34731199307), job `103654186412`, `success`
- Exact source-main CI: [run 34731259160](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/34731259160), job `103654358161`, `success`
- Release: [v2.9.11](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.11), release id `387761593`, target `4e6340e380f5c6c9b22b4a5b4352ad08e8d67ba2`
- Release asset: `chatgpt-auto-confirm.user.js`, asset id `560339046`, 133694 bytes, SHA-256 `7529a90211ebd969044313ca38fd1d7fca1fba702604794eafe749884a59695a`

## Local lightweight verification

- `node --check chatgpt-auto-confirm.user.js`: PASS
- `npm test`: PASS, 84/84
- No local Fabushi application build, native build, emulator/simulator run or heavy E2E was executed; repository instructions require those checks to run in GitHub Actions.

## Parent delivery

- Parent baseline: `bhrumom/fabushi main@6b77ac34060e1733dd8d0a900987a5dd2471a0bb`
- Parent records branch: `codex/tfi-userscript-file-input-20260913`
- Parent PR/merge/readback: pending
- Parent packaged product delivery: `N/A` — parent change is project-record-only and the runnable userscript is delivered from its independent source repository.

## Live browser evidence — pending

The required evidence bundle has not been captured. It must use authenticated Chrome and non-sensitive samples and tie every artifact to the installed version, source SHA, timestamp and journey identifier:

1. Workbench opens at `2.9.11`, one root, multi-file picker and selected image/video/ordinary-file chips.
2. Task record shows attachment metadata while browser storage keeps payload in IndexedDB rather than `localStorage`.
3. Uploading state is visible; the ChatGPT composer has not been sent yet.
4. Matching attachment names/previews are visible and upload is no longer pending.
5. Only after confirmation, the task prompt is sent and the conversation is tracked.
6. Unsupported/missing/timeout failure stays retryable and does not send plain text.

Required artifacts: step-labelled screenshots, one complete journey video, action trace/diagnostics, browser/version readback and native logs where available. Until these are attached, the task remains `IN_PROGRESS`.
