# Telegram → Fabushi 全量融合项目

这是 Fabushi 通信平台重构与 Telegram 同类能力对标项目的标准化项目资料夹。

## 权威项目位置

- Repository: `bhrumom/fabushi`
- Branch: `main`
- Path: `projects/telegram-fabushi-integration/`

以后所有 Telegram → Fabushi 融合任务都必须从 GitHub `main` 的该目录读取项目基线，并在任务结束前把状态、WBS、验收、变更和证据回写到该目录。Google Drive 与聊天记录仅作为输入或镜像。

## 项目目标

以 **自主协议 + 自建服务 + Rust 核心** 为基础，把成熟 IM 所需的私聊、群组、频道、Topic、媒体、搜索、通知、音视频、Bot/AI Agent、Mini Apps 与支付统一进 Fabushi；Electron、iOS、Android 共享同一套 Rust 通信核心与协议定义，不依赖 Telegram 官方 API 或基础设施。

## 文档分层

- `source/`：原始总计划与不可丢失的需求来源。
- `docs/`：产品、架构、协议、客户端、服务端、安全、测试与验收文档。
- `management/`：路线图、WBS、里程碑、风险、状态与 PR 执行规则。
- `decisions/`：ADR（Architecture Decision Record），记录不可随意漂移的关键架构决策。
- `templates/`：任务、ADR、PR 验收与状态报告模板。

## 执行原则

1. 任何功能必须有唯一模块归属，不新增第二套聊天/联系人/Bot 通道。
2. 功能状态只允许：`NOT_STARTED`、`IN_PROGRESS`、`IMPLEMENTED`、`TESTED`、`E2E_VERIFIED`、`RELEASED`。
3. “存在代码”不等于完成；完成必须同时满足实现、测试、E2E、权限、错误处理、可观测、文档和正式架构归属。
4. 工程事实以 GitHub commit / PR / CI run / release evidence 为准。
5. 源计划是需求基线；若后续决策改变基线，必须新增 ADR 并更新变更日志。

## 建议阅读顺序

`00 项目章程` → `01 范围` → `02 PRD` → `03 系统架构` → `04 领域模型与协议` → `13 测试策略` → `15 路线图` → `19 完成定义` → `management/01-WBS原子任务.md`。

## 2026-09-04 P0 recovery architecture

架构恢复工作使用 Program ID `FAB-ARCH-P0-20260904`。它不创建新项目，继续复用 `FAB-P0001/TFI`，并与 `FAB-P0005/MSR`（唯一 Mahayana Runtime/session）和 `FAB-P0004/GBF`（Bot 行为、同账号设备能力）互相约束。

先读：
- `source/2026-09-04-p0-recovery-architecture.md`
- `docs/2026-09-04-p0-requirements.md`
- `docs/2026-09-04-p0-architecture.md`
- `docs/2026-09-04-p0-testing.md`
- `docs/2026-09-04-p0-release.md`
- `docs/2026-09-04-p0-security.md`
- `management/09-2026-09-04-P0-WBS.md`
- `management/10-2026-09-04-P0-里程碑.md`
- `management/11-2026-09-04-P0-验收追踪.md`
- `management/12-2026-09-04-P0-风险与依赖.md`
- `management/13-2026-09-04-P0-变更日志.md`
- `decisions/ADR-0014-mahayana-bot-miniapp-cross-project-contract.md`
- `evidence/FAB-ARCH-P0-20260904/README.md`

`codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d` 是本轮审计输入，不是已验收状态；其 M6 P0.1 仍按严格审查结果视为拒绝，直到新任务逐项通过代码审查、Actions 和 canonical-main packaged evidence。