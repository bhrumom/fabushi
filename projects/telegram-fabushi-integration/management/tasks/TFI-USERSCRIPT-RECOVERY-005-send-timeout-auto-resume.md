# TFI-USERSCRIPT-RECOVERY-005 — 发送超时后的自动恢复与持续运行

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-005`
- Status: `IN_PROGRESS`
- Started: `2026-09-12T02:00:00+08:00`
- Updated: `2026-09-12T02:25:00+08:00`
- Source: `source/2026-09-12-userscript-send-timeout-auto-resume.md`
- Requirements: `TFI-USR-ST-R01`–`TFI-USR-ST-R06`
- Source baseline: userscript `main@448d4d8f83d5e9e558ebd17cafad2a3ea426613f` (`2.9.6`)
- Parent baseline: `bhrumom/fabushi main@2a6cf4dbb64f0625a9dc147bb21b9949b018a219`
- Source branch: `codex/userscript-send-timeout-recovery-20260912-source`
- Parent branch: `codex/tfi-userscript-send-timeout-recovery-20260912`

## Objective

修复“消息发送超时/异常重发次数用尽后被自动暂停，未继续新开会话”的状态机缺口，使持续目标在安全退避后自动恢复，同时保留不确定发送的去重保护。

## In scope

- 页面级发送超时提示识别与安全恢复。
- 异常快速重发预算耗尽后的持久化退避/自动恢复。
- 空闲调度器不再把终态阻塞任务改成暂停。
- 轻量回归、source Release、父记录和现场验证门禁。

## Out of scope

- Fabushi 应用代码/构建/打包/原生 E2E。
- 未确认服务器是否接受的初始点击自动重发。
- 修改 ChatGPT 服务端错误或授权策略。

## Acceptance criteria

- [x] `TFI-USR-ST-A01`: 页面级“消息发送超时，请重试”被识别，消息正文和工作台日志不会自触发。
- [x] `TFI-USR-ST-A02`: 四次快速异常重发耗尽后，任务进入持久化延迟恢复而不是 `blocked`/`paused`，并在退避到期自动排队新会话。
- [x] `TFI-USR-ST-A03`: 延迟恢复保留任务目标/历史证据，成功 Work 或验收后清零退避计数。
- [x] `TFI-USR-ST-A04`: 发送未知、生成中、授权、安全验证、限流及跨任务所有权保护继续 fail-closed。
- [x] `TFI-USR-ST-A05`: 调度器没有可运行任务时不再把终态阻塞任务二次标记为暂停；手动暂停仍保持原语义。
- [x] `TFI-USR-ST-A06`: source syntax、全量轻量回归、PR/exact-main CI 和单调新 Release 通过。
- [ ] `TFI-USR-ST-A07`: 真实 Chrome 安装新版本后，消息超时/异常结束能自动新开会话并继续 Work → 验收，留存截图、完整视频、trace/diagnostics。
- [ ] `TFI-USR-ST-A08`: 父仓库记录经 protected main 合并并 canonical readback。

## Open-source-first survey

- `microsoft/playwright`（Apache-2.0）：官方文档强调 locator 的 auto-wait/retry 以及超时后的显式信号；本轮采用“稳定状态 + 页面级可见错误”而不是瞬时 DOM 事件，未复制代码、未新增依赖。
- `resilience4j/resilience4j`（Apache-2.0）：成熟的 Retry、TimeLimiter、CircuitBreaker 模式支持退避和失败后暂时阻断；本轮只借鉴“有限快速预算 + 有界指数退避”的状态模型，不把 Java 依赖引入 userscript。
- `failsafe-lib/failsafe`（Apache-2.0）：提供 retry policy、backoff 和 max delay；本轮借鉴可持久化的下一次尝试时间与上限，不复制实现。

## Verification method

- 本地只执行 `node --check chatgpt-auto-confirm.user.js` 与 jsdom userscript tests；不运行 Fabushi 应用构建或测试。
- GitHub 运行 source PR/exact-main CI 和 Release provenance。
- 现场使用电脑插件读取安装版本、单工作台/状态变化，并执行发送超时或无最终回复 → 新会话 → 原样重发 → 新验收会话的完整旅程。

## Implementation / evidence

- `chatgpt-auto-confirm.user.js` bumped to `2.9.7`; visible page-level send-timeout detection excludes the workbench and ChatGPT transcript.
- The old throw-on-exhaustion branch now persists a 5/10/20/30-minute capped exponential recovery deadline, clears only the active conversation dispatch handle, and keeps the task in `waiting`; the scheduler resumes at the deadline. Successful Work/review completion resets the recovery counters.
- A startup migration revives legacy 2.9.6 records whose latest log says the abnormal retry budget was exhausted, provided a real conversation URL exists; ambiguous unconfirmed sends remain fail-closed.
- The idle scheduler now halts without rewriting terminal `blocked` records to `paused`; explicit manual pause is unchanged. The left task row displays the recovery countdown.
- Source commit: `adff78c5d6c7ddba88c360e693601de983601a78` (`2.9.7`), PR [#5](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/5), merged to source `main`.
- PR CI: run `34632077834`, job `103371068407`, `userscript`, success. Exact source-main CI: run `34632156429`, job `103371328841`, `userscript`, success.
- Release: `v2.9.7`, release ID `387246515`, target `adff78c5d6c7ddba88c360e693601de983601a78`; asset `chatgpt-auto-confirm.user.js`, asset ID `557757902`, 107701 bytes. Downloaded release asset SHA-256 matches the source file (`6f7d5e1b349082f1b3d371e98cb6c716f70a2166a5a72731672155df66b8de18`).
- Local lightweight checks: `node --check chatgpt-auto-confirm.user.js`; `npm test` 76/76 passed.
- Existing screenshot/CUA reproduction remains in `evidence/TFI-USERSCRIPT-RECOVERY-005/README.md`; live 2.9.7 browser evidence is still pending.

## Risks and blockers

- 发送超时可能是服务端已接受但客户端未确认；任何自动恢复必须保留 token/URL 证据并禁止同一不确定点击的重复派发。
- 无限退避会掩盖永久性服务错误；需显示下一次尝试时间、退避轮次和用户可手动暂停入口。
- 真实 Chrome 仍需安装待发布版本才能关闭现场验收门禁。

## Next action

在已登录 Chrome 中通过 Fabushi Marketplace 安装 `v2.9.7`，捕获版本/单根节点、页面发送超时或无最终回复后的自动新会话、原样重发与 Work → 验收的截图、完整视频、trace/diagnostics；之后提交并合并父仓库治理记录。任务在现场证据与父仓库 canonical readback 前保持 `IN_PROGRESS`。
