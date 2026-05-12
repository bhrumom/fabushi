# Tasks

每个任务一个 Markdown 文件，命名为 `TASK-0001.md`、`TASK-0002.md`。任务文件是协作事实来源，聊天室只承载讨论。

## 状态

- `backlog`: 已记录，尚未开始。
- `doing`: 有员工正在处理。
- `review`: 等待验收、审查或确认。
- `done`: 已完成并记录结果。
- `blocked`: 被外部信息、权限、依赖或决策阻塞。

## 模板

```md
# TASK-0000: 标题

- status: backlog
- owner: product_manager
- reviewers: qa, reviewer
- created: 2026-05-12
- links: agent/chatroom/2026-05-12.md

## Goal

写清任务目标。

## Acceptance Criteria

- 可验证标准 1。
- 可验证标准 2。

## Activity Log

### 2026-05-12 10:30 CST - product_manager

记录关键进展、阻塞或决策。
```

