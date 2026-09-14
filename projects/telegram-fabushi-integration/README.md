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

`TFI-USERSCRIPT-RECOVERY-011` 已完成 source `v2.9.20`、宿主 `tab-recovery` watchdog 和 GitHub Release/Chrome 包交付：它区分最终 Work 回复与“停止回答”，把 final 传给下一轮验收，并在恢复/继续时保持任务 token、轮次和附件连续。Fabushi Chrome Web Store 的既有 `0.6.0` 草稿已于 `2026-09-14T11:44:35+08:00` 提交审核，当前状态为“待审核”；公开 listing、安装回读、真实崩溃/卡住旅程和完整现场证据仍按 `TFI-USERSCRIPT-RECOVERY-011` / `CWA-008` 跟踪。

## 当前已验证的 Marketplace 交付

`M8-MARKET-003` 已将 Mini App/插件统一为 GitHub-first、油猴式的安装更新路径：市场只发布审核后的版本元数据，客户端按不可变 commit/Release artifact 下载并校验 SHA-256 与 size；Desktop、Chrome、Web、Android、iOS 和 CLI 共用安装、更新、阻止降级与显式回滚语义。官方固定目录中三项损坏/错配历史包已由受控 CI 重新打包为 `1.0.1` 并发布。

- 产品主线：`main@f6a0d99c85a481999298a18cada6a9f10718a360`
- 项目记录主线：PR [#2600](https://github.com/bhrumom/fabushi/pull/2600) 已合并，canonical records `main@b0ac0efb822398b658464ab1b559fd4ca41f004d` 已回读。
- 测试版本：`1.2.65`，GitHub Release [desktop-1.2.65](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65)
- 发布目标：Release target SHA 与上述 canonical main 一致；包含 macOS DMG/ZIP、`latest-mac.yml`、blockmap、Windows/Linux 安装包及 Chrome 包。
- 精确主线交付：Electron `34800013097`、Native mobile `34800013089`、Chrome `34800013075`、post-main `34800500558` 均成功；完整证据索引见 `evidence/M8-MARKET-003/README.md`。

本条只关闭 `M8-MARKET-003` 这一交付子门禁；更广泛的 M8 Mini App 权限、审核、沙箱和跨端能力仍按各自任务记录管理。

## 建议阅读顺序

`00 项目章程` → `01 范围` → `02 PRD` → `03 系统架构` → `04 领域模型与协议` → `13 测试策略` → `15 路线图` → `19 完成定义` → `management/01-WBS原子任务.md`。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-012 任务级控制修复

用户反馈的独立 userscript 工作台问题已拆分为任务级控制：顶部选中任务时只暂停当前任务；设置中保留独立的暂停全部/继续全部；每条当前任务行提供详情、暂停/继续/恢复和安全删除入口。

- source PR [#16](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/16) 已创建，当前 head `53102aad173091cd8629caf4a1e761f7ad2d64d7`。
- source 2.9.21 在本地轻量检查中 `node --check` 通过，userscript regression `108/108` 通过。
- 当前仍为 IN_PROGRESS：PR CI、protected source main、Release 和真实 Chrome 视觉/trace 证据待闭合；本轮没有将新版本标记为已公开上线。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-013 内存感知与宿主回收

本轮将“脚本无法直接释放整个标签页进程内存”的边界落实为双层机制：脚本有界清理自身日志、弱引用和临时资源；Chromium MV3 宿主在安全时机调用标签页卸载能力，激活后沿用既有恢复链路。

- source PR [#17](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/17)（head `3d23d8cc78931dceecb4d647706766470224f81b`）和 host PR [#2607](https://github.com/bhrumom/fabushi/pull/2607) 已创建。
- userscript 2.9.22 本地轻量回归 `111/111` 通过；host 端已加入专用 `tab-memory.request`、安全策略和 `chrome.tabs.discard()` 桥接。
- 当前仍为 IN_PROGRESS：source/host CI、protected main、canonical packaged/Chrome 证据和用户明确的公开发布授权待闭合；本轮没有宣称公开上线。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-013 merge/readback update

source PR [#17](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/17) 已合并，canonical source main 为 `882cadf0cc35d00a29b93450990d758b4034a5c0`，userscript 为 2.9.22。host PR [#2607](https://github.com/bhrumom/fabushi/pull/2607) 已进入父仓库 main，merge SHA 为 `f7f9871b153efbe26d040e68e8d28eea46af2130`；随后发现并修复了运行时消息分发遗漏及 0.6.1 版本门禁同步问题，后续 PR [#2608](https://github.com/bhrumom/fabushi/pull/2608) 当前开放。

任务仍保持 IN_PROGRESS：后续 PR CI/protected merge、exact-main packaged/Chrome 证据和公开发布授权未完成。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-014 Renderer 崩溃保护与发布回读

本轮已将多任务切页的导航控制从 userscript 页面内逻辑提升为 Fabushi Chrome 宿主能力：脚本请求 `tab-navigation-guard` permit，宿主按任务代次、阶段、轮次、goalRevision 校验，并对普通导航执行冷却、in-flight 去重、崩溃/unloaded fail-closed 与有限恢复；脚本继续负责结束会话后的新验收路由和恢复票据。

- userscript PR #19 已合并，v2.9.24 Release 已发布：<https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.24>。
- Fabushi PR #2623 已合并到 `main@b4d2d85fcd510c51d3dce646311d19c81e6c7403`；发布诊断 PR #2624 已合并到 `main@1e63a8cf14697107af62948d713cff120679694f`。
- Chrome 0.6.2 的 exact-main 打包/模拟用户旅程、跨平台安全与 post-main 交付均已通过；证据含步骤截图、完整视频、trace、HTML/report 和日志。
- 当前仍为 IN_PROGRESS：Chrome Web Store 条目已有提交处于审核中，API 返回 `FAILED_PRECONDITION/NOT_UPDATEABLE`，因此未重复取消或覆盖已有审核；当前 Chrome 未打包副本已在用户确认后替换并重载，扩展页与 Service Worker 控制台回读为 0.6.2，旧版备份保留在 `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.4.1-20260914`。
- 权威任务记录：`management/tasks/TFI-USERSCRIPT-RECOVERY-014-renderer-crash-guard.md`。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-014 最终 main 发布与 Chrome 本机回读

- 最终 canonical main 为 `396a842c7e00b8ad7c236d84cabc9230ed88d391`；Chrome exact-main package run `34842044140` 成功，ZIP 为 113355 bytes，SHA-256 `fcb28edd264facb0940bc1a61366954743f72ced557a72ae79cf96e5325b58ce`。
- post-main run `34843041788` 成功，GitHub Release [desktop-1.2.65-396a842c7e00](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65-396a842c7e00) 已绑定该 SHA，并包含 Chrome 0.6.2 包、内容清单和 SHA256SUMS。
- 用户确认后，当前 Chrome 未打包扩展目录已从 v0.4.1 替换为精确 CI 包并重载；扩展详情页与 Service Worker 控制台均回读 v0.6.2。旧版可从 `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.4.1-20260914` 回滚。
- Web Store 仍保持 `IN_PROGRESS / PENDING_REVIEW`：已有提交占用 item，未取消审核，也未把本地未打包扩展升级误报为商店公开发布。

## 2026-09-15 — TFI-USERSCRIPT-RECOVERY-016 公平持续调度与执行器自愈

本轮针对“等待冷却不续做、多个任务不轮换、打开会话即暂停、页面换代后假运行”的用户反馈，采用按任务可运行时间调度的 delayed-set 语义：一个任务的导航保护/退避/发送节流只延迟它自己，其他可运行任务继续轮询；全部延迟时只睡到最早唤醒点。打开已记录会话只写入代际绑定的 inspect ticket，不再改变任务状态。旧页面 Web Lock 短暂存在时，新实例进行有界接管并自动恢复扫描。

- source userscript PR [#22](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/22) 与版本对齐 PR [#23](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/23) 已合并；canonical source main `480ebe61ba039f15e7023bbc0253ea23c373aba0`，Release `v2.9.30`，资产 `224113` bytes / SHA-256 `d15040a5d420b0fa4cc38b195f178143a2d22a166e3357f88c7159c6b7a3b14a`；source CI 已通过。
- parent clean branch 已同步该精确脚本，并将 Chrome 扩展从 canonical `0.6.4` 递增到 `0.6.5`，同时更新 Marketplace 的 sourceRef、版本、大小和哈希；父 PR、protected main、exact-main packaged journey、证据和 Release 仍待完成。
- 任务记录：`management/tasks/TFI-USERSCRIPT-RECOVERY-016-fair-continuous-scheduler.md`；当前状态 `IN_PROGRESS`，不把 source Release 或本地静态检查当作产品交付完成。
