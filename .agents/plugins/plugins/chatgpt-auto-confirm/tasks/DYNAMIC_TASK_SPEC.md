# ChatGPT 自动确认动态任务规范

本文件定义 GitHub Actions 持续运行器的任务控制协议。运行中的 Action 每 30 秒读取 `tasks/actions-inbox.json`，不需要停止、重建或手动续跑当前 Action。

## 控制文件

唯一控制入口：

`.agents/plugins/plugins/chatgpt-auto-confirm/tasks/actions-inbox.json`

顶层字段：

- `schemaVersion`: 当前为 `2`。
- `revision`: 人类可读控制版本。每次改动建议递增。
- `keepAlive`: `true` 时，即使当前任务全部完成，Action 仍继续轮询新任务；本轮 runner 到期后会自动续接下一轮。
- `authoritative`: `true` 时，文件中不存在的未完成任务会被取消。
- `maxConcurrent`: 同时运行的独立 Chat 数，范围 1-4。
- `reviewGate`: 是否让待验收任务阻塞其他任务调度。
- `specificationFiles`: 注入每条任务消息的仓库规范文件。
- `specificationURLs`: 注入每条任务消息的在线规范链接。
- `tasks`: 当前期望任务集合。

## 任务字段

每个任务至少需要：

- `id`: 稳定逻辑任务 ID，只能使用字母、数字、短横线和下划线。
- `goalVersion`: 正整数。任务目标发生任何实质变化时必须递增。
- `title`: 简短标题。
- `prompt`: 当前任务目标。它是可变内容，不再被首次启动输入永久冻结。

可选字段包括：

- `promptTemplate`
- `connector`
- `priority`
- `timeout`
- `maxTaskContinuations`
- `maxRuntimeRetries`
- `dependsOn`
- `resourceLocks`
- `specificationFiles`
- `specificationURLs`

控制器会把逻辑任务 `example` 的第 3 版映射成运行任务 `example--v3`。当 `goalVersion` 从 3 增加到 4 时，只取消旧版 `example--v3`，随后在新的独立 Chat 中派发 `example--v4`。其他正在运行的任务不会停止。

## 动态新增任务

在 `tasks` 数组中追加一个新的对象，并提交到 `main`：

```json
{
  "id": "new-task-20260731",
  "goalVersion": 1,
  "title": "新增任务",
  "prompt": "完成新的任务目标并验证。",
  "connector": "GitHub",
  "priority": 40,
  "dependsOn": [],
  "resourceLocks": ["worktree:new-task"]
}
```

运行中的 Action 会在下一次轮询时调用原生加锁的 `queue_enqueue`，然后按照 `maxConcurrent`、依赖和资源锁并行派发。

## 动态更新已有任务

修改 `prompt` 或任务规范时，同时把 `goalVersion` 加 1。只修改 `revision` 而不提高 `goalVersion`，不会重复执行同一个已存在版本，这是防止重复派发的幂等规则。

## 完成回执

所有工作 Chat，无论完成、未完成或阻塞，最终回复都必须包含一个闭合的机器报告：

```text
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","status":"complete|incomplete|blocked","summary":"本轮实际结果","completed":[],"remaining":[],"blockers":[],"verification":[],"next_connector":"","next_task":""}
MAHAYANA_TASK_REPORT_V1_END
```

完成时必须满足：

- `status` 为 `complete`
- `remaining` 为空数组
- `blockers` 为空数组
- `next_task` 为空字符串

不能只用自然语言说“已完成”。这样小程序不再依赖页面按钮或自然语言启发式判断，也不会把已完成任务再次续发。

## 任务规范传递

ChatGPT 消息框目前不能由本控制器可靠上传本地附件，因此采用等价且可审计的双通道：

1. 消息中列出仓库文件路径，Chat 可通过当前 checkout 读取。
2. 消息中列出 GitHub 在线链接，Chat 可通过 GitHub connector 读取。

每次派发都会明确要求先读取这些规范，并声明当前 `goalVersion` 与规范优先于旧 Chat 内容。
