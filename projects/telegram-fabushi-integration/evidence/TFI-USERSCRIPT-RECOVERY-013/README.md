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

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-013 evidence update

- source PR [#17](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/17)，head `3d23d8cc78931dceecb4d647706766470224f81b`，版本 2.9.22；host PR [#2607](https://github.com/bhrumom/fabushi/pull/2607)，head `0c16f0a52872e2efea9ed80c8de031ab1e70c081`。
- source 端 `npm test`、userscript syntax check 与 diff check 已通过；轻量回归为 111/111。
- host 端静态 contract/policy 已写入 PR，尚待 GitHub Actions；本地不执行重型构建/E2E。
- 后续 evidence 必须绑定 exact source/host main SHA、版本、workflow run/job、浏览器时间、任务标识，并保留分步截图、完整视频、trace/report/diagnostics。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-013 merge/readback evidence

- source main readback：`882cadf0cc35d00a29b93450990d758b4034a5c0`，userscript 2.9.22。
- host first main readback：`f7f9871b153efbe26d040e68e8d28eea46af2130`；follow-up head：`025cf0c04077ebd1affd5c25fa1f12a8489a1040`。
- 首轮 CI 的 Chrome Web Store job 因旧 `0.6.0` 版本门禁失败；安全 closure 检查通过。修复已在 follow-up #2608。
- 后续 evidence 仍必须绑定 follow-up 接受后的 exact main SHA、workflow run/job、版本、浏览器时间和任务标识，并保留分步截图、完整视频、trace/report/diagnostics。
