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
| ADR-0014 | Event-aware exact-head checkout gate（PR exact head / merge-group current group SHA / fail-closed CI result） | Accepted |

> Review note (2026-09-05): 本轮仅补入当前任务直接依赖的 ADR-0014 索引，不在独立代码审查中重编号或重写既有 ADR-0008–ADR-0013 的历史索引债务；其源文件与 provenance 保持不变。
