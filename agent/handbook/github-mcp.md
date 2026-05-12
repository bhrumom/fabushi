# GitHub MCP Handbook

所有 AI 员工都可以在自己的运行环境中使用 GitHub MCP，但本地协作的事实来源仍然是 `agent/` 目录。

## 最低使用场景

- 读取 issue、PR、review comment 和 CI/check 状态。
- 在 issue 或 PR 里发布进展、问题和验收结果。
- 把远端链接写回任务文件或聊天室。
- 协调代码审查、发布说明和交付状态。

## 推荐流程

1. 先读本地任务文件，确认要查哪个 issue 或 PR。
2. 通过 GitHub MCP 获取远端状态。
3. 把关键结论写回 `agent/tasks/TASK-*.md`。
4. 需要对外同步时，由任务负责人或 `github_manager` 发布 GitHub 评论。
5. 对外动作完成后，把链接写入聊天室或任务文件。

## 禁止事项

- 不把 token、Cookie、私钥、验证码写入仓库。
- 不在没有任务上下文时随意修改 GitHub issue 或 PR。
- 不把 GitHub MCP 查询结果当作唯一真相；本地任务文件必须同步关键结论。
- 不替其他员工删除历史记录。

## 交付记录建议

```md
### 2026-05-12 11:00 CST - github_manager

- remote: https://github.com/owner/repo/pull/123
- action: comment
- result: done

summary:
已在 PR 中同步 QA 验收结果，并把链接写回本任务。
```

