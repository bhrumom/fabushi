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
