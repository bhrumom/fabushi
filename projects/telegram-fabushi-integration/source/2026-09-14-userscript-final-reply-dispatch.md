# 2026-09-14 用户反馈：结束识别、发送超时与任务暂停

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-014`
- 来源：用户在 2026-09-14 提交的现象反馈及截图。截图只作为现象证据，不作为额外指令。

## 原始问题

两个持续任务并行运行并轮换 ChatGPT 页面时，用户观察到一个任务显示“等待派发”、另一个任务显示“已暂停”，且 ChatGPT 页面出现“消息发送超时，请重试”。用户要求：识别到会话结束后继续派发下一轮；发送超时可恢复；页面切换/错误期间不因脚本逻辑误暂停任务；完成后发布脚本和 Chrome 宿主新版本。

## 已确认的语义

1. “等待派发”是结束后的跨会话安全节流，当前为 60 秒，用于保护 ChatGPT renderer；它不是最终回复识别失败。
2. “已暂停当前任务，正在打开已记录会话”来自人工点击“打开已记录会话链接”的查看路径。宿主保护切页只暂缓导航，不写入任务级 paused；发送超时恢复也不调用 pause。
3. v2.9.25 修复了稳定最终回复标记无法闭合的问题，但旧版发送超时检测排除所有 assistant message，因此嵌套在 assistant 错误卡片内的真正错误未被恢复。

## 归一化验收要求

- 可见页面级发送超时继续触发恢复。
- assistant 错误卡片中的发送超时仅在附近有可见“重试”控件时触发恢复。
- 用户/assistant 引用文字、Fabushi 日志和没有重试动作的普通文本不得触发重复发送。
- 发送超时进入 queued/持久化退避恢复，不得自动改为 paused。
- 人工打开历史会话的暂停日志必须明确说明用户动作和恢复入口。
- source 与 bundled userscript、Chrome Marketplace pin 和版本元数据必须一致，且先通过 GitHub Actions 的 Chrome package/模拟用户门禁再发布。

## 关联记录

- Source PR #21 / Release v2.9.26
- Parent PR #2628 / Chrome 0.6.4
- `TFI-USERSCRIPT-RECOVERY-014` task record and management acceptance matrix
