# ADR-0003 — 统一 Conversation / Participant / Message

- **状态**：Accepted
- **日期**：2026-08-22
- **来源**：`../source/完整telegram融合进fabushi.txt`

## Context

满足真人、人与 Agent、Agent 与 Agent 共用消息总线，并消除第二套聊天实现。

## Decision

真人、Agent、Bot、Service 共享统一 Participant；私聊、Agent 会话、群组、频道、Topic 等统一进入 Conversation/Message 模型。

## Consequences

权限和运行环境仍需按 participant 类型隔离，统一模型不等于统一权限。

## Supersedes / Superseded by

无。
