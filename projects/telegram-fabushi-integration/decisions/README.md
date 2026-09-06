# Architecture Decision Records

ADR 用于记录会长期影响代码结构、协议或平台边界的决策。已接受 ADR 不应被“顺手改代码”绕过；改变时应新增 superseding ADR。

| ADR | 决策 | 状态 |
|---|---|---|
| ADR-0001 | Rust First 核心 | Accepted |
| ADR-0002 | 自主协议 + 自建服务，不依赖 Telegram API/基础设施 | Accepted |
| ADR-0003 | 真人/Bot/Agent 使用统一 Conversation/Participant/Message | Accepted |
| ADR-0004 | Local-First + 增量同步 | Accepted |
| ADR-0005 | AI Agent 是通信网络一等公民 | Accepted |
| ADR-0006 | Mini App 使用权限清单、签名上下文和沙箱 bridge | Accepted |
| ADR-0007 | 支付采用 PaymentIntent + Provider Adapter + Ledger | Accepted |
| ADR-0013 | canonical version required-gate bootstrap 在 guard-only 无法穿越既有 drift 时必须以同一 exact-head 原子事务完成 | Accepted |
| ADR-0014 | canonical version gate 按事件显式绑定 checkout 身份：pull_request=exact PR head，merge_group=current group SHA | Accepted |
| ADR-0015 | post-merge deterministic iOS fixture、exact evidence provenance 与 packaged OWNERSHIP proof 分离为三个 fail-closed capability | Accepted |
