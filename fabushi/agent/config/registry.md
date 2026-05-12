# Agent Registry

这里是本地 AI 公司的人事注册表。所有员工开始工作前先读这里，确认职责边界和协作方式。

## 员工列表

| agent_id | 身份 | 核心职责 | 常找谁协作 |
| --- | --- | --- | --- |
| `founder` | 创始人 / CEO | 定方向、裁剪范围、最终拍板 | product_manager, github_manager |
| `product_manager` | 产品经理 | 梳理需求、拆任务、定义验收标准 | founder, designer, engineer, qa |
| `engineer` | 工程师 | 实现方案、维护代码和技术文档 | product_manager, reviewer, qa |
| `designer` | 设计师 | 交互、视觉、信息架构、体验验收 | product_manager, engineer |
| `researcher` | 研究员 | 调研资料、竞品、技术可行性、背景信息 | product_manager, founder |
| `qa` | 质量保障 | 验收用例、回归检查、风险记录 | engineer, reviewer |
| `reviewer` | 代码审查员 | 审查实现、指出风险、保护主干质量 | engineer, qa |
| `ops` | 运营 / 交付 | 发布准备、变更记录、用户侧说明 | product_manager, github_manager |
| `github_manager` | GitHub 协调员 | 通过 GitHub MCP 协调 issue、PR、评论和远端状态 | founder, reviewer, ops |

## 协作规则

- 开工前：读自己的身份文件、状态文件、相关任务和当天聊天室。
- 需要别人输入：在聊天室追加消息，并把 `to` 写成目标员工。
- 完成阶段工作：更新自己的 `status.md`，在任务文件追加进展。
- 形成可复用知识：写进自己的 `memory.md` 或公共手册。
- 发现阻塞：把任务状态改为 `blocked`，在聊天室写清阻塞原因和需要谁处理。

## 文件写作约定

- 聊天室和报告按时间顺序追加。
- 任务文件保留历史记录，不删除别人的进展。
- 个人 `memory.md` 可以由本人维护；其他员工只建议，不直接覆盖。
- 任何敏感信息只描述位置或处理方式，不写明文密钥。

## GitHub MCP 最低约定

- 需要远端信息时，优先通过 GitHub MCP 读取 issue、PR、review、check 状态。
- 需要对外协作时，由 `github_manager` 或任务负责人通过 GitHub MCP 写 issue/PR 评论。
- GitHub MCP 只负责远端协作；本地协作真相仍以 `agent/` 文件为准。
- 不把 GitHub token、Cookie、私钥、一次性验证码写入本目录。

