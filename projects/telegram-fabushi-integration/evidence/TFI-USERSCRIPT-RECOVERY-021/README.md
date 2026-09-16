# Evidence — TFI-USERSCRIPT-RECOVERY-021

This index tracks the exact source and parent delivery lineage for the real ChatGPT response-toolbar final-reply fix.

## Source

- Source PR: [#28](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/28), merged `2026-09-16T13:33:02Z`.
- Source main merge SHA: `42df09a39f4505418f13a4fab578c96ee03b9b37`.
- Source CI: [run 35102539237](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/35102539237), success; syntax and full regression passed.
- Source Release: [v2.9.35](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.35), published `2026-09-16T13:33:15Z`.
- Asset: `chatgpt-auto-confirm.user.js`, `235583` bytes, SHA-256 `4fc88a50a8bb5034d5ec41f262c333d83e83917b1e22f75b26bb04ae10f8602b`.
- Download URL: `https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/download/v2.9.35/chatgpt-auto-confirm.user.js`.

## Actual UI evidence

- Computer Use inspected Chrome window `核验发布执行状态`, URL `chatgpt.com/c/6aaa55e7-37d0-83e8-a30f-07d8af88f12b`.
- Observed page-level button: `分享`.
- Observed response toolbar: `复制回复`, `评价回复`, `切换模型`, `更多操作`.
- This confirms the implementation must recognize `评价回复/Rate response` as the current renderer's completion action and must not use the page-level share button as a generic completion signal.

## Parent delivery

- Parent repository: `bhrumom/fabushi`.
- Parent branch: `codex/tfi-final-reply-share-20260916`.
- Bundled userscript: byte-identical to source Release asset above.
- Worker projection: source commit/release URL/size/SHA-256 updated to the same Release.
- Candidate Chrome version: `0.6.11`.
- Parent PR, canonical-main SHA, exact-main package/journey, evidence artifact, parent Release and production catalog readback: pending.

## Evidence contract

Required for application-affecting parent delivery: exact canonical-main SHA, workflow/job IDs, package/content manifest/checksums, step-labelled screenshots, complete journey video, trace, HTML/test report and native logs; upload must occur on passing and failing paths with the maximum permitted retention. No local build or packaged E2E is claimed.

