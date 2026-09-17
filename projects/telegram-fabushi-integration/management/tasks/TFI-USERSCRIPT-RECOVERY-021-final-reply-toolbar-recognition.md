# TFI-USERSCRIPT-RECOVERY-021 — 真实回复操作栏最终回复识别

## Identity

- Portfolio Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-021`
- Source: `source/2026-09-16-userscript-final-reply-toolbar.md`
- Related cumulative task: `TFI-USERSCRIPT-RECOVERY-020` 的无限停滞刷新要求随本次 parent release 一并交付；不复用冲突候选 PR 的历史分支。

## Objective

修复 ChatGPT 页面最终回复识别：当前 assistant 回复正文出现回复级 `复制+分享`，或真实页面暴露的 `复制回复+评价回复/Rate response` 时，脚本应判定最终回复；页面顶部全局 `分享`、无关操作栏和单个按钮不能完成回复。同步发布包含无限 3 分钟停滞刷新修复的可追溯 source/parent 版本。

## Scope

In scope:

- userscript `latestTurn` 的语义操作识别、当前 assistant turn 归属和 portaled association。
- `Share/分享/共享` 与 `Rate response/评价回复/评分` 的实际 renderer 语义兼容。
- 复制+分享、复制+评价、stale streaming、页面级分享隔离和 foreign portal 回归。
- 继承 source `v2.9.33` 的无限 180 秒停滞刷新语义，并把 source artifact 固定到 parent bundled/Marketplace。
- source Release `v2.9.35`、parent Chrome `0.6.11`、protected-main integration、exact-source zero-test package/provenance 和正式发布门禁。

Out of scope:

- 不点击用户当前页面的发送、分享、评价或更新按钮。
- 不取消或覆盖 Chrome Web Store 既有审核提交。
- 不修改 ChatGPT 页面本身、账号权限、任务正文或附件。

## Acceptance criteria

1. 当前 assistant turn 有正文和可见 `复制+分享` 时，`responseActionsComplete=true`、`final=true`；stale `data-is-streaming=true` 不能阻挡。
2. 当前真实页面语义 `复制回复+评价回复/Rate response` 时，`responseActionsComplete=true`、`final=true`。
3. 页面顶部全局 `分享`、只有分享、只有复制、无关/未绑定 portaled controls 均不能误报；当前 turn 的显式关联 portaled `复制+分享` 可以完成。
4. `Stop`、授权卡、限流、foreign user turn 和无正文安全边界保持不变。
5. 绑定会话无可见变化时每 180 秒可继续刷新，不存在两次终止上限，并保留发送去重身份、附件和阶段。
6. source、bundled、Worker projection 的 version/source commit/release URL/size/SHA-256 完全一致；Chrome manifest/packaging/validator/workflow 版本单调递增。
7. source CI、parent protected-main、exact-source Chrome zero-test package/content manifest/checksums 均有证据。按照 FCM-024 当前最高优先级治理，不再要求自动 Playwright/packaged E2E/视频/trace 作为测试发布门禁；正式/稳定发布只能由手工启动的 Action App-owned runner 经 Fabushi official MCP 对 exact candidate 做外部控制验收。任一正式门禁未完成前保持 `IN_PROGRESS`。

## Open-source-first survey

- `sindresorhus/p-retry`（MIT）：确认无限重试应由显式间隔、可取消边界和退避控制；本任务沿用 userscript 自有 180 秒 watchdog，不新增运行时依赖。
- `TanStack/query` retryer（MIT）：参考按条件决定 retry、暂停/恢复和 retry delay 的结构；当前页面完成判定仍使用 Fabushi 自身 task/turn ownership，避免引入通用请求库。
- `KudoAI/chatgpt.js`（MIT）：检查 ChatGPT DOM 变化与语义查询思路；未直接复用易漂移的内部 selector，改为当前 assistant turn 内多属性语义匹配并保留归属校验。

Decision: adapt the proven retry/semantic-query ideas, reject a new dependency because this is a standalone userscript and the existing code already owns persistence, scheduling and safety boundaries.

## Verification

- Local lightweight: `node --check` and `git diff --check` passed for the source/parent edits recorded by the originating Work session; no local application build, native test or E2E is claimed.
- Computer Use inspection: current Chrome AX tree observed top-level `分享` versus response-level `复制回复`/`评价回复`/`切换模型`/`更多操作`.
- Source CI: PR [#28](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/28), run [35102539237](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/35102539237), full regression and syntax passed.
- Source main/Release: merged source main `42df09a39f4505418f13a4fab578c96ee03b9b37`; [v2.9.35](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.35); asset `235583` bytes, SHA-256 `4fc88a50a8bb5034d5ec41f262c333d83e83917b1e22f75b26bb04ae10f8602b`.
- Parent integration: PR [#2680](https://github.com/bhrumom/fabushi/pull/2680) passed PR checks and merge-group CI and merged through the protected merge queue at canonical main `343019ed0d10ab4ecd9bd37c3aa686d3cc59f2c2` on `2026-09-16T14:02:48Z`.
- Canonical readback after #2680: Chrome manifest `0.6.11`; bundled userscript, Marketplace metadata and Worker projection all pin source `v2.9.35`, source commit `42df09a39f4505418f13a4fab578c96ee03b9b37`, `235583` bytes and SHA-256 `4fc88a50a8bb5034d5ec41f262c333d83e83917b1e22f75b26bb04ae10f8602b`.
- Zero-test package-chain repair: PR [#2681](https://github.com/bhrumom/fabushi/pull/2681) restored artifact construction only, without Node tests, Playwright or product E2E. Merge-group run `35106753460` passed and #2681 merged through the protected queue at `195ddb0d96ca58fb262b6fe5a8b859056bc013c9` on `2026-09-16T14:11:21Z`.
- Exact-source Chrome package: run [35106817630](https://github.com/bhrumom/fabushi/actions/runs/35106817630), job `104830079326`, source `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`, success. The job ran checkout -> Node setup -> deterministic package -> provenance/checksum verification -> artifact upload only.
- Inner Web Store ZIP: `fabushi-chrome-0.6.11.zip`, `124645` bytes, SHA-256 `7eb41b77c0cd86953729990467adc30a7eef2c2a500e4018e32d68e1864104db`; `fabushi-chrome-0.6.11.content-manifest.json` and `SHA256SUMS.txt` both verified `OK` in the Action log.
- Action artifact: ID `10450532008`, name `fabushi-chrome-web-store-195ddb0d96ca58fb262b6fe5a8b859056bc013c9`, `125574` bytes, artifact digest `sha256:7d95d6a5463a3a7d812ca7b9c533856ac06449150734db6769f638e88582bcb0`, retention through `2026-12-15`.
- Formal acceptance blocker was rechecked in this continuation: `fabushi官方mcp.fabushi_account` returned HTTP 400 / `We couldn't connect your account. Please try again.`. Per FCM-024, unified-device control, historical E2E or another device cannot substitute for official-MCP exact-candidate acceptance.

## Status and next action

- Status: `IN_PROGRESS / FORMAL_MCP_BLOCKED`.
- Source userscript: `v2.9.35` is publicly released.
- Parent product code: merged to protected `main`.
- Chrome zero-test package: produced and checksum/provenance verified for exact product-bearing main `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`.
- Next action: restore/reconnect the Fabushi official MCP account, start the required exact-candidate App-owned Action runner, perform the official-MCP external control acceptance, and only then submit/promote the formal Chrome/production release. No old E2E or alternate control path may be used to bypass this gate.
- Blocker: Fabushi official MCP connection-layer HTTP 400. Chrome Web Store review state, if an older submission is still under review, is a separate downstream condition and does not satisfy this candidate's formal gate.
- Started: `2026-09-16T21:12:00+08:00`
- Updated: `2026-09-16T22:12:00+08:00`
- Completed: pending formal official-MCP acceptance and stable publication
