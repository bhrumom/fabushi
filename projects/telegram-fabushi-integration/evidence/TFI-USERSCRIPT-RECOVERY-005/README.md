# TFI-USERSCRIPT-RECOVERY-005 evidence index

Status: `IN_PROGRESS`

## Current evidence

- 用户截图（2026-09-12 Asia/Shanghai）：持续目标工作台显示“已暂停”；日志为“会话已结束但没有最终回复，自动重发次数已用尽”后紧接“已暂停；不会发送、导航或刷新”；页面显示“消息发送超时，请重试”。
- 电脑插件只读状态与截图一致：当前 ChatGPT 标签页为 `https://chatgpt.com/c/6aa428f5-3078-83e8-8c81-3db47ed1c0d9`；旧脚本工作台存在当前/可恢复任务分组，当前实例报告已暂停。
- 根因初判：2.9.6 四次快速异常重发预算耗尽后抛出错误；无运行任务分支调用 `pause()`，把终态错误任务再次转换成暂停，因而没有继续派发。
- 开源调查：Playwright locator retry/timeout、Resilience4j Retry/CircuitBreaker/backoff、Failsafe retry policy/backoff；仅采用设计原则，不复制代码和依赖。

## Pending closure evidence

- 新版 userscript source PR、exact-main CI 和 Release provenance。
- 页面级发送超时识别与四次预算耗尽后持久化退避的轻量回归。
- 现场安装新版本的 one-root、状态变化、自动新会话、原样重发和 Work → 新验收会话截图、完整视频、trace/diagnostics。
- 父仓库记录 protected merge 与 canonical readback。

No Fabushi application build/package/E2E is applicable; this task is limited to the standalone userscript.

## Source delivery evidence (2026-09-12)

- Source PR [#5](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/5) merged to `main@adff78c5d6c7ddba88c360e693601de983601a78`.
- PR CI run `34632077834`, job `103371068407`, and exact source-main run `34632156429`, job `103371328841`, both completed `success`.
- Release `v2.9.7` (ID `387246515`) targets the same source-main SHA and includes `chatgpt-auto-confirm.user.js` asset ID `557757902` (107701 bytes). Release asset SHA-256: `6f7d5e1b349082f1b3d371e98cb6c716f70a2166a5a72731672155df66b8de18`.
- Lightweight verification on the source branch: `node --check chatgpt-auto-confirm.user.js`; `npm test` 76/76 passed.
- Implemented behavior: page-level send-timeout recovery, persisted bounded abnormal-end backoff, legacy exhausted-record migration, idle terminal-state protection, and visible left-list recovery countdown.

The live Chrome installation and full visual/diagnostic journey remain open; the source Release does not by itself prove installed-browser behavior.
