# Self-Onboarding Handbook

当一个 AI 进入 `agent/` 后，如果发现公司里没有适合自己的职位，可以按本手册创建新身份。目标是让新员工能立刻工作，同时保持公司角色清晰、可审计。

## 什么时候需要创建新身份

- 现有员工职责明显不覆盖当前任务。
- 当前任务需要长期复用的新能力，例如安全审查、发布管理、数据分析。
- 使用现有身份会让职责混乱，影响后续协作。

如果只是一次性的子任务，优先借用最接近的现有身份，并在聊天室说明临时职责。

## 创建步骤

1. 选择一个唯一的 `agent_id`，使用小写 `snake_case`，例如 `security_reviewer`。
2. 复制 `agent/agents/_template/` 到 `agent/agents/{agent_id}/`。
3. 填写 `AGENT.md`：写清 role、mission、responsibilities、inputs、outputs、collaboration。
4. 填写 `status.md`：写当前状态、任务、阻塞、下一步。
5. 填写 `memory.md`：写这个身份的工作原则和长期记忆。
6. 填写 `workspace/README.md`：说明个人工作区存什么。
7. 在 `agent/config/registry.md` 的员工列表增加一行。
8. 在当天 `agent/chatroom/YYYY-MM-DD.md` 追加一条自助入职消息。
9. 如有任务相关性，在对应 `agent/tasks/TASK-*.md` 的 Activity Log 里记录。

## 自助入职消息模板

```md
## 2026-05-12 11:30 CST

- from: security_reviewer
- to: all
- topic: self-onboarding
- status: info
- links: agent/agents/security_reviewer/AGENT.md

message:
公司现有职位没有覆盖安全审查职责。我已创建 `security_reviewer` 身份，负责安全风险、敏感信息和权限边界检查。
```

## 质量要求

- 新身份必须有明确职责边界，不能只写一个名字。
- 新身份必须能说清常找谁协作。
- 新身份不能保存密钥、token、Cookie、验证码或私钥。
- 新身份创建后必须更新注册表，否则其他员工找不到它。
- 如果职责只临时存在，在 `status.md` notes 标记 `provisional`，并写明何时删除或合并。

