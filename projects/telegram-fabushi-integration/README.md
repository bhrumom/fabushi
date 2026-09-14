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

## 当前 userscript 附件连续性子门禁

`TFI-USERSCRIPT-RECOVERY-010` 修复首次带附件发送后，在恢复、继续、异常重发及跨轮次发送中因 composer/document 或 dispatch context 变化而丢失附件的问题。source userscript `v2.9.19` 已发布并通过 98/98 轻量回归；parent records 已通过 PR #2587/#2588 合并并从 `main@baf13113...` 回读，已登录 Chrome 的完整现场证据仍按 task record 跟踪。

## 当前已验证的 Marketplace 交付

`M8-MARKET-003` 已将 Mini App/插件统一为 GitHub-first、油猴式的安装更新路径：市场只发布审核后的版本元数据，客户端按不可变 commit/Release artifact 下载并校验 SHA-256 与 size；Desktop、Chrome、Web、Android、iOS 和 CLI 共用安装、更新、阻止降级与显式回滚语义。官方固定目录中三项损坏/错配历史包已由受控 CI 重新打包为 `1.0.1` 并发布。

- 产品主线：`main@f6a0d99c85a481999298a18cada6a9f10718a360`
- 测试版本：`1.2.65`，GitHub Release [desktop-1.2.65](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65)
- 发布目标：Release target SHA 与上述 canonical main 一致；包含 macOS DMG/ZIP、`latest-mac.yml`、blockmap、Windows/Linux 安装包及 Chrome 包。
- 精确主线交付：Electron `34800013097`、Native mobile `34800013089`、Chrome `34800013075`、post-main `34800500558` 均成功；完整证据索引见 `evidence/M8-MARKET-003/README.md`。

本条只关闭 `M8-MARKET-003` 这一交付子门禁；更广泛的 M8 Mini App 权限、审核、沙箱和跨端能力仍按各自任务记录管理。

## 建议阅读顺序

`00 项目章程` → `01 范围` → `02 PRD` → `03 系统架构` → `04 领域模型与协议` → `13 测试策略` → `15 路线图` → `19 完成定义` → `management/01-WBS原子任务.md`。
