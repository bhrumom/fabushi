# 性能、SLO 与可观测性

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：DOC-14
- **版本**：v1.0
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

## 性能目标

Rust Core：
- idle CPU 近 0
- 本地会话列表加载 < 50ms（合理设备）
- 本地消息分页查询 < 50ms
- 消息发送到本地 optimistic UI < 30ms
- 网络内同区域服务端 ack P50 < 100ms，P95 < 300ms（目标值，需实际基准校准）
- 断线恢复不会阻塞 UI
- 媒体下载与消息同步分优先级

Electron：
- 大会话使用虚拟化
- IPC 批处理/事件聚合
- 避免每条消息跨 IPC 多次 roundtrip
- preload API 类型化
- 大二进制不走 JSON IPC

服务端：
- 无状态 gateway 可扩展
- message shard 可按用户/会话分区
- presence 独立于历史消息
- media 与 message 分离
- backpressure
- rate limit
- tracing


============================================================

## SLO / Observability（项目管理补充）

源计划没有给出正式生产 SLO 预算，因此这里不虚构可承诺 SLA。上线前应基于性能压测建立：

- Gateway 可用性与连接成功率；
- 消息 server ack P50/P95/P99；
- delta sync 成功率、gap recovery 比率；
- 消息重复/丢失率；
- 媒体上传下载成功率与吞吐；
- 推送到达/去重指标；
- 通话 setup time、ICE/TURN 成功率；
- Mini App 权限拒绝率与安全事件；
- 支付 intent 成功/失败/重复 webhook 指标。

每个核心请求至少携带 trace/request ID；日志、metrics、trace 可以关联，但敏感内容必须脱敏。