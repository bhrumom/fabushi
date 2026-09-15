# TFI-USERSCRIPT-RECOVERY-019 — 最终回复识别、停滞刷新与验收 JSON 恢复

## Identity

- Portfolio Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-019`
- Requirement source: `projects/telegram-fabushi-integration/source/2026-09-15-userscript-final-reply-stall-refresh-json-recovery.md`
- Related tasks: `TFI-USERSCRIPT-RECOVERY-018`, `CWA-008`

## Objective

修复用户反馈的三个连续故障：最终回复已经显示但未被识别、会话长时间无变化时授权卡片/任务不再前进、验收回复 JSON 轻微格式错误把任务卡在“需要处理”。发布 source userscript 新版本，并同步父 Chrome/Marketplace 镜像，确保线上资产可验证且不会重复发送。

## Scope

### In scope

- userscript assistant turn 的语义最终回复证据：正文、复制按钮、点赞/点踩按钮和流式/Stop 排除条件。
- 绑定会话 180 秒无进展的受控刷新、次数上限、状态/附件/token 保留和刷新后的重新扫描。
- 验收 JSON 的严格优先解析、有限容错提取、repair/requeue 与重复 Work 防护。
- source tests/README/version/Release；父仓库 bundled source、Chrome 版本和 Marketplace immutable metadata 同步（若父交付门禁通过）。

### Out of scope

- ChatGPT 页面本身、第三方授权服务或 Chrome Web Store 审核状态的改变。
- 新增外部 userscript runtime dependency、重写现有 dispatcher/host 协议、Faliu 内容卡片。
- 本机应用构建或本机重型 E2E；仅做轻量静态检查，重验证由 Actions 完成。

## Dependencies

- source repository `bhrumom/fabushi-chatgpt-auto-confirm-userscript` 的 `main` 与 v2.9.31 基线。
- 父仓库 `bhrumom/fabushi` canonical `main`、Chrome packaged workflow、Platform Worker projection 和保护主线/Release 门禁。
- 既有导航许可/公平调度/Marketplace 任务的状态与不可变 source metadata。

## Acceptance criteria

1. 对当前 task marker 的稳定 assistant 正文，只要可见复制按钮和点赞或点踩反馈按钮同时存在，即可成为最终回复证据；不依赖第三个操作按钮。流式、Stop、foreign task、授权卡片、限流和错误卡片不误报。
2. 当前绑定会话连续 `180000 ms` 没有正文、回复操作、加载/授权或任务状态变化时，脚本最多受控刷新两次；刷新保留 URL、phase、round、token、result、attachments 和“不重复发送”语义，并在刷新后恢复扫描。发送歧义、限流或错误页面不被刷新动作放大。
3. 验收回复解析严格 JSON 优先；能从前后说明/代码围栏/可安全恢复的未转义引号中提取 `taskId`、`round`、`status`、`summary` 及 `next`。失败时最多两次 review repair/requeue，保留已完成 Work result，不再重复 Work；超过上限才转为明确可操作的 blocked 状态。
4. source header、README、测试夹具和 Release 版本一致；source CI 至少通过语法检查和完整 userscript regression。
5. 父仓库若同步 bundled/Marketplace，则版本递增、source commit/hash/size 一致；PR 经保护主线合并后，针对 exact canonical main SHA 运行 Chrome package/packaged simulated-user journey，保留逐步截图、全程视频、trace、HTML/report/native logs，并验证生产 catalog/direct-release 回读。若父交付尚未完成，本任务保持 `IN_PROGRESS`，不得将 source Release 误报为 Fabushi 产品交付完成。

## Verification plan

- 轻量本地：只做源码阅读、`node --check`、差异/版本/hash 静态核对；不在本机 build/package/app/E2E。
- GitHub Actions：source PR workflow 的 `node --check` 与 `npm test`；父 PR 的受影响 CI、Platform Control Plane、Chrome package 和 exact-main post-main workflow。
- 回归用例：copy+thumbs-only final；旧第三按钮仍兼容；流式 copy-only 不完成；portal action association；180 秒停滞刷新与上限；刷新保留任务字段；包裹/坏引号 review JSON；repair 不重复 Work；外部/foreign turn 隔离。
- 发布证据：source PR/merge SHA、source CI run/job、Release tag/asset/hash/size；父 PR、canonical main SHA、Chrome artifact、E2E evidence bundle、Worker deploy 与线上 metadata readback。

## Open-source-first survey and decision

- [KudoAI/chatgpt.js](https://github.com/kudoai/chatgpt.js)（MIT）：参考其 DOM 语义 response/regenerate/stop 控件抽象和版本化用户脚本维护方式；Fabushi 仍保留自己的 task marker、portal association 和 fail-closed 规则，不复制代码、不增加依赖。
- [Violentmonkey](https://github.com/violentmonkey/violentmonkey)（MIT）：参考 userscript 更新/调试与持久化边界；不改变 Fabushi 的明确用户授权和不可变 Release 校验。
- [WICG Page Lifecycle](https://github.com/WICG/page-lifecycle)：参考页面 freeze/resume/discard 不能假设总有回调的原则；本任务采用可重入的持久任务字段与受控 reload，而不是依赖单一页面生命周期事件。
- 延迟队列/工作队列（BullMQ/Kubernetes workqueue/Temporal 的公开设计）：参考 delayed/stalled task 的有界重试语义；本任务不引入 Node worker 或第三方运行时。
- 决策：成熟方案提供了可复用的语义和边界，但没有与 Fabushi task/approval/review 状态和 ChatGPT DOM 完全兼容的成品；采用小范围适配，拒绝复制不必要代码或引入运行时依赖。

## Branch / commit / PR

- Parent records/implementation branch: `codex/tfi-userscript-019-final-reply-stall-refresh-20260915`
- Source implementation branch: `codex/final-reply-stall-refresh-2.9.32-20260915`
- Source PR: [#25](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/25) — merged source main `50569be0ab88909408ed8880a24c185906d760eb`
- Source Release: [v2.9.32](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.32), 234862 bytes, SHA-256 `30ec1f70e0c14a8ebbd530b2cf0186a2d63690bf85e45b8ec8d0e1a81090e9e7`
- Parent PR: [#2652](https://github.com/bhrumom/fabushi/pull/2652) — bundled source, Chrome `0.6.10`, and Worker pin staged; canonical main SHA pending

## Status and evidence

- Status: `IN_PROGRESS / SOURCE_RELEASED / PARENT_CI_PENDING`
- Started: `2026-09-15`
- Updated: `2026-09-15`
- Completed: pending required source + parent delivery gates
- Current blocker: parent Actions, protected-main merge, exact-main Chrome packaged/E2E evidence, production Worker readback and parent Release are required.
- Risks: overly broad button matching could create false final replies; reload during an ambiguous send could duplicate Work; tolerant JSON extraction could accept foreign text. Mitigate with task/turn association, Stop/streaming checks, bounded refresh/repair, strict identity/round validation and regression fixtures.
- Implementation summary: source v2.9.32 now uses copy + like/dislike as final evidence, refreshes a bound unchanged conversation after 180 seconds with a two-refresh cap, and requeues only the review phase after bounded JSON recovery failure. Parent mirrors the exact source Release metadata and increments Chrome to 0.6.10.
- Next action: run parent PR Actions, merge through protected main, run exact-main packaged simulated-user evidence, deploy/read back Marketplace, then publish the parent Release if all required gates pass.
