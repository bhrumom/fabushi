# TFI-USERSCRIPT-RECOVERY-016 — 公平持续调度与执行器自愈

- 项目：`FAB-P0001` / `TFI`
- Task ID：`TFI-USERSCRIPT-RECOVERY-016`
- 来源：`source/2026-09-15-userscript-fair-continuous-scheduler.md`
- 状态：`IN_PROGRESS`
- 开始时间：2026-09-15（Asia/Shanghai）
- 最近更新：2026-09-15
- parent 分支：`codex/tfi-userscript-scheduler-016-20260915`
- source 分支：`codex/fair-scheduler-2.9.29-20260915`

## 目标

消除单个任务的冷却/退避对整个标签页调度器的头阻塞，取消“查看会话即暂停”，并让页面换代后的单执行器租约可以可靠接管，使多个任务持续、公平、安全地轮换推进。

## 范围

包含 userscript 的 per-task eligibility、最早唤醒、公平轮询、导航保护文案、查看会话不中断、Web Lock 接管和对应回归；包含 Fabushi 内置 userscript 镜像、版本/包验证与项目记录。

不包含绕过 ChatGPT 真正的账户限流，不允许同时向同一个 composer 并发发送，不引入 ChatGPT 私有 API，不删除宿主崩溃/导航保护。

## 依赖

- 依赖 `TFI-USERSCRIPT-RECOVERY-014` 的宿主导航 permit 与 renderer recovery。
- 依赖 `v2.9.28` 的 task-scoped turn ownership。
- parent 产品交付须经过 protected main、exact-main Chrome package/E2E、证据包和 Release。

## 验收标准

1. A 在 navigation/rate/backoff/dispatch 延迟时，B 若可运行会在下一次调度中被选择。
2. 全部任务延迟时只等待最早截止时间；恢复/新增任务能立即抢占睡眠。
3. 打开 A 的已记录会话不改变 A/B 的运行状态，也不会清除全局 auto-resume。
4. 文档换代时新实例对旧 runner lock 进行有界接管；旧实例消失后自动开始扫描。
5. 真实限流、导航保护、异常退避在状态和日志中可区分。
6. source focused/full regression、parent bundled contract、Chrome exact-main packaged simulated-user journey 全部通过并保留截图、视频、trace/report/log。

## 验证与证据计划

- 本机仅运行 `node --check`、Node/jsdom focused regression、diff/静态检查；不构建 Fabushi 应用。
- source GitHub Actions：完整 userscript regression。
- parent GitHub Actions：Chrome/package/security scoped checks；合并后 exact-main packaged user journey 和 post-main delivery。
- 证据索引：`evidence/TFI-USERSCRIPT-RECOVERY-016/README.md`。

## 开源调查与决策

Kubernetes workqueue、BullMQ delayed jobs、Temporal durable timers 的调查与许可证/适配结论记录在 source requirement。决定采用按任务延迟集合和 worker 非阻塞语义，不引入其服务端依赖或复制实现。

## 风险

- 过度放宽互斥可能重复发送；发送、上传、授权、未确认 click 仍持有前台调度器。
- ChatGPT 真限流可能是账户级；本任务只阻止错误的头阻塞与误导文案，不绕过真实限制。
- 当前用户工作区存在其他未提交改动；本任务在独立 clean worktree 中实施，不覆盖原工作区。

## 实现/证据

- source `codex/fair-scheduler-2.9.29-20260915` 已实现并合并为 canonical source main `480ebe61ba039f15e7023bbc0253ea23c373aba0`，Release `v2.9.30`；source PR #22（调度修复）和 #23（运行时版本对齐）均通过 CI。Release asset `chatgpt-auto-confirm.user.js` 为 224113 bytes，SHA-256 `d15040a5d420b0fa4cc38b195f178143a2d22a166e3357f88c7159c6b7a3b14a`。
- source full regression：`120/120 PASS`；另通过 `node --check` 与 `git diff --check`。本机验证只使用已有 jsdom 依赖的轻量夹具，不构建或运行 Fabushi 应用。
- parent clean branch 已将 bundled userscript 与 source asset 做字节级同步；Marketplace fallback 已固定 `sourceRef=480ebe61ba039f15e7023bbc0253ea23c373aba0`、version `2.9.30`、size `224113`、SHA-256 `d15040a5…`。Chrome manifest/package/validator/test/E2E contract 已从 `0.6.4` 推进到 `0.6.5`。
- parent PR、protected-main merge、exact-main Chrome package/simulated-user evidence、post-main Release 与登录 Chrome 现场证据尚未完成；因此任务继续为 `IN_PROGRESS`。

## 下一步

提交 parent PR 并等待 required checks/protected merge；随后对精确 canonical main 运行 Chrome package、模拟用户旅程和 post-main Release，最后在用户确认后回读当前登录 Chrome 的双任务连续轮换。

## 时间

- started_at：2026-09-15T01:05:00+08:00
- updated_at：2026-09-15T01:30:00+08:00
- completed_at：N/A（任务进行中）
