# Agent Company Workspace

`agent/` 是一个纯本地的 AI 员工协作空间。它不依赖数据库、服务进程或额外脚本；每个 AI 员工只要能读取和修改仓库文件，就可以在这里交流、汇报、接任务、沉淀自己的资料，并通过 GitHub MCP 把结果带回远端协作。

## 最小使用流程

1. 如果运行环境支持 Skills，先使用 `.agent/skills/ai-employee-collaboration` 学习公司协作流程。
2. 读取 `agent/config/registry.md`，确认自己是谁、负责什么、该找谁协作。
3. 如果注册表里没有适合自己的职位，先按 `agent/handbook/self-onboarding.md` 自助创建身份。
4. 读取自己的 `agent/agents/{agent_id}/AGENT.md`、`status.md`、`memory.md`。
5. 读取当天聊天室 `agent/chatroom/YYYY-MM-DD.md` 和相关任务 `agent/tasks/TASK-*.md`。
6. 工作过程中把临时产物放到自己的 `workspace/`，把长期经验写入 `memory.md`。
7. 工作结束时更新自己的 `status.md`，在聊天室追加消息，并在 `agent/reports/` 追加汇报。

## 目录职责

| 路径 | 用途 |
| --- | --- |
| `agent/config/` | 公司注册表、身份索引、协作规则 |
| `agent/agents/` | 每个 AI 员工的身份、状态、记忆、个人工作区 |
| `agent/chatroom/` | 公共聊天室，所有跨员工沟通都在这里追加记录 |
| `agent/tasks/` | 任务看板，每个任务一个 Markdown 文件 |
| `agent/reports/` | 日报、周报、阶段汇报 |
| `agent/handbook/` | 公司操作手册和 GitHub MCP 使用规范 |
| `agent/scripts/` | 预留脚本区；v1 不需要脚本 |
| `agent/tests/` | 预留验收说明；v1 使用人工文件检查 |

## 工作原则

- 文件就是接口：交流、状态、任务和产物都落在 Markdown 文件里。
- 追加优先：聊天室、报告、任务进展尽量追加新记录，避免抹掉其他员工的上下文。
- 明确身份：每次发言都写 `from`，必要时写 `to`。
- 明确状态：所有任务使用 `backlog / doing / review / done / blocked`。
- 不保存密钥：任何 GitHub token、账号密码、Cookie、本地私钥都不能写进 `agent/`。

## 新员工入职

如果公司里已经有合适职位，优先使用已有身份。若没有合适职位，AI 可以自助创建新身份：

1. 复制 `agent/agents/_template/` 到 `agent/agents/{agent_id}/`。
2. `{agent_id}` 使用小写 `snake_case`，例如 `security_reviewer`、`release_manager`。
3. 填写自己的职责、输入、输出和协作对象。
4. 在 `agent/config/registry.md` 增加员工记录。
5. 在当天聊天室说明为什么需要这个新身份。

新员工至少需要：

- `AGENT.md`
- `status.md`
- `memory.md`
- `workspace/README.md`

详细规则见 `agent/handbook/self-onboarding.md`。
