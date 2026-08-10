---
id: guide
revision: '6'
title: 使用指南
publishedAt: 2026-07-19
summary: 在同一实例中创建隐藏任务队列、后台确认会话、自动续作并独立验收。
tags: [指南, 任务队列, 自动续作]
---
# 使用指南

## 快速开始

1. 用「内置任务提示词」选择实现、诊断、审查或持续完成模板。
2. 用 `enqueue_tasks` 一次加入多个任务。任务会进入持久队列，并与通用确认共用同一个已登录的 ChatGPT 实例。每个运行中任务使用独立的隐藏预热页面；无依赖且资源锁不冲突的任务按 `maxConcurrent` 并行执行。
3. 每轮结束都只输出同一个 `mahayana.task-report.v1` 模板。阶段完成使用 `status=incomplete`、`all_tasks_complete=false`；跨 Chat 等待也在同一模板填写 `wait_seconds` 与 `wait_reason`。`completed` 只表示已做事项，不会停止任务。
4. 只有同一模板同时满足 `status=complete`、`all_tasks_complete=true`、`remaining=[]`、`blockers=[]`、`wait_seconds=0`、`next_task=""`，程序才会启动独立验收；验收也满足同样条件后任务才进入终态。`review_task` 仅保留为人工恢复/兼容入口，Worker 页面只展示状态。
5. 每个 Chat 开始时读取立项邮件线程，接收 `1315518325@qq.com` 的新增要求。不会因每轮结束机械发邮件；只有产生可核验的实质进展、任务全部完成，或需要人工提供信息、权限与决策时才回复同一线程。

## 中断恢复

任务、隐藏页面引用、会话引用和结果文件都写入本机持久状态。重新调用 `resume_queue` 后，小程序会先接管仍存活的隐藏页面，再处理尚未入账的结果，不会从头重复发送。

## GitHub Actions 持续运行

点「启动 6 小时 Action」会用本机已登录的 `gh` 刷新三个仓库 Secret：ChatGPT 登录令牌、加密状态密钥和压缩后的初始任务状态。工作流只从 `main` 读取可信实现，在 GitHub 托管的 macOS Runner 安装官方 ChatGPT 应用、恢复登录并继续队列。

每轮在 GitHub 的六小时硬限制前主动停止，使用 AES-256 加密任务状态并上传短期 artifact。若任务尚未完成，本轮使用 `workflow_dispatch` 启动下一轮并传递上一轮 Run ID；完成后停止续作。Action 日志只显示登录恢复结果和任务状态，不输出登录令牌、加密密钥或任务 Secret。

## 单进程并行队列安全

用 `dependsOn` 表示先后关系，用 `resourceLocks` 表示不能同时修改的仓库、发布环境或外部资源。队列状态会同时返回请求并发数、有效并发数、每个活动隐藏页面和执行模式 `single-authenticated-process-multi-hidden-window-parallel`；默认验收门会阻止新一批任务在上一批尚未验收时启动。

## 前台会话不受干扰

自动确认会扫描每个已经加载的 ChatGPT 页面，包括隐藏页面和非当前会话，并直接在原页面处理授权卡。扫描不会选中会话、切换侧栏或激活 ChatGPT。队列的会话恢复、续作和验收只允许发生在同一实例内从未显示的隐藏页面中，不能回退到用户正在输入的页面。
