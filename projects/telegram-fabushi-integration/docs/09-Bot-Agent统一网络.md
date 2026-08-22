# Bot / AI Agent 统一网络

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：DOC-09
- **版本**：v1.0
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

这是 Fabushi 相比 Telegram 必须重点超越的部分。

统一原则：
- Bot 和 AI Agent 都是 Participant。
- 真人联系人和 Agent 在同一联系人/会话框架下。
- Agent 可以拥有头像、状态、权限、能力标签。
- Agent-to-Agent 使用同一消息协议。
- 普通用户消息与工具事件通过类型区分，不污染展示层。

Agent 能力：
- 私聊 Agent
- 群聊 @Agent
- Agent 监听特定事件
- Agent 主动回复
- Agent 调用 MCP/工具
- Agent 发送文件
- Agent 发起 Mini App
- Agent 创建支付请求
- Agent-to-Agent message
- 多 Agent 工作组
- Agent 会话记忆隔离
- Agent 权限与数据域隔离
- 高风险操作确认
- 审计日志

Bot 开发者能力：
- Bot token / app credential
- Webhook
- WebSocket event stream
- command
- inline action
- callback button
- menu
- deep link
- Mini App launch
- payment request

目标：最终把传统 Telegram Bot API 的易用性和 Fabushi AI 原生 Agent 能力融合为一套更强的 Developer Platform。


============================================================