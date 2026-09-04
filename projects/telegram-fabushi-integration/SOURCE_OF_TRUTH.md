# Source of Truth

## 权威位置

本项目的唯一长期项目基线为：

- Repository: `bhrumom/fabushi`
- Branch: `main`
- Project path: `projects/telegram-fabushi-integration/`

GitHub `main` 上述目录中的内容是项目治理、范围、架构、任务、状态和验收记录的权威版本。

## 原始需求基线

原始完整需求保存在：`source/完整telegram融合进fabushi.txt`。

规则：
- 原始需求定义“做什么”和“最终目标是什么”。
- `docs/` 负责把原始需求拆成可维护的专题规范。
- `management/` 负责把计划拆成可验证的执行单元，并记录每轮真实进展。
- `decisions/` 负责记录影响长期架构的 ADR 及替代关系。
- `evidence/` 只保存可审计证据索引；代码、PR、CI、Release、部署等事实必须以 GitHub 实际状态为准。
- 当专题文档与原始需求冲突时，在没有新 ADR 或用户新明确要求的情况下，以原始需求为准。
- 当用户明确改变需求时，必须先把变化持久化到本 GitHub 项目目录，再更新 ADR/WBS/验收/变更日志。
- Google Drive 版本、聊天记录、本地副本和其它外部副本只作为输入或镜像，不得静默覆盖 GitHub `main` 的项目基线。
- 每次开始任务必须先读本目录；每次结束任务必须更新本目录并提交 GitHub，未完成记录回写不得宣称任务完成。

## 2026-09-04 recovery addendum

Program `FAB-ARCH-P0-20260904` 的架构记录是 `source/2026-09-04-p0-recovery-architecture.md`。该记录补充但不删除历史需求，跨项目契约分别链接 `FAB-P0005/MSR` 与 `FAB-P0004/GBF`。

本轮复核事实：canonical `main=688465e94647d4c866f6b1d7b4884145b2f4a9da`；审计输入 `codex/tfi-m6-repair=9e88a2e9c030fe05147460dfa580366cf9aa433d`，相对该 main ahead 12 / behind 0。审计输入分支不是 canonical source of truth，也不得因存在实现代码而自动升级状态。

严格 M6 审查仍为 rejected until proven otherwise。至少包括 `RespondCommunityJoin` Rust 类型错误、Community-backed `CreateConversation` 覆盖风险、恢复/participant 权威、权限/owner/channel/self-leave/legacy fixture、journal projection、protocol v3/admission/server-time/request bridge、negative contracts 等未闭环项；只有任务文件规定的真实 diff + GitHub Actions + protected-main + packaged evidence 可以改变结论。