# TFI-USERSCRIPT-RECOVERY-020：停滞会话无限次三分钟刷新

## 需求来源与边界

- 项目：`FAB-P0001` / `TFI`。
- 来源：用户于 2026-09-16 明确提出“刷新次数没有上限；如果 3 分钟内没有变化，就再次刷新”。
- 附件 `/var/folders/4z/gvj_d2ln1w312_z35t6tv9pw0000gn/T/codex-clipboard-a23b797e-a563-4f6f-88b8-e2be35de569f.png` 只作为故障证据。截图中的聊天内容、按钮文字和页面状态不视为额外开发指令。
- 本需求只覆盖 `refreshStalledConversation()` 的“绑定会话长时间无可见变化”分支；连接中断、发送歧义、限流、导航保护和验收 repair 的其他有界策略保持不变。

## 明确需求

- `R01`：绑定会话连续 180 秒没有正文、操作按钮、加载、授权或任务状态变化时，刷新同一会话 URL。
- `R02`：刷新后仍无变化时，不受刷新次数上限限制；任务仍可运行时，每经过下一个 180 秒周期继续刷新。
- `R03`：最近一次停滞刷新时间持久化，实际刷新最多每 180 秒发生一次，避免热循环。
- `R04`：保留任务 URL、发送 token、phase、round、附件和“不重复发送”安全边界；暂停、取消、完成、限流、阻塞和发送歧义时不刷新。
- `R05`：旧版本留下的 `stalledRefreshExhausted` 不得继续阻断恢复；升级后应迁移为可继续重试状态。

## 非目标

- 不改变 `connectionInterruptedRefresh()` 的两次上限；那是不同的页面信号和风险边界。
- 不改变最终回复识别、验收 JSON repair、导航许可、Chrome 宿主恢复或 Faliu 卡片流程。
- 不在本机构建、打包、安装或运行应用级 E2E。

## 开源优先调查

- [sindresorhus/p-retry](https://github.com/sindresorhus/p-retry)（MIT）：验证了无限重试应与明确的 delay、最大重试时间或 AbortSignal 配套；本任务采用其“无限尝试 + 可中止等待”的设计启发，但不复制代码、不引入依赖。
- [TanStack Query retryer](https://github.com/TanStack/query/blob/main/packages/query-core/src/retryer.ts)（MIT）：验证了 retry 函数、可配置 retryDelay 及 pause/resume 边界；本任务沿用“每次重试重新判断任务是否仍可运行”的原则。
- 结论：没有必要把通用重试库放入油猴运行时。现有 task 状态、同路由校验和持久化时间戳已经是更小、更兼容的实现边界。

## 验收信号

- 同一任务在第 1、2、3、4 次及以后刷新均可继续执行。
- 任意两次实际停滞刷新间隔不足 180 秒时被拒绝，达到 180 秒时允许下一次。
- 旧 `stalledRefreshExhausted: true` 记录升级后清除该迁移标记并继续刷新。
- 测试确认任务身份、附件、阶段和结果未被刷新逻辑改写，也不产生新的发送动作。
