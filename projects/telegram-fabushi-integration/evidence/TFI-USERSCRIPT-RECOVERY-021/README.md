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

## Parent protected-main delivery

- Parent repository: `bhrumom/fabushi`.
- Integration PR: [#2680](https://github.com/bhrumom/fabushi/pull/2680), merged through the protected merge queue at `2026-09-16T14:02:48Z`.
- Product integration main SHA: `343019ed0d10ab4ecd9bd37c3aa686d3cc59f2c2`.
- Bundled userscript is byte-identical to source Release `v2.9.35`.
- Marketplace and Worker projection pin source commit `42df09a39f4505418f13a4fab578c96ee03b9b37`, release `v2.9.35`, size `235583`, SHA-256 `4fc88a50a8bb5034d5ec41f262c333d83e83917b1e22f75b26bb04ae10f8602b`.
- Chrome manifest version: `0.6.11`.

## Zero-test Chrome package evidence

FCM-024 supersedes the older automatic Playwright/journey gate for test/prerelease construction. The parent package must be built and provenance-verified without product behavior tests; stable/formal acceptance is separate and official-MCP-only.

- Packaging repair PR: [#2681](https://github.com/bhrumom/fabushi/pull/2681), merged through merge queue at `2026-09-16T14:11:21Z`.
- Exact product/package source main SHA: `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`.
- Merge-group CI: run `35106753460`, success.
- Chrome package workflow: [run 35106817630](https://github.com/bhrumom/fabushi/actions/runs/35106817630), event `push`, branch `main`, exact source `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`.
- Package job: `104830079326`, `Package exact-source Fabushi Chrome without behavioral tests`, success.
- Job steps: checkout exact source; set up Node; `node scripts/package-chrome-extension.mjs`; source/version/checksum verification; artifact upload. No `npm test`, Playwright, simulator/emulator, packaged-app E2E, smoke, regression or user journey is part of this workflow.
- Web Store ZIP: `fabushi-chrome-0.6.11.zip`, `124645` bytes, SHA-256 `7eb41b77c0cd86953729990467adc30a7eef2c2a500e4018e32d68e1864104db`.
- Package log: source SHA `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`; `fabushi-chrome-0.6.11.zip: OK`; `fabushi-chrome-0.6.11.content-manifest.json: OK`.
- Action artifact ID: `10450532008`.
- Artifact name: `fabushi-chrome-web-store-195ddb0d96ca58fb262b6fe5a8b859056bc013c9`.
- Artifact bundle size: `125574` bytes.
- Artifact digest: `sha256:7d95d6a5463a3a7d812ca7b9c533856ac06449150734db6769f638e88582bcb0`.
- Artifact retention: until `2026-12-15T14:11:23Z`.

## Formal-release blocker

- Fabushi official MCP was called again during continuation before formal publication.
- `fabushi_account` returned HTTP 400 with `We couldn't connect your account. Please try again.`.
- FCM-024 therefore blocks formal/stable publication. Unified-device control, historical autonomous E2E, a previously published version, or a different device is not accepted as substitute evidence.
- Once the official MCP account is connected again, the next evidence must come from the exact-candidate manually dispatched App-owned Action runner and official-MCP device/tool/finish transcript before stable promotion.

## Current evidence contract

For this task, test/prerelease construction evidence is exact source, immutable package artifact, content manifest, checksums and provenance. Automatic product behavior tests are intentionally absent under FCM-024. Formal stable publication still requires exact-candidate manual Action runner + App-owned device + Fabushi official MCP external control evidence. The task remains open until that gate and downstream stable publication complete.
