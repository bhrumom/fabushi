# TFI-USERSCRIPT-RECOVERY-011 — 标签页崩溃/卡住自动恢复

## Identity

- Portfolio Project ID: `FAB-P0001`
- Project Key / Task ID: `TFI / TFI-USERSCRIPT-RECOVERY-011`
- Started: `2026-09-14T08:00:00+08:00`
- Updated: `2026-09-14T09:36:20+08:00`
- Status: `IN_PROGRESS / WEBS_STORE_BLOCKED / LIVE_CHROME_EVIDENCE_PENDING`

## Objective

修复 ChatGPT 标签页出现 renderer 崩溃页或长时间卡住时的任务恢复。恢复必须保持原任务
会话身份、发送 token、持续目标阶段和 IndexedDB 附件，不因新文档或恢复流程重新生成
无附件目标，也不能把不确定的发送重复点击成两个会话。

## Source requirements

规范化来源：`projects/telegram-fabushi-integration/source/2026-09-14-userscript-tab-crash-recovery.md`。

- `TFI-USR-CRASH-R01`：工作区持久心跳。
- `TFI-USR-CRASH-R02`：新文档唯一 stale workspace 自动接管。
- `TFI-USR-CRASH-R03`：URL/token/轮次/阶段/IndexedDB 附件连续。
- `TFI-USR-CRASH-R04`：卡住路径有界新文档交接。
- `TFI-USR-CRASH-R05`：幂等、去重、fail-closed。
- `TFI-USR-CRASH-R06`：测试、发布、可追溯证据。
- `TFI-USR-CRASH-R07`：脚本请求宿主 `tab-recovery` 能力，宿主只保存恢复元数据并在页面外
  监控标签页。
- `TFI-USR-CRASH-R08`：恢复/继续不重复发送、不丢 token/轮次/附件；用户明确恢复当前唯一
  会话时可绑定 URL，并把最终 Work 回复传给下一轮验收。

## Scope

### In scope

- 独立 userscript 的工作区 heartbeat、stale workspace 识别与自动接管。
- renderer 卡住时的单次新文档交接以及既有 URL/token/附件恢复。
- userscript → Fabushi Chrome 宿主的恢复能力请求、租约续期/释放、崩溃 watchdog 和安全
  原标签/接管标签恢复。
- “需要处理”发送确认超时记录的显式恢复：已有 URL 只检查，唯一当前 URL 可由用户确认
  绑定，无 URL 的不确定发送保留 token 和附件等待，不执行第二次发送。
- userscript 回归测试、source Release、parent 项目记录和现场证据索引。

### Out of scope

- ChatGPT 私有崩溃 API、上传 API、浏览器内核补丁或绕过登录/安全验证。
- 本地 Fabushi 应用构建、Electron/Android/iOS 构建及本地 E2E；这些若适用必须由 CI
  承担。
- 在无法运行页面 JavaScript 的 `chrome-error://` 文档内执行 userscript；该边界由
  新文档接管和可用的页面外扩展 watchdog 覆盖。

## Dependencies

- Source repository: `bhrumom/fabushi-chatgpt-auto-confirm-userscript`。
- Source baseline: parent task 010 released `v2.9.19` / source main
  `5cbbb4e099f8404982ea621a4ab8464f4b2b959e`。
- Existing localStorage `fabushi-workbench-v2`, IndexedDB
  `fabushi-workbench-attachments-v1`, Web Locks and navigation ticket contract。
- 真实 Chrome 登录态和可复现的崩溃/卡住样本证据仍待补齐。

## Acceptance criteria

- [x] A01：运行中工作区按固定间隔持久化 owner、任务状态、当前 URL/token、恢复 URL 和
  时间戳；目标正文及附件二进制不写入 heartbeat。
- [x] A02：新 ChatGPT 文档面对唯一 stale heartbeat 且原 Web Lock 已释放时自动接管；
  healthy、多个候选、手动暂停、取消和终态场景不误接管。
- [x] A03：接管后的 Work/验收/下一轮仍沿用当前任务 URL、token、phase/round 和
  IndexedDB Blob；附件须在新 composer 重新注入并确认后才能发送。
- [x] A04：卡住恢复最多执行既定次数，并通过一次恢复票据进入新文档；无无限刷新、无
  重复派发，原发送不确定时保留 token 并 fail-closed。
- [x] A05：新增回归测试覆盖 stale/healthy/paused/multiple workspace、恢复票据幂等、
  URL/token/附件连续和卡住有界恢复；源语法检查与完整 source 测试通过。
