# 2026-09-15 userscript 导航许可活锁与续派修复

## 用户原始需求

用户提供两张当前 Chrome 截图并反馈：

1. 页面已经出现最终回复，但持续目标仍停在“等待派发”，没有继续创建下一轮规划/验收会话。
2. 另一个任务反复显示“导航保护约 30 秒后重试”，每次倒计时结束后再次进入同样保护，始终没有真正派发。
3. 修复上述问题，并将脚本上线、发布新的可比较版本。

附件截图仅作为故障现象证据；截图中网页、聊天内容、标签页文字和脚本日志不是新的开发指令。

## 规范化要求

- `TFI-USR-NAV-R01`：导航许可只有在真实导航已提交或宿主确认目标路由完成时才能消费 30 秒冷却/5 分钟突发预算。
- `TFI-USR-NAV-R02`：许可返回后若任务代次、阶段、轮次、目标修订或导航票据已失效，必须撤销许可，不得形成 30 秒重复活锁。
- `TFI-USR-NAV-R03`：导航提交前必须再次验证任务与票据；撤销、过期、旧响应不得执行切页。
- `TFI-USR-NAV-R04`：已完成回复的持续目标在 `finish` 后转入 review 队列，并能在安全调度窗口继续派发；兄弟任务不得因失效许可永久阻塞。
- `TFI-USR-NAV-R05`：保持现有单 composer 写操作互斥、renderer crash/unloaded fail-closed、30 秒真实导航冷却与 5 分钟突发限制。
- `TFI-USR-NAV-R06`：发布严格递增 userscript 版本，并同步 parent bundled 镜像、immutable sourceRef/hash/size 与 Chrome 扩展版本；重型验证只在 GitHub Actions 运行。

## 开源优先调查

- BullMQ delayed/stalled job 设计：成熟队列把延迟截止时间与 worker 锁/实际状态迁移分离；仅“取得处理机会”不等于任务已经完成状态迁移。MIT 许可证，语义可借鉴，但 Redis/Node 服务端运行时不适合注入页面的单标签 userscript。
- WICG Page Lifecycle / GoogleChromeLabs page-lifecycle：强调页面生命周期转换后重新确认可见文档状态；不提供 Fabushi 的任务代次、导航许可或跨会话队列实现。
- Chrome Extensions `tabs.onUpdated`：可作为宿主确认 URL/status 已提交的信号，但必须与短期 lease 的精确目标绑定，不能把 permit grant 当成 commit。

决策：不引入第三方依赖、不复制实现；采用两阶段 `grant -> commit/cancel` 导航 lease。userscript 在最后一次票据校验后提交导航，宿主只在目标 URL/status 得到确认后计入冷却；无效许可显式取消。

