# TFI-USERSCRIPT-RECOVERY-018 — 导航许可活锁与最终回复续派

- 项目：`FAB-P0001` / `TFI`
- Task ID：`TFI-USERSCRIPT-RECOVERY-018`
- 来源：`source/2026-09-15-userscript-navigation-permit-livelock.md`
- 状态：`IN_PROGRESS / IMPLEMENTATION`
- 开始时间：2026-09-15（Asia/Shanghai）
- 最近更新：2026-09-15
- parent 分支：`codex/tfi-userscript-navigation-livelock-018-20260915`
- source 分支：`codex/navigation-livelock-2.9.31-20260915`

## 目标

修复“最终回复已出现但持续目标不续派”和“导航保护每 30 秒重复、永不真正切页”的共同根因：导航许可在实际切页前被错误记作已消费，失效许可不断重启冷却。

## 范围

包含 userscript 导航 lease 的最后验证、commit/cancel 消息、standalone 本地预算提交时点、持续目标 final -> review 续派回归；包含 Chrome 宿主只按已确认目标路由提交冷却/突发预算、过期/取消 lease 清理、bundled source/版本/Marketplace metadata 同步与发布证据。

不包含绕过 ChatGPT 账户限流、取消真实导航冷却、并发写同一 composer、取消 crash/unloaded 防护，或从截图内容推导其它产品需求。

## 依赖

- `TFI-USERSCRIPT-RECOVERY-014` 的宿主导航保护与 renderer recovery。
- `TFI-USERSCRIPT-RECOVERY-016` 的 per-task eligibility、公平轮询和 runner 自愈。
- source/parent protected main、GitHub Actions、exact-main Chrome packaged journey、Release 与 Marketplace immutable metadata。

## 验收标准

1. 宿主 grant 后、真实导航前票据失效时，userscript 发送 cancel；该 lease 不计入 30 秒冷却或 5 分钟预算。
2. 宿主只在精确目标 URL/status 提交时记录 committed navigation；错误/无关 tab update 不提交 lease。
3. standalone userscript 只在最后验证通过且即将调用 `location.replace/assign` 时记本地导航预算；same-route 和失效响应不消费预算。
4. 连续目标收割 final 后可进入 review 派发；一次失效 permit 不会使当前或兄弟任务永久停在“等待派发”。
5. source/host focused/full regression、parent bundled contract、exact-main Chrome packaged journey 与强制证据包全部通过。
6. userscript 与 Chrome 包版本单调递增；Release/sourceRef/hash/size/target SHA 可回溯。

## 验证方法

- 本机仅做轻量 `node --check`、现有 Node/JSDOM 单元回归、静态 diff/metadata 检查；不构建 Fabushi 应用。
- source GitHub Actions 跑完整 userscript regression。
- parent GitHub Actions 跑导航宿主测试、Chrome package/packaged simulated-user journey；合并后按 exact main 交付并保留截图、完整视频、trace/report/log。

## 开源调查与决策

调查 BullMQ delayed/stalled worker、WICG/GoogleChromeLabs Page Lifecycle 和 Chrome `tabs.onUpdated` 语义。复用“锁/许可与状态提交分离”的成熟设计，不引入其运行时或复制代码；采用 generation-bound 两阶段 navigation lease。详见 source requirement。

## 分支 / PR / 提交

- source branch：`codex/navigation-livelock-2.9.31-20260915`
- parent branch：`codex/tfi-userscript-navigation-livelock-018-20260915`
- source PR：[\#24](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/24)，已合并；source main `5f7d1f26a9883e6806ec855f5f2177ad737aa07e`
- source Release：[v2.9.31](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.31)，225544 bytes，SHA-256 `1e025a9b64bcba225059a0768fb08b5bcf818f902f8c7c4e5980505958e6fe2a`
- parent PR：待创建
- commit / canonical main：待验证

## 风险

- 若 commit 过早，仍会产生 phantom cooldown；若过晚，新文档加载后旧页面无法发消息。缓解：在最后票据校验后同步发 commit，并由宿主只在目标 URL update/complete 时最终计账。
- MV3 service worker 生命周期可能跨请求重启；lease 持久化在 session/local storage，并按 TTL 清理。
- Web Store 可能继续受既有审核锁定；GitHub source Release 与 exact-main parent Release 仍可独立完成，但不得冒充 Web Store 已公开。

## 实现/证据

source 已完成并发布；parent 分支实现与轻量宿主回归已完成，等待 parent PR、受保护主线及 exact-main 交付门禁。

## 下一步

提交 parent PR，运行 Chrome packaged simulated-user journey 和 Platform Control Plane 部署，回读线上 catalog/direct-release，并完成 Release/evidence 记录。

## 时间

- started_at：2026-09-15T13:10:00+08:00
- updated_at：2026-09-15T13:10:00+08:00
- completed_at：N/A
