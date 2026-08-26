# 2026-08-26 — 抖音批量无平台水印下载小程序

## 原始需求

用户要求把本轮已验证的抖音公开作品无平台水印下载方法做成 Fabushi 小程序，上线到现有 Mini Apps 市场，并支持批量下载。

## 归一化范围

- 复用现有 `FAB-P0001 / TFI` 的 M8 Mini Apps 市场，不创建第二套应用商店。
- 小程序 ID：`douyin-batch-downloader`。
- 支持抖音 `jingxuan?modal_id=...`、`/video/<aweme_id>`、公开短链接分享文本和作品 ID。
- 单次批量最多 50 条，服务端有限并发解析，并保留逐条成功/失败结果。
- “无水印”实现定义为：优先选择作品公开元数据中的 `video.bit_rate[*].play_addr` / `video.play_addr` 播放源；不得把 `download_addr` 当 clean source；不做裁切、遮挡、重编码或图像修复式去水印。
- 下载通过受限媒体代理完成，必须限制为抖音/字节 CDN HTTPS 域名并转发 Range，禁止演变为任意 URL SSRF 代理。
- 提供市场搜索、默认 Bot、GUI、单条解析和批量解析命令入口。
- 仅面向公开可访问内容；不得绕过 DRM、付费墙、私密访问控制或盗取浏览器 Cookie。

## 验收要求

1. 市场搜索“抖音”可以发现并添加该官方小程序。
2. 给定 `https://www.douyin.com/jingxuan?modal_id=7491613333141900602` 能解析作品 ID。
3. 解析逻辑明确优先最高可用 bitrate 的 `play_addr`，且测试证明不会选 `download_addr`。
4. 批量接口支持最多 50 条并返回逐条结果，一个失败项不影响其它成功项。
5. 媒体代理只允许受信任的抖音/字节 CDN HTTPS Host，支持 HTTP Range。
6. GUI 可批量粘贴、解析并触发下载全部成功项。
7. `npm run check` 与 `npm test` 在 current-head GitHub CI 通过。
8. PR 必须进入 protected `main`；之后按仓库 post-main gate 完成 packaged E2E、截图/视频/trace 与 Release 证据后才能把任务标记为 COMPLETED。

## 开源优先调研

- 参考 `yt-dlp/yt-dlp` 的站点 extractor 分层思想：解析平台标识/元数据与下载传输分离，平台变化局限在 adapter。
- 参考当前公开的 Douyin parser 实现共同做法：解析 aweme_id，读取公开作品元数据，选择 `play_addr` 而非 `download_addr`。
- 不直接复制第三方解析器代码；Fabushi 实现保留自己的 URL allowlist、批量限流、错误模型和市场边界。
