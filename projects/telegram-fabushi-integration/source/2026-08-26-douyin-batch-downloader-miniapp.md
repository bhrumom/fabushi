# 2026-08-26 — 抖音批量无平台水印下载小程序

## 原始需求

用户要求把本轮已验证的抖音公开作品无平台水印下载方法做成 Fabushi 小程序，上线到现有 Mini Apps 市场，并支持批量下载。

## 2026-08-26 需求补充：独立、可安装、可迁移

用户进一步明确：该能力不能继续作为 `ai-backend` 内置功能存在，必须成为一个独立 Mini App，可通过 Marketplace 安装，并可迁移到其它兼容的 Fabushi / Mahayana Host。

归一化要求：

- 继续复用现有 `FAB-P0001 / TFI` 的 M8 Mini Apps，不创建第二个项目或第二套市场。
- 小程序 ID 固定为 `douyin-batch-downloader`。
- 应用专属解析/下载运行时不得位于 `ai-backend/src/`，平台后端只保留通用 Marketplace registry/release/install contract。
- 可迁移单位为版本化 Mini App package + immutable release metadata + SHA-256；兼容 Host 通过 `mahayana.external-release.v1` 下载、校验并安装。
- 小程序必须声明并提供 GUI、CLI 与本地 MCP stdio 入口；Bot/自然语言最终路由到这些统一能力，而不是依赖一个专属平台 HTTP 路由。
- 当前 Fabushi 分发模型允许 package 使用 Mahayana 的共享、版本化 `official-miniapps` runtime。这里的“独立”指不依赖 Fabushi `ai-backend` 应用专属代码，可在兼容 Mahayana Host 上重新安装/迁移；不宣称它是脱离 Fabushi/Mahayana 生态即可单独启动的完全自包含二进制。
- 用户输出目录、下载结果和 manifest 是运行数据，不绑定仓库绝对路径；迁移后可以在新 Host 重新安装同一 package 后继续使用。

## 功能范围

- 支持抖音公开 `jingxuan?modal_id=...`、`/video/<aweme_id>` 与公开短链接/分享文本。
- 支持批量输入、去重、失败隔离、重试与限速；默认批量上限由本地 runtime 管理并允许受控配置。
- “无平台水印”定义为：选择公开页面/元数据暴露的 clean playback candidate，排除 `playwm` / `watermark=1` 等已标识水印流；不通过裁切、遮挡、重编码或图像修复去除已烧录水印。
- 下载只允许 HTTPS Douyin / ByteDance 媒体域名白名单，并限制单文件最大字节数。
- 下载完成记录文件大小、SHA-256 与批次 `manifest.json`。
- 可选 Cookie 只能由用户显式传入、指定 cookie file 或环境变量；不得读取用户常用浏览器 Cookie。
- 仅面向用户有权访问/保存的公开内容，不绕过登录、验证码、DRM、付费墙或私密访问控制。

## 独立分发结构

- Marketplace package：`marketplace/packages/douyin-batch-downloader/1.0.0/`
- Mahayana / CLI descriptor：`.agents/plugins/plugins/douyin-batch-downloader/.mahayana/plugin.json`
- MCP descriptor：`.agents/plugins/plugins/douyin-batch-downloader/.mcp.json`
- 插件元数据：`.agents/plugins/plugins/douyin-batch-downloader/.codex-plugin/plugin.json`
- 本地共享 Runtime provider：`third_party/mahayana/mahayana-rs/providers/official-miniapps/`
- Marketplace catalog 只发布 immutable package URL + SHA-256/size，不承载 Downloader 专属后端运行时。

## 验收要求

1. Marketplace 搜索“抖音”可发现 `douyin-batch-downloader`，release 为 `installMode=package`。
2. `marketplace/packages/douyin-batch-downloader/1.0.0/app.tar.gz` 的 SHA-256 与 Marketplace release metadata 一致，并可由 Mahayana installer 验证。
3. `fabushi-miniapp.json` 声明 GUI / MCP / CLI / 本地模式；`.mcp.json` 提供 stdio MCP；`.mahayana/plugin.json` 提供 CLI runtime。
4. 应用专属运行时不再嵌入 `ai-backend/src/douyin_downloader.js`，Marketplace HTTP 层也不得注册 Downloader 专属 routes。
5. Rust local runtime 有 `resolve` 与 `download` 两个可验证工具，支持批量、重试、限速、域名白名单、大小限制、安全文件名和 SHA-256 输出。
6. 给定 `https://www.douyin.com/jingxuan?modal_id=7491613333141900602` 的作品 ID 结构可以识别；运行时拒绝非 Douyin HTTPS source 和非允许媒体 Host。
7. current-head GitHub CI 必须通过独立 package boundary、Rust fmt/test/build、Marketplace search/install contract 和 package digest 检查。
8. PR 必须进入 protected `main`；之后按仓库 post-main gate 完成 packaged E2E、截图/视频/trace 与 Release 证据后才能把任务标记为 COMPLETED。

## 开源优先调研

- 参考 `yt-dlp/yt-dlp` 的站点 extractor 分层：平台解析与下载传输分离，把站点变化限制在 adapter/runtime 层。
- 参考公开 Douyin parser 的 `aweme_id -> public playback source` 思路，但不直接复制第三方实现源码。
- Fabushi 保留自己的 package/release contract、HTTPS/host allowlist、批量限流、错误模型、MCP/CLI descriptor 和 Mahayana 安装边界。
