# M8-DL-001 — 抖音批量无平台水印下载小程序

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-DL-001`
- **Stage**: `M8 Mini Apps`
- **Status**: `IMPLEMENTED`
- **Started**: `2026-08-26`
- **Branch**: `feat/tfi-douyin-batch-downloader-miniapp`
- **Source requirement**: `../../source/2026-08-26-douyin-batch-downloader-miniapp.md`

## Objective

把已验证的抖音公开作品 clean `play_addr` 下载方法产品化为 Fabushi 官方 Mini App，并复用现有 Marketplace、Bot identity 与统一下载后端，支持批量粘贴和下载。

## Implementation

- `ai-backend/src/douyin_downloader.js`
  - Douyin URL/分享文本/作品 ID 解析；
  - 短链有限跳转且每一跳只允许 Douyin Host；
  - Web detail API + public share page fallback；
  - 最高 bitrate `play_addr` 选择，明确不读取 `download_addr` 作为 clean source；
  - 最多 50 条、并发 4 的批量解析；
  - allowlist + HTTPS + Range 的媒体代理；
  - 批量 GUI；
  - 官方 `douyin-batch-downloader` Mini App manifest、默认 Bot 与 commands。
- `ai-backend/src/miniapp_marketplace_http.js`
  - 将该 manifest 加入 Marketplace seed；
  - 注册 downloader REST/UI/media routes。
- `ai-backend/test/douyin_downloader.test.js`
  - jingxuan/canonical/numeric ID；
  - highest-bitrate clean source；
  - short-link redirect；
  - Marketplace discovery；
  - batch partial failure isolation。

## Security / compliance boundary

- 不读取用户常用浏览器 Cookie，不持久化登录凭证。
- 不绕过 DRM、付费墙或私密访问控制。
- 媒体代理不能转发任意互联网 URL；仅允许抖音/字节 CDN HTTPS 域名。
- UI 明示仅下载用户拥有、获授权或法律允许保存的公开内容。

## Open-source-first decision

调研 `yt-dlp` extractor 分层和现有公开 Douyin parser 的 `aweme_id -> metadata -> play_addr` 路径。复用其架构思想，不复制第三方源码；采用 Fabushi 自有 manifest、URL allowlist、批量限流和错误模型。

## Acceptance criteria

1. Marketplace 搜索“抖音”可以发现 `douyin-batch-downloader`。
2. 用户提供的 `jingxuan?modal_id=7491613333141900602` 结构可正确提取 ID。
3. clean stream 只来自 `bit_rate.play_addr` / `video.play_addr`，测试明确排除 `download_addr`。
4. 单次最多 50 条、并发受控、逐条返回结果。
5. 下载代理支持 Range 且具有严格 SSRF Host allowlist。
6. GUI 支持多行粘贴、批量解析、逐项下载和下载全部成功项。
7. current-head `npm run check` + `npm test` 通过。
8. PR 合并 canonical `main` 后，通过 exact-main packaged/E2E 和 Release gate 才能 COMPLETED。

## Verification / evidence

- Implementation commits: `fd13a64b8f3e4dde58453df812f4787d5c3020eb`, `3167cceb46f1d6038ec76735681e58832f6052f2`, `e54c3fabdcecef0f6f19802150dc5d9726d7bdc3`, `009c175d6b1b6454573f019ded84db01fc654ca7`.
- Source persistence: `36c307b76968d6ec7b63ddacf1de17e9232a2a41`.
- CI / PR / merge / exact-main / Release evidence: pending.

## Blockers

- Douyin public web metadata shape/anti-bot behavior can change; adapter has stable errors and share-page fallback but production must monitor parse-failure rate.
- Task cannot be closed before protected-main + post-main delivery evidence.

## Next action

Open PR, run repository CI, fix any failures, merge to protected `main`, then run exact-main packaged/E2E delivery and publish the verified Release.
