# Mini Apps 平台

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：DOC-10
- **版本**：v1.0
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

目标：在 Fabushi 内提供类似 Telegram Mini Apps 的轻应用体系，但拥有自己的 SDK 和安全模型。

运行形态：
- Web 应用
- Fabushi 内置 Web runtime/WebView
- 由 Bot、Agent、聊天按钮、链接、应用市场启动

Mini App SDK：
- initData/session
- current user
- theme
- viewport
- haptic（移动端）
- openLink
- close
- mainButton
- backButton
- share
- sendMessage
- requestContact（需授权）
- requestLocation（需授权）
- file picker（需授权）
- camera/mic（需授权）
- clipboard（需授权）
- payment
- agent bridge

安全：
- 每个 Mini App 独立 origin
- CSP
- permission manifest
- 用户明确授权
- 权限可撤销
- 敏感 API 二次确认
- token 短时有效
- 防 replay
- 签名 initData
- 沙箱隔离

开发者平台：
- 创建 Mini App
- App ID
- Secret
- 域名绑定
- 权限声明
- 发布版本
- 灰度
- 审核
- 日志
- Webhook


============================================================

## AEO / AI 应用发现层（2026-08-27）

Mini App 的 AI discovery 是 Marketplace 的公开投影，不是新 runtime 或第二个 catalog：

- stable entity：每个 app 固定 `/apps/{slug}/#app`，页面、内容、JSON feed 和 WebMCP 引用同一 `@id`；
- machine knowledge：`/ai/apps.json`、per-app JSON、content feed、answer feed；
- answer intent：自然语言问题页直接回答并关联推荐 app；
- auxiliary text：`llms.txt` 精简导航，`llms-full.txt` 完整 catalog-derived 信息；
- agent interface：WebMCP 提供推荐与能力发现；安装/写入/本地调用仍经过既有 Host 权限；
- crawlability：robots/sitemap/结构化数据与 Cloudflare production probe 共同构成可抓取证据。

应用名称、版本、能力、权限、价格和内容必须继续只在 canonical Marketplace catalog 维护。
