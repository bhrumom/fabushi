---
id: guide
revision: '2'
title: 使用指南
publishedAt: 2026-07-19
summary: 创建任务队列、并发执行、自动续作并在 Work 中验收。
tags: [指南, 任务队列, 自动续作]
---
# 使用指南

## 快速开始

1. 用「内置任务提示词」选择实现、诊断、审查或持续完成模板。
2. 用 `enqueue_tasks` 一次加入多个任务。任务会进入持久队列并默认共用一个专用 ChatGPT 实例；即使请求了更高并发，页面操作也会安全串行，任务完成后的复核也在该实例中新建 Chat。旧版隐藏 target 仍保留为显式兼容回退。
3. 每个 Chat 的最终回答必须包含 `mahayana.task-report.v1` 总结。若状态为 `incomplete` 或 `blocked`，小程序会根据 `remaining`、`blockers` 和 `next_task` 自动新建 Chat 续作。
4. 完成项会由程序自动在同一专用实例的新 Chat 中独立验收；验收 Chat 返回 `complete` 后直接启动下一项，不向用户索要确认。`review_task` 仅保留为人工恢复/兼容入口，Worker 页面只展示状态。

## 中断恢复

任务、worker 进程号、会话引用和结果文件都写入本机持久状态。重新调用 `resume_queue` 后，小程序会先接管仍存活的 worker，再处理已经退出但尚未入账的结果，不会从头重复发送。

## 单进程队列安全

用 `dependsOn` 表示先后关系，用 `resourceLocks` 表示不能同时修改的仓库、发布环境或外部资源。队列状态会同时返回请求的并发数和实际执行模式 `single-authenticated-process-serialized`；默认验收门会阻止新一批任务在上一批尚未验收时启动。
