# ADR-0008 — 固定 Fabushi Messaging Core，冻结旧 Telegram 栈

- **状态**：ACCEPTED（待 PR 合并成为 main 权威事实）
- **日期**：2026-08-22
- **项目**：FABUSHI-TELEGRAM-FUSION

## Context

仓库同时存在新的 `native/mahayana-messaging` 自建消息域，以及历史 `native/telegram-*`、`mahayana-telegram`、`providers/telegram-*` 实现。如果不固定边界，后续功能可能继续进入两套状态机/网络栈，违背“自主协议、自建服务、真人/Bot/Agent 统一消息内核”的项目目标。

PR #1961 已把自建消息核心、Electron Messenger V2、Feature Host bridge、统一 Actor/Conversation/Message 和大量 Telegram-class 产品能力合并进 `main`，因此无需再创建一套平行 Rust chat core。

## Decision

1. `native/mahayana-messaging/` 是 Fabushi 唯一 canonical Messaging Core。
2. `native/telegram-*`、`third_party/mahayana/mahayana-rs/mahayana-telegram/`、`third_party/mahayana/mahayana-rs/providers/telegram-*` 全部标为 **LEGACY/FROZEN**。
3. LEGACY/FROZEN 路径不得接受新产品功能，只允许：依赖拆除、数据/协议迁移、兼容性修复、删除准备、安全修复。
4. Electron、iOS、Android 必须通过共享 Rust Core / Host bridge / UniFFI 或等价统一边界使用同一协议和状态机。
5. canonical wire schema 暂以 `native/mahayana-messaging/src/protocol.rs` 的版本化 Serde protocol v2 为准；未来 protobuf/UniFFI IDL 必须由 canonical schema 驱动或具备自动双向兼容测试。
6. M14 只有在依赖为零、数据迁移完成、CI/E2E 证明无 fallback 后，才能删除 LEGACY/FROZEN Telegram 路径。

## Consequences

### Positive

- 防止继续出现双聊天栈、双联系人、双 Bot/Agent channel。
- 当前已合并的自建 Rust 能力成为后续迭代基础。
- Telegram 仅保留 UX/feature reference 角色，不再成为产品核心后端。

### Negative / cost

- 旧 Telegram crates 暂时仍占据仓库和 CI 复杂度。
- 部分旧 social/AI adapter 必须逐步迁移到统一 MessagingService。
- M14 删除前需要严格的依赖图和迁移证明。

## Alternatives rejected

- **重新按 `crates/fabushi-*` 目录重写一遍**：会复制现有 `native/mahayana-messaging` 的业务状态机，制造第二套实现。
- **继续把 Telegram provider 当兼容后端长期保留**：违反自主协议/自建服务目标，并阻碍 M14。

## Verification

- GitHub `main` 存在 `native/mahayana-messaging` 且 PR #1961 已合并。
- GitHub `main` 仍存在旧 `native/telegram-*` 与 `providers/telegram-*` 路径。
- 项目 feature matrix/WBS/状态报告必须引用本 ADR，后续新增通信功能的 PR 必须落入 canonical domain。
