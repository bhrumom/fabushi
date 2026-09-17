# 用户需求：Marketplace 识别线上 userscript 最新版本

- 项目：`FAB-P0001` / `TFI`
- 日期：2026-09-15（Asia/Shanghai）
- 来源：用户反馈“并没有识别到新版本”，并附 Fabushi Chrome Marketplace 截图。

## 用户可见现象

截图中的 Marketplace 条目显示 `2.9.28`、GitHub commit `f09e2c5e` 和“已是最新”。但独立 userscript 的 GitHub Release `v2.9.30` 已经发布，导致用户误以为线上发布没有生效。

## 根因

当前 Chrome 扩展的内置 fallback 是旧版本，且公开控制面仍返回桌面 Mini App 的 `1.0.1` 包条目。扩展按版本比较时以旧内置 userscript `2.9.28` 覆盖远端 `1.0.1`，因此不会发现独立 userscript `v2.9.30`。脚本 Release 本身可下载并不等于 Marketplace 已提供同一 runtime 的发现元数据。

此外，旧扩展只在打开 Marketplace 时拉取一次目录，Service Worker 没有持久化的定时检查、action 徽章或启动通知。因此用户看到的“已是最新”可能只是旧 fallback 的局部判断，而不是线上版本的实时结果。

## 目标与约束

1. Chrome `platform=chrome-extension` 的公开目录必须返回独立 userscript 的最新不可变 metadata。
2. 桌面/CLI 继续使用现有 `chatgpt-auto-confirm` Mini App 包，不能被 Chrome userscript 投影改写。
3. 元数据必须固定到公开 GitHub commit、Release URL、SHA-256 和字节数；扩展安装前仍需重新下载并校验。
4. 不把截图文字当作操作指令；截图只作为现象证据。
5. Chrome 扩展必须在启动、打开 Marketplace 和后台定时唤醒时自动检查；发现更新后持久化状态、显示页面提示和 action 徽章，安装仍需用户明确点击。

## 相关现有设计

`TFI-USERSCRIPT-RECOVERY-016` 已完成 userscript v2.9.30 的 source Release、Chrome bundled pin 和 immutable install contract。本任务补齐控制面针对旧扩展的 Chrome-only discovery projection，并补上客户端主动、持续的版本发现。

## 开源优先调查

沿用本项目已记录的 Kubernetes workqueue、BullMQ delayed jobs、Temporal durable timers 调查结论；本轮不引入新的远程依赖。分发侧继续采用 immutable release metadata + client-side digest verification，而不是动态执行未经 pin 的分支代码。

本轮的客户端调度沿用 Chrome MV3 `alarms` 的持久唤醒模型，更新状态使用 `chrome.storage.local` 保存，避免依赖弹窗是否保持打开；页面内刷新仅负责即时反馈，不承担后台唯一职责。

## 用户补充要求（2026-09-15）

用户进一步澄清：这里需要的是“插件自动识别更新”，而不是只在发布页显示一个新版本。验收因此要求实际发布包中的扩展 Service Worker 在没有打开 popup 的情况下也能定期检查线上目录，并在扩展打开后恢复提示；旧版本安装包必须能通过正常 Chrome Web Store 更新到包含该能力的扩展版本。Chrome Web Store 若已有提交处于审核中，不取消或覆盖该提交，记录 `NOT_UPDATEABLE` 阻塞并等待审核完成。

## 用户再次澄清与客户端路径修复（2026-09-15）

用户要求“让插件能够自动识别更新”。进一步回溯发现：桌面 Host 连接存在时，Chrome popup 原先优先使用 Host 的目录，Host 版本落后会继续显示旧的 `2.9.28`。因此 Chrome Marketplace 目录现在优先读取 `https://api.ombhrum.com` 的实时 `platform=chrome-extension` 响应；Host 仅在实时目录暂时失败时兜底，且请求序号会丢弃过期响应，避免旧请求覆盖新目录。后台 Service Worker 的启动/安装/30 分钟检查仍独立运行，不依赖 popup 或 Host。
