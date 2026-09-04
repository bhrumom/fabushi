# TFI-M6-CHANNELS-001 — 频道、Topic 与管理闭环

- **Project ID**：`FAB-P0001`
- **Project Key**：`TFI`
- **Task ID**：`TFI-M6-CHANNELS-001`
- **状态**：`IN_PROGRESS`
- **开始日期**：2026-09-04
- **更新时间**：2026-09-04

## 目标与来源

完成 M6 的第一条可验收垂直切片：频道订阅/广播、成员与审计分页、Topic 独立未读/草稿、慢速模式、管理员权限和封禁后的访问撤销。

来源：`source/full-plan/part-04.txt`、`source/full-plan/part-05.txt`、`docs/02-产品需求-PRD.md`、`management/wbs/M6.md`。

## 范围

包含：

- Rust `CommunityState` 的 subscriber、admin log、分页模型；
- Rust Protocol v2 命令/事件；
- Rust Engine/Service 的频道 audience、发帖、Topic、慢速模式、成员管理与 actor-scoped projection；
- Electron self-hosted client 的命令封装和事件接收；
- Rust M6 channel/topic contract tests。

不包含：

- Telegram API、MTProto、Telegram 网络或 Telegram 品牌依赖；
- 频道评论关联群的完整产品 UI；
- 移动端原生页面与 packaged cross-device E2E；
- M6 的 protected merge、canonical-main delivery 和 Release（需后续 CI/PR 闭环）。

## 依赖

- M1/M2 Rust core、SQLite/durable journal、WebSocket/auth：已在 canonical main 有记录；
- M4/M5 媒体与群组域：canonical main 有实现，但当前项目矩阵仍需逐项证据回读；
- 本任务的 GitHub Actions current-head、protected merge、canonical-main packaged E2E 是完成前置。

## 验收标准

1. 非参与者订阅频道后可在 snapshot/delta 中收到频道广播；取消订阅或封禁后不再收到。
2. 频道成员/订阅者分页返回有界、稳定 cursor；管理员日志只有 Owner/Administrator 可读。
3. Topic 创建/删除受 `manage_topics` 控制；Topic 消息、独立未读游标、草稿和关闭拒绝均由 Rust 核心执行。
4. 慢速模式由服务端按 sender 的最新消息间隔执行，管理员可配置，违规得到明确 retry 时间。
5. 成员限制/封禁撤销发送与订阅访问；审计记录保留 actor、action、target、reason、timestamp。
6. journal replay 不包含 bearer invite token 或私有 admin log；直接管理员响应和受保护读取仍可工作。
7. CI 在目标 commit 上通过 Rust/Messaging/Portfolio governance；canonical-main packaged/E2E 证据满足项目 §1D 的截图、视频、trace/report 合同。

## 开源优先调查与决策

- [matrix-org/synapse](https://github.com/element-hq/synapse)：采用其自托管 homeserver 的域/同步/运维分层作为架构参考，不复制代码或引入 Matrix 协议；Apache-2.0。
- [element-hq/element-web](https://github.com/element-hq/element-web)：采用其成熟 Messenger/Web/Electron 测试分层思路，不复制 UI；AGPL/GPL/commercial 边界不适合作为 Fabushi runtime 依赖。
- [signalapp/libsignal](https://github.com/signalapp/libsignal)：仅作为 Rust 跨语言密钥生命周期参考；E2EE 依赖仍待 M13 的安全、license 和产品适配审查，不在 M6 引入。

结论：M6 没有可直接兼容 Fabushi Protocol v2、Rust 状态机和 Mahayana Host 边界的现成实现；因此复用上述成熟系统的架构与测试经验，在 Fabushi 自有领域边界内实现，不复制受许可约束的代码。

## 实现与验证记录

- **分支**：`codex/tfi-m6-repair`
- **提交**：`f9316f500`（包含 `a5eb43137`、`f9316f500` 两轮修复，基于最新 `origin/main`）
- **PR**：待创建/受保护合并
- **CI**：待 GitHub Actions
- **实现文件**：`native/mahayana-messaging/src/{community,conversation,protocol,engine,service}.rs`、`desktop/src/{selfhosted-messaging-client-v2,messaging-shell-v2}.ts{,x}`
- **测试文件**：`native/mahayana-messaging/tests/m6_channels_topics_contract.rs`
- **本地检查**：已执行 `git diff --check`；未执行本地编译或测试，遵循仓库磁盘安全规则。

### 2026-09-04 — 网页版极高模型审查与修复

网页版 ChatGPT 审查 `ba4e0c69e` 后返回 `WEB-REJECTED`，指出两项确定编译阻断和多项权限/隐私阻断。网页版随后审查 `dea59a912` 仍返回 `WEB-REJECTED`，补充指出入会策略、成员初始化、legacy thread、双 authority 和 actor journal 污染问题。本轮已继续修复：

- 补齐 `Topic.unread_count` 及 projection 初始化；开放 engine 内部 topic root helper 的 crate 可见性；
- `UpdateCommunity` 不再接受客户端覆盖成员、邀请、Topic、封禁、订阅者和审计日志，并在首次建档时仅由 owner 初始化全量权限；
- 不再允许未知频道被任意订阅并创建空社区状态；
- actor-scoped projection 仅向具备 `invite_members` 权限的 owner/admin 暴露邀请 token；
- journal replay 统一清理历史 invite token、pending join request 和 admin log，避免旧持久化记录泄露。
- 私有频道仅允许公开 admission 或已有 membership/subscription；无 Community 的 join request 不再创建占位状态；首次 Community 从 Conversation participants 构造并保留同 actor 的管理元数据；
- 非 `topic:<id>` 的历史 thread root 保持普通 thread；Community topics 每次完整重建 compatibility projection；journal 写入 canonical Community，replay 按接收 actor 重新投影并重算 Topic unread。

最新提交仍待网页版复审；协议滚动兼容、邀请凭证完整校验、Electron privileged merge、membership mutation 双向收敛和负向契约测试仍未完成。在 CI、PR、protected merge 和 canonical-main packaged E2E/Release 完成前保持 `IN_PROGRESS`。

## 风险、阻塞与下一步

- 当前仍缺 GitHub Actions 实际编译/测试结果、PR 合并、canonical-main packaged E2E visual/debug evidence 和 Release，不能标记 `TESTED` 或 `RELEASED`。
- M6 UI 尚未完成所有 Topic/订阅操作入口，后续应在同一协议上补齐并加入 Electron Playwright 用户旅程。
- 下一步：静态审查后提交本轮变更，触发最窄 Rust/Messaging/Frontend CI；根据 CI 反馈修复，再进入 protected merge 和 canonical-main delivery loop。
