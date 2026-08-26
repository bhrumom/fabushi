# M8-DL-001 — 抖音批量无平台水印下载小程序

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-DL-001`
- **Stage**: `M8 Mini Apps`
- **Status**: `TESTING`
- **Started**: `2026-08-26`
- **Updated**: `2026-08-26`
- **Branch**: `feat/tfi-douyin-batch-downloader-miniapp`
- **Canonical PR**: `#2141`
- **Source requirement**: `../../source/2026-08-26-douyin-batch-downloader-miniapp.md`

## Objective

把已经验证的抖音公开作品 clean playback 下载能力从平台内置后端拆出，交付为 **独立、可安装、可迁移的 Fabushi Mini App**：Marketplace 只负责发现/release，Mahayana Host 安装并运行 package；同一 Mini App 同时具有 GUI、MCP、CLI 和默认 Bot 路由能力。

## Current implementation

### Portable package

- `marketplace/packages/douyin-batch-downloader/1.0.0/app.tar.gz`
  - versioned install artifact；
  - expected SHA-256: `9b7aa85b751755cc776a884afba2927ceb661d7580c8b135826bc8760cc6ba75`；
  - Marketplace release metadata 使用 immutable GitHub source + digest/size。
- `marketplace/packages/douyin-batch-downloader/1.0.0/fabushi-miniapp.json`
  - protocol `fabushi.miniapp.package.v1`；
  - 声明 `GUI / MCP / CLI / 本地` modes；
  - 入口 `index.html`。

### Mini App descriptors

- `.agents/plugins/plugins/douyin-batch-downloader/.mahayana/plugin.json`
  - CLI runtime：`./runtime/cli/fabushi-plugin-cli --plugin douyin-batch-downloader`；
  - shared WASM runtime descriptor；
  - tools: `resolve`, `download`。
- `.agents/plugins/plugins/douyin-batch-downloader/.mcp.json`
  - 本地 stdio MCP：`fabushi-plugin-cli --plugin douyin-batch-downloader mcp-serve`。
- `.agents/plugins/plugins/douyin-batch-downloader/.codex-plugin/plugin.json`
  - 插件身份/分发元数据。

### Local runtime

- `third_party/mahayana/mahayana-rs/providers/official-miniapps/src/douyin_downloader.rs`
  - 批量输入、去重、限速、重试；
  - Douyin HTTPS source allowlist；
  - Douyin/ByteDance media HTTPS allowlist；
  - clean playback candidate 选择并排除 `playwm` / `watermark=1`；
  - 安全文件名、最大文件大小、临时 `.part` + atomic finalize；
  - 下载完成输出 bytes / SHA-256 / batch `manifest.json`；
  - 可选 Cookie 仅允许显式参数、cookie file 或 `DOUYIN_COOKIE`，不读取浏览器 Cookie。

### Platform decoupling

Downloader 专属 `ai-backend/src/douyin_downloader.js` 和对应 backend test 已删除；`ai-backend/src/miniapp_marketplace_http.js` 已恢复为纯通用 Marketplace router，不再挂载 Downloader 专属 `/resolve`、`/batch`、`/media` routes。平台后端只通过通用 Marketplace catalog/release/install contract 认识该应用。

这意味着迁移单位是：**Mini App package + descriptor + compatible Mahayana shared runtime**。它不依赖 Fabushi ai-backend 的应用专属实现，可以在其它兼容 Fabushi/Mahayana Host 上重新安装同一 immutable release。它不是脱离 Mahayana Host 即可独立启动的完全自包含二进制，这一点不做虚假承诺。

## Architecture / install flow

`Marketplace search -> mahayana.external-release.v1 -> immutable app.tar.gz + SHA-256 -> Feature Host / Plugin Installer -> local GUI / CLI / MCP -> shared official-miniapps Rust runtime`

Bot/自然语言和 slash command 应路由到同一 Mini App tool surface，而不是建立第二份解析器。

## Governance correction

并行实现 PR `#2136` 已作为 feeder 实现合并进本任务 feature branch，吸收其 portable package、MCP/CLI descriptor 和 Rust runtime。它曾错误创建重复 `FAB-P0009 / DBD` 项目；本任务已删除全部 `projects/douyin-batch-downloader-miniapp/**` 记录，并将 `projects/PORTFOLIO.json` 恢复到 canonical main 的 P0001-P0008 / `next_sequence=9`。本工作唯一权威项目保持 `FAB-P0001 / TFI`。

## Open-source-first decision

继续采用 `yt-dlp` extractor 分层思想和公开 Douyin parser 的 public playback-source思路，不复制第三方源码。Fabushi 自己负责 package/release、runtime、MCP/CLI、allowlist、批量执行和错误模型。

## Acceptance criteria

1. Marketplace 可以发现 `douyin-batch-downloader`，并返回 package install release。
2. package SHA-256/size 与 release metadata 一致，Mahayana installer 可验证。
3. package manifest 声明 GUI/MCP/CLI/local modes；`.mcp.json` 与 `.mahayana/plugin.json` 客观存在且指向同一 runtime。
4. `ai-backend` 不包含 Downloader 专属 runtime/router。
5. Rust runtime `resolve` / `download` contract tests 通过，且 source/media allowlist、安全文件名、批量输入等单测通过。
6. `cargo fmt --check`、Rust test/build、Marketplace search/install test、package digest 检查全部 current-head CI 通过。
7. duplicate project/fake P0009 不存在；`projects/PORTFOLIO.json` 与 canonical main identity policy 一致。
8. canonical PR #2141 通过 protected main gate 并从 main 回读验证。
9. exact-main packaged E2E 保留 required screenshots/video/trace/reports，随后发布指向 accepted main SHA 的 GitHub Release，才可 `COMPLETED`。

## Verification / evidence so far

- Original embedded implementation commits: `fd13a64b8f3e4dde58453df812f4787d5c3020eb` → `009c175d6b1b6454573f019ded84db01fc654ca7`（历史 provenance；已被独立 package 架构取代）。
- Feeder PR #2136 merged into feature branch as `fb1478d0f9d52b9cdee32acac6fb1c7581ece680`.
- Portfolio duplicate cleanup: `baed8e4c66badb0409d04eb15aeab8341af5362e` + removal commits.
- ai-backend decoupling: `81f6385f856251559f2ef64c29c3dd7df282620b`, `55594d4ebad5723c7aedb2db12430bd756ab61a5`, `8ac37f594032761aa03df29720162059b7075034`, `953724e369b3154245fce5c4a7896c8b20345e80`.
- Rustfmt repair after feeder CI evidence: `fc1f13be0acdf3b993695bc0aa5d5b190a22f989`.
- Dedicated portable-boundary CI update: `892570d5004d194c648d93c77f931f0e7d1dc803`.
- Updated persisted requirement: `1c55a9e77f8334efad9f8c0b2e2e7acae3f5baef`.
- Current-head CI / merge / exact-main / Release evidence: pending.

## Blockers / risks

- Douyin 页面结构与反自动化行为会变化，runtime 必须在登录/验证码出现时显式失败，不尝试绕过。
- 当前 package 是 portable UI/package + compatible Mahayana shared runtime 模型；如果未来要求“完全自包含、无 Mahayana Host 也能执行”，需另立 artifact/runtime packaging 设计，不应混淆当前验收。
- 任务在 current-head CI、protected merge、canonical-main packaged E2E 与 Release 完成前不得关闭。

## Next action

重新打开 canonical PR #2141，运行最新 dedicated/repository CI；修复失败后合并 protected `main`，随后完成 exact-main package/E2E/Release 交付闭环。
