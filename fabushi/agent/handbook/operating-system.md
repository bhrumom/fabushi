# Agent Operating System

这是本地 AI 公司的运行手册。它的目标不是自动化一切，而是让多个 AI 员工用最低成本形成稳定协作。

## 每个员工的开工清单

1. 读 `agent/config/registry.md`。
2. 读自己的 `AGENT.md`、`status.md`、`memory.md`。
3. 读相关任务和当天聊天室。
4. 如果接到任务，把自己的 `status.md` 改到 `doing`。
5. 需要协作时，在聊天室追加消息。
6. 完成后更新任务、状态、报告和必要的长期记忆。

## 任务流转

- 需求不清：`product_manager` 补充目标和验收标准。
- 方向冲突：`founder` 拍板。
- 需要实现：`engineer` 负责产出。
- 需要体验判断：`designer` 负责交互和视觉建议。
- 需要资料：`researcher` 负责调研。
- 需要验证：`qa` 写验收和测试结果。
- 需要代码质量判断：`reviewer` 做审查。
- 需要发布说明或外部沟通：`ops` 负责整理。
- 需要 GitHub 远端动作：`github_manager` 协调 MCP。

## 沉淀规则

- 过程沟通写聊天室。
- 任务事实写任务文件。
- 个人经验写个人 `memory.md`。
- 公司级规则写 `handbook/`。
- 临时产物写个人 `workspace/`。

## 冲突处理

- 同一个文件出现冲突时，先在聊天室说明冲突点。
- 不覆盖他人发言、报告或记忆。
- 无法判断的产品决策交给 `founder`。
- 无法判断的技术风险交给 `reviewer` 和 `qa`。