- [x] A06：source PR、exact source-main CI、`v2.9.20` Release asset 与 SHA 可追溯：source PR #15、source main `579c5204734afe21d366018d4ee16b5c6d3fb6ce`、exact-main CI `34794406863`、Release `v2.9.20`（asset `chatgpt-auto-confirm.user.js`）。
- [ ] A07：真实 Chrome 崩溃/卡住旅程取得 checkpoint 截图、完整视频、trace/diagnostics；
  在证据完成前不将本任务标记为 passed。
- [x] A08：脚本在活动/发送中/附件上传等待及可恢复 blocked 状态请求 `tab-recovery`；请求
  payload 不包含目标正文、prompt 或文件二进制，宿主 grant/deny 与释放消息可闭环。
- [x] A09：恢复“需要处理”的不确定发送时，原始 token/附件仍保留；恢复确认窗口不复用过期
  的原始 90 秒计时，用户明确选择当前唯一会话时绑定 URL，后续检查不重复发送。
- [ ] A10：Fabushi Chrome 扩展 exact-main packaged journey 证明 crash/error page → 原标签
  恢复或单次接管新标签 → userscript 工作区/附件/最终回复交接；证据需含截图、完整视频、
  trace/report/logs。

## Open-source-first survey and reuse decision

已完成官方 Playwright/Chrome tabs/webNavigation 调研；采用页面外 crash 观察和新文档
接管的分层原则，不复制实现、不引入 Playwright 运行时。延续 task 010 对 chatgpt.js、
Violentmonkey 和 GPL 文件上传项目的许可证/兼容性审查，继续使用现有自研 DOM 与
IndexedDB 边界。宿主扩展采用 Chrome 官方 `tabs`/`alarms` 事件与持久化 metadata lease，
不把页面正文或附件二进制复制到扩展存储。

## Implementation / delivery evidence

source PR [#15](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/15)
已合并；source canonical main 为
`579c5204734afe21d366018d4ee16b5c6d3fb6ce`，exact-main CI run `34794406863` 成功，Release
[`v2.9.20`](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.20)
已绑定该 SHA 并包含安装资产。

parent PR [#2594](https://github.com/bhrumom/fabushi/pull/2594) 已经 protected merge queue
合并；本任务接受的 parent main SHA 为 `e60d40f4a97dcb319515abb2b46ef2845d4eb21b`，随后
独立 PR #2593 已将 canonical main 前进到 `31fdeca90bc8012e144b3ada00ca439891606e2c`（包含
并保留本任务 SHA）。该任务接受 SHA 的
Chrome workflow `34795268685` 成功（artifact `10329366885`），Electron packaged gate
`34795268724`、Native mobile gate `34795268715`、security/governance checks 均成功；
post-main delivery `34796011272` 成功并发布 Release
[`desktop-1.2.64`](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.64)，目标与该
SHA 一致，包含桌面安装包、updater metadata 和 Chrome `0.6.0` 包。

Chrome Web Store 正式提交 run `34796377000` / job `103830176952` 已完成 exact-source
包校验，但因受保护环境 `chrome-webstore` 的 publisher、item、OAuth client、secret 和
refresh token 均未配置，在调用商店 API 前 fail-closed；未产生商店提交。证据 artifact 为
`10329509377`。本任务的 packaged Fabushi delivery 对独立 userscript 部分为 `N/A`，但同一
修复扩展了 `FAB-P0011/CWA` Chrome 宿主，因此真实 Chrome 崩溃/卡住及附件/最终回复现场证据
仍需补齐。

## Risks and next action

- Risk: renderer crash document cannot run page JavaScript；必须依赖 reload/new document，
  集成扩展可进一步提供页面外 tab watchdog。
- Risk: stale heartbeat 可能与后台页面节流混淆；采用较长 TTL、唯一候选和手动暂停屏障，
  不确定时保持原任务而不抢占。
- Blocker: Chrome Web Store publish workflow `34796377000` 在 API 调用前发现受保护环境凭据
  为空；不能代填或把 GitHub Release 冒充为商店已上架。
- Next: 配置 `chrome-webstore` 环境的发布凭据后，以 source SHA
  `e60d40f4a97dcb319515abb2b46ef2845d4eb21b` 重跑 publish workflow；同时在已登录 Chrome
  补齐崩溃/卡住、无链接恢复、最终回复→验收和附件连续性的截图、完整视频、trace/diagnostics。
