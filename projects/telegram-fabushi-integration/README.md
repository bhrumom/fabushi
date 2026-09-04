# Telegram → Fabushi 全量融合项目

这是 Fabushi 通信平台重构与 Telegram 同类能力对标项目的标准化项目资料夹。

## 权威项目位置

- Repository: `bhrumom/fabushi`
- Branch: `main`
- Path: `projects/telegram-fabushi-integration/`

以后所有 Telegram → Fabushi 融合任务都必须从 GitHub `main` 的该目录读取项目基线，并在任务结束前把状态、WBS、验收、变更和证据回写到该目录。Google Drive 与聊天记录仅作为输入或镜像。

## 项目目标

以 **自主协议 + 自建服务 + Rust 核心** 为基础，把成熟 IM 所需的私聊、群组、频道、Topic、媒体、搜索、通知、音视频、Bot/AI Agent、Mini Apps 与支付统一进 Fabushi；Electron、iOS、Android 共享同一套 Rust 通信核心与协议定义，不依赖 Telegram 官方 API 或基础设施。

## 执行原则

1. 任何功能必须有唯一模块归属，不新增第二套聊天/联系人/Bot 通道。
2. “存在代码”不等于完成；完成必须满足任务自身 review/CI/protected-main/post-main packaged evidence 契约。
3. 工程事实以 GitHub commit / PR / CI run / release evidence 为准。
4. 源计划是需求基线；后续决策变化必须记录 ADR/WBS/验收/变更日志。

## 2026-09-04 P0 recovery architecture

Program ID `FAB-ARCH-P0-20260904` 继续复用 `FAB-P0001/TFI`，并与 `FAB-P0005/MSR`（唯一 Mahayana Runtime/session/policy plane）和 `FAB-P0004/GBF`（Bot 行为、同账号设备/App MCP 能力）互相约束。

当前治理审查事实：PR #2320 对 `21ee56892db48925fe863320a1cd68b51c4596cd` 的结论仍是 `REVIEW-REJECTED`；审查回写后起点为 `a0333f32a5d0edc04723c49fc53a5997a3b0fe1e`。本轮修订只是把治理契约修到可重新审查，不代表 `REVIEW-PASS`、CI 通过、合并或发布。执行交接在代码审查组对 PR 最新真实 head 给出新 `REVIEW-PASS` 前保持关闭。

`codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d` 只是审计输入。当前事实包括 `RespondCommunityJoin` optional-event/bool 编译阻断、`service.rs` Community-backed `CreateConversation` 仍直接进入 `UpsertConversation`；相反，无 Community 的 `RequestCommunityJoin` 已返回 `CommunityNotFound`，它现在是必须保持的 regression gate，而非当前未修 defect。

P0 authoritative task files：
- `management/tasks/TFI-M3-P0-001-desktop-first-message-hydration.md`
- `management/tasks/TFI-M6-P0-001-repair-compile-and-community-create-boundary.md`
- `management/tasks/TFI-M6-P0-002-community-canonical-membership-recovery.md`
- `management/tasks/TFI-M6-P0-003-community-admission-authz-negative-contracts.md`
- `management/tasks/TFI-M6-P0-004-recipient-neutral-journal-replay.md`
- `management/tasks/TFI-M6-P0-005-protocol-v3-reader-boundary.md`
- `management/tasks/TFI-M7-P0-001-group-bot-messaging-contract.md`
- `management/tasks/TFI-M8-P0-001-generated-miniapp-open-card.md`
- `management/tasks/TFI-M8-P0-002-install-miniapp-bot-projection.md`

每个任务文件自身就是完整派发契约；WBS/共享文档只能索引，不得补全任务缺失条件。

## Source of truth

See `SOURCE_OF_TRUTH.md`. GitHub `main` and live engineering facts are authoritative.
