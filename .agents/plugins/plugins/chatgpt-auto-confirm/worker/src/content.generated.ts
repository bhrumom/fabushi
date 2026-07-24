export const HOME = {
  "schema": "mahayana.miniapp.home.v1",
  "revision": "39b83b0cd733b7a1667d37d5704caadb894db13cc69ed91ca83fcde19315a2ae",
  "app": {
    "id": "chatgpt-auto-confirm",
    "title": "ChatGPT 自动确认",
    "version": "1.0.0+codex.20260723053507"
  },
  "welcome": {
    "id": "welcome",
    "markdown": "欢迎使用 **ChatGPT 自动确认**。\n\n它既能在后台自动确认 ChatGPT 授权卡，也能编排可恢复的任务队列。自动确认会原地扫描所有已经加载的 ChatGPT 页面，包括隐藏窗口和非当前会话，不激活应用、不抢焦点、不切换侧栏。每个任务都会附带机器可读最终总结；未完成时自动创建新 Chat 续作，完成后会在队列自己的 Chat 页面创建新的验收 Chat。\n\n通用确认和任务队列始终共用同一个已登录的 ChatGPT 实例。队列通过 ChatGPT 自带的 `show:false` 预热机制持有一个从未显示、从不获取焦点的隐藏页面，任务、续作和验收只在这个隐藏页面串行操作；不会新开第二个 ChatGPT 实例，也不会把你刚打开的新聊天切回任务会话。队列、会话引用和审计记录只保存在本机；辅助功能扫描仅作为旧版 ChatGPT 的兼容通道，而且只会处理当前前台窗口中真正可见的授权卡，绝不点击隐藏会话里的辅助功能元素。"
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
        "revision": "4",
        "kind": "article",
        "title": "使用指南",
        "publishedAt": "2026-07-19",
        "summary": "在同一实例中创建隐藏任务队列、后台确认会话、自动续作并独立验收。",
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
  "mahayana://chatgpt-auto-confirm/content/articles/guide": "# 使用指南\n\n## 快速开始\n\n1. 用「内置任务提示词」选择实现、诊断、审查或持续完成模板。\n2. 用 `enqueue_tasks` 一次加入多个任务。任务会进入持久队列，并与通用确认共用同一个已登录的 ChatGPT 实例。队列页面由 ChatGPT 内部的隐藏预热机制创建，从未显示也不会获得焦点；即使请求了更高并发，页面操作也会安全串行。\n3. 每个 Chat 的最终回答必须包含 `mahayana.task-report.v1` 总结。若状态为 `incomplete` 或 `blocked`，小程序会根据 `remaining`、`blockers` 和 `next_task` 自动新建 Chat 续作。\n4. 完成项会由程序自动在同一实例的隐藏页面中新建 Chat 独立验收；验收 Chat 返回 `complete` 后直接启动下一项，不向用户索要确认。`review_task` 仅保留为人工恢复/兼容入口，Worker 页面只展示状态。\n\n## 中断恢复\n\n任务、隐藏页面引用、会话引用和结果文件都写入本机持久状态。重新调用 `resume_queue` 后，小程序会先接管仍存活的隐藏页面，再处理尚未入账的结果，不会从头重复发送。\n\n## 单进程队列安全\n\n用 `dependsOn` 表示先后关系，用 `resourceLocks` 表示不能同时修改的仓库、发布环境或外部资源。队列状态会同时返回请求的并发数和实际执行模式 `single-authenticated-process-hidden-prewarm-serialized`；默认验收门会阻止新一批任务在上一批尚未验收时启动。\n\n## 前台会话不受干扰\n\n自动确认会扫描每个已经加载的 ChatGPT 页面，包括隐藏页面和非当前会话，并直接在原页面处理授权卡。扫描不会选中会话、切换侧栏或激活 ChatGPT。队列的会话恢复、续作和验收只允许发生在同一实例内从未显示的隐藏页面中，不能回退到用户正在输入的页面。"
};
