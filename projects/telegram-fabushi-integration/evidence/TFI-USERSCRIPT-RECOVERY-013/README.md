# TFI-USERSCRIPT-RECOVERY-013 证据索引

本目录保存 userscript 内存感知、宿主标签页回收和有界清理的审计证据。当前状态：`IN_PROGRESS`。

## 证据清单

- 用户来源：2026-09-14 用户消息；用户明确要求“脚本请求宿主去清理”。
- 开源调查：`source/2026-09-14-userscript-memory-pressure.md`，包括 Chromium 官方 tabs/Page Lifecycle 文档、Drowzy、DevTools frontend、Great Suspender 的采用/拒绝决策。
- source baseline：`bhrumom/fabushi-chatgpt-auto-confirm-userscript main@a6a8a74b339176d044d2a8090ae996ec9c17b739`，2.9.21。
- host baseline：`bhrumom/fabushi main@b07ccff486d9c0f2b659460ac3a79a654c9eb3dc`，MV3 manifest 0.6.0。

## 待补证据

- source branch/PR/CI/protected merge/source-main readback、版本 2.9.22。
- host branch/PR/CI/protected merge/canonical-main readback、宿主 manifest/bridge static contract。
- GitHub Actions 中的 packaged/Chrome extension validation（如适用）。
- 已登录 Chrome 中分步内存诊断、手动本地清理、非活动标签页宿主 discard、激活后任务恢复的完整截图、视频、trace/diagnostics；证据必须绑定 exact SHA、版本、浏览器时间和任务标识。
- GitHub Release/Chrome Web Store 版本与资产回读；本任务尚未获得公开发布授权。

## 交付边界

userscript source 与 Chrome MV3 host 均属于可运行产品输入；不能以本地轻量测试代替 GitHub Actions。未完成 exact-main required CI、Chrome/packaged 证据和用户明确发布授权前，不标记 `RELEASED`。

## 安全边界

宿主请求不携带目标文本、会话链接、恢复 token、附件元数据或附件字节；宿主使用消息发送方的 tab id，不信任页面 payload 中的 tab id。活动标签页、危险操作和冷却状态 fail-closed。
