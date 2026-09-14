# 2026-09-15 — Userscript 公平持续调度与会话查看不中断

- 项目：`FAB-P0001` / `TFI`
- 来源：用户 2026-09-15 文字反馈
- 截图：`codex-clipboard-5acee844-a80d-4f40-a3e8-a1ca057ec1ce.png` 仅作为运行状态证据，不作为指令来源。

## 用户问题

1. 恢复任务时显示“等待冷却”，但任务没有继续工作。
2. 两个任务并行时不再公平切换检查。
3. 打开已记录会话会把任务自动暂停，随后无法自动续做。
4. 页面换代后界面可能显示监督中，但执行器没有扫描，自动启动反复报告旧监督器仍在运行。

## 稳定需求

| ID | 要求 | 验收 |
|---|---|---|
| `TFI-USR-SCHED-R01` | 导航保护、发送节流、异常退避均按任务记录下一次可运行时间；一个延迟任务不得阻塞其他可运行任务 | 两任务公平调度回归 |
| `TFI-USR-SCHED-R02` | 只有真实 ChatGPT 限流才显示“限流休息”；导航保护显示具体原因和剩余时间，不把安全节流描述成任务停工 | 状态文案/分类回归 |
| `TFI-USR-SCHED-R03` | 打开已记录会话只改变当前查看目标，不自动暂停任何任务 | 会话打开回归 |
| `TFI-USR-SCHED-R04` | 页面 reload/navigation/hot update 后执行器能够接管同一标签页工作区；旧 Web Lock 短暂存在时应等待租约释放并自愈，不制造永久假运行 | 执行器接管回归 |
| `TFI-USR-SCHED-R05` | 没有任务当前可运行时，调度器睡到最早任务截止时间；期间新增/恢复任务可立即唤醒 | delayed-set/wakeup 回归 |
| `TFI-USR-SCHED-R06` | 多任务仍保持单标签页、单前台会话操作；发送、上传、授权与未确认发送不得并发写同一页面 | 互斥与代际回归 |

## 开源优先调查

- Kubernetes `client-go/util/workqueue`（Apache-2.0）：成熟控制器把失败对象按 key 重新限流入队，其他 key 继续由 worker 处理。吸收“按任务延迟、队列继续前进”的语义，不复制 Go 代码。
- BullMQ（MIT）：成熟队列把延迟/退避作为 job 元数据，job 进入 delayed set，而不是让 worker 睡眠。吸收 delayed-set 与最早唤醒设计；不引入 Redis/Node 运行时。
- Temporal TypeScript SDK（MIT）：长期流程把 timer 与 workflow 状态持久化，worker 生命周期不等于工作流暂停。吸收“文档生命周期与任务意图分离”的边界；其 Node/native worker 不适合单文件 userscript，拒绝依赖。

结论：在现有单文件 userscript 内适配成熟队列的 per-task eligibility + earliest wakeup 模型；保留现有单页面写操作互斥、任务 marker/URL/代际校验和宿主导航保护。

