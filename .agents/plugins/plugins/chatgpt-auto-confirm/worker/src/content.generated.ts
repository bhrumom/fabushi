export const HOME = {
  "schema": "mahayana.miniapp.home.v1",
  "revision": "e59ae943ae4e515ccec5a48ed931189bc1f8401f5617c92ed9cc9653d2396669",
  "app": {
    "id": "chatgpt-auto-confirm",
    "title": "ChatGPT 自动确认",
    "version": "1.0.0+codex.20260723030016"
  },
  "welcome": {
    "id": "welcome",
    "markdown": "欢迎使用 **ChatGPT 自动确认**。\n\n它既能在后台自动确认 ChatGPT 授权卡，也能编排可恢复的任务队列。每个任务都会附带机器可读最终总结；未完成时自动创建新 Chat 续作，完成后会在同一个队列实例的 Chat 页面创建新的验收 Chat。Worker 页面只负责队列和监控，不承载工作或验收；验收 Chat 返回 complete 后队列自动继续，不向用户索要确认。队列默认只启动一个专用 ChatGPT 实例，所有任务和验收 Chat 都复用它，避免每个任务重复启动 Electron 进程；旧版隐藏 target 仍保留为显式兼容回退。\n\n队列、会话引用和审计记录只保存在本机；辅助功能扫描仅作为旧版 ChatGPT 的兼容通道。"
  },
  "tips": [
    {
      "id": "getting-started",
      "revision": "1",
      "markdown": "回复 `/` 可查看当前 MCP Tools。"
    }
  ],
  "quickReplies": [
    {
      "id": "queue-status",
      "label": "查看任务队列",
      "aliases": [],
      "action": {
        "type": "tool",
        "name": "queue_status",
        "arguments": {}
      }
    },
    {
      "id": "prompt-templates",
      "label": "内置任务提示词",
      "aliases": [],
      "action": {
        "type": "tool",
        "name": "prompt_templates",
        "arguments": {}
      }
    },
    {
      "id": "wait-review",
      "label": "等待验收任务",
      "aliases": [],
      "action": {
        "type": "tool",
        "name": "wait_for_review",
        "arguments": {
          "timeout": 60
        }
      }
    }
  ],
  "feed": {
    "items": [
      {
        "id": "guide",
        "revision": "2",
        "kind": "article",
        "title": "使用指南",
        "publishedAt": "2026-07-19",
        "summary": "创建任务队列、并发执行、自动续作并在 Work 中验收。",
        "tags": [
          "指南",
          "任务队列",
          "自动续作"
        ],
        "quickReplies": [],
        "resourceUri": "mahayana://chatgpt-auto-confirm/content/articles/guide"
      },
      {
        "id": "launch",
        "revision": "1",
        "kind": "announcement",
        "title": "小程序上线",
        "publishedAt": "2026-07-19",
        "summary": "欢迎使用这个对话式 MCP 小程序。",
        "tags": [
          "公告"
        ],
        "quickReplies": [],
        "resourceUri": "mahayana://chatgpt-auto-confirm/content/announcements/launch"
      }
    ],
    "nextCursor": null
  }
} as const;
export const RESOURCES: Record<string,string> = {
  "mahayana://chatgpt-auto-confirm/content/announcements/launch": "# 小程序上线\n\n这里是首条公告。",
  "mahayana://chatgpt-auto-confirm/content/articles/guide": "# 使用指南\n\n## 快速开始\n\n1. 用「内置任务提示词」选择实现、诊断、审查或持续完成模板。\n2. 用 `enqueue_tasks` 一次加入多个任务。任务会进入持久队列并默认共用一个专用 ChatGPT 实例；即使请求了更高并发，页面操作也会安全串行，任务完成后的复核也在该实例中新建 Chat。旧版隐藏 target 仍保留为显式兼容回退。\n3. 每个 Chat 的最终回答必须包含 `mahayana.task-report.v1` 总结。若状态为 `incomplete` 或 `blocked`，小程序会根据 `remaining`、`blockers` 和 `next_task` 自动新建 Chat 续作。\n4. 完成项会由程序自动在同一专用实例的新 Chat 中独立验收；验收 Chat 返回 `complete` 后直接启动下一项，不向用户索要确认。`review_task` 仅保留为人工恢复/兼容入口，Worker 页面只展示状态。\n\n## 中断恢复\n\n任务、worker 进程号、会话引用和结果文件都写入本机持久状态。重新调用 `resume_queue` 后，小程序会先接管仍存活的 worker，再处理已经退出但尚未入账的结果，不会从头重复发送。\n\n## 单进程队列安全\n\n用 `dependsOn` 表示先后关系，用 `resourceLocks` 表示不能同时修改的仓库、发布环境或外部资源。队列状态会同时返回请求的并发数和实际执行模式 `single-authenticated-process-serialized`；默认验收门会阻止新一批任务在上一批尚未验收时启动。"
};
