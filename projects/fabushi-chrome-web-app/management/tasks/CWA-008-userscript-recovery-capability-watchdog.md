# CWA-008 — 用户脚本恢复能力与标签页 watchdog

## Identity

- Portfolio Project ID: `FAB-P0011`
- Project Key / Task ID: `CWA / CWA-008`
- Started: `2026-09-14T08:00:00+08:00`
- Updated: `2026-09-14T11:44:35+08:00`
- Status: `IN_PROGRESS / WEBS_STORE_PENDING_REVIEW / LIVE_CHROME_EVIDENCE_PENDING`

## Objective

让 Fabushi Chrome 扩展成为内置 ChatGPT userscript 的页面外恢复宿主。脚本按需请求
`tab-recovery` 能力，宿主自动检测 renderer 崩溃、崩溃页、discarded 或 stale heartbeat，
并使用一次性恢复票据重载原标签页或有限接管新标签；任务 token、阶段、轮次和附件索引由
脚本持续保存，恢复后由当前 composer 重新上传确认附件。修复发送确认超时恢复反复回到
“需要处理”的状态，并保持已识别的自然语言 Work 回复进入下一轮验收。

## Source requirements

规范化来源：`projects/fabushi-chrome-web-app/source/2026-09-14-userscript-recovery-capability.md`。

- `CWA-R013`：显式能力请求/授予/释放。
- `CWA-R014`：宿主恢复元数据最小化，不存正文、凭证和文件本体。
- `CWA-R015`：页面外 crash/stale watchdog 与暂停/关闭保护。
- `CWA-R016`：原标签优先、单次接管 fallback、附件与任务身份连续。
- `CWA-R017`：blocked 发送确认恢复不复用过期计时、不重复发送，并继续最终回复→验收链路。
- `CWA-R018`：CI 打包、用户旅程、证据和 Release 可追溯。

## Scope

### In scope

- MV3 service worker 的 `userscript-recovery.js` capability lease、alarm、tabs lifecycle
  监控、恢复 URL 校验、原标签 reload 和单次接管。
- `userscript-content.js` 的 request/release bridge、内置 userscript v2.9.20、附件与
  blocked 恢复状态机修复。
- 打包 allow-list、runtime staging、静态验证、unit/contract tests、项目记录和 CI 证据。

### Out of scope

- ChatGPT 私有 API、浏览器内核修复、任意外部标签页接管、Cookie/令牌导出、远程脚本执行。
- 本地 Fabushi 应用 build、native/mobile build 或 E2E；重型验证必须在 GitHub Actions。

## Dependencies

- TFI source userscript branch `codex/tab-crash-recovery-20260914` and its source PR/Release.
- Chrome MV3 `tabs`/`alarms`/`storage`/`content_scripts` permissions and current runner bridge.
- Protected main, exact-main Chrome packaged workflow and the repository post-main delivery loop.
- Authenticated Chrome crash/restore sample and required visual/debug evidence remain pending.

## Acceptance criteria

- [x] A01：userscript 活跃/发送中/可恢复 blocked 时发出 `tab-recovery` request；宿主 grant
  与 release bridge 已接入。
- [x] A02：宿主只持久化恢复元数据，不持久化 goal、prompt、Cookie、凭证或文件字节；
  unsafe origin/URL、未声明可恢复 blocked 状态被拒绝。
- [x] A03：watchdog 在 crash URL、崩溃标题、discarded 或 stale heartbeat 时优先更新原
  标签页，更新失败才创建一个接管标签；`onRemoved` 不重开主动关闭的标签。
- [x] A04：内置 userscript v2.9.20 保留 task token、phase/round、会话身份和 IndexedDB
  attachment IDs；当前 composer 未重新确认附件前不会发送。
- [x] A05：blocked 发送确认恢复拥有独立确认窗口；首次恢复扫描不会因旧 90 秒时间戳再次
  blocked，用户明确选择当前唯一会话时可绑定 URL且不重发，Work final 仍进入验收 prompt。
- [ ] A06：Chrome focused CI、protected merge、canonical-main packaged crash-recovery
  journey，以及截图/完整视频/trace/report/logs evidence 全部绑定 exact SHA。
- [ ] A07：精确 canonical main SHA 的 packaged Fabushi Release 已验证；Chrome Web Store
  版本 `0.6.0` 已提交审核但尚未公开发布，在审核完成前保持 `IN_PROGRESS`。

## Open-source-first survey and reuse decision

官方 Chrome `tabs`/`alarms`/`webNavigation` 与 Playwright Page crash 行为已调研；采用
Chrome 原生页面外观察模型，不复制 Playwright 或其他 userscript/扩展代码、不增加生产依赖。
TFI 侧延续对 `chatgpt.js`、Violentmonkey 和 GPL 文件上传实现的比较，使用 Fabushi 自有
任务/附件边界。

## Implementation / verification evidence

工作树已实现：`userscript-recovery.js`、service worker import、content bridge、v2.9.20
bundle、packaging/runtime/verifier allow-list 和 tests。轻量验证已通过：扩展 validator、
Node syntax/static checks、Chrome focused contract tests `10/10` 及 watchdog unit tests
`5/5`（合并回归套件 `15/15`）；TFI source regression 在最终 patch 后重新执行并记录实际结果。未执行本地 app build、
package 或 E2E。

Parent PR [#2594](https://github.com/bhrumom/fabushi/pull/2594) 已通过 protected merge queue
合并；本任务接受的 main SHA 为 `e60d40f4a97dcb319515abb2b46ef2845d4eb21b`，随后独立
PR #2593、#2595 及后续 canonical main 变更已将当前 canonical main 前进到
`6d9fc672f8163b1a4246e46e59691d0110ee9f0b`（包含并保留本任务 SHA）。该任务接受 SHA 的 Chrome
package/journey run `34795268685` 成功，artifact `10329366885`；Electron packaged gate
`34795268724`、Native mobile gate `34795268715`、Computer control security gate
`34795268693`、Project portfolio governance `34795268701`、CI `34795233447` 均成功。
post-main delivery run `34796011272` / publish job `103829791736` 成功，发布的
[`desktop-1.2.64`](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.64) 目标 SHA
正确，包含 macOS/Windows/Linux updater 资产及 Chrome `0.6.0` 精确包。

Chrome Web Store 发布凭据已写入受保护的 `chrome-web-store` 环境，Google Cloud 中的
Chrome Web Store API 也已启用。精确包校验后，首次带凭据运行
`34802232279` 因 API 尚未启用返回 403；启用后重试 `34802669055` 的包来源、版本和
SHA 校验成功，但上传接口返回 400。Chrome Web Store 开发者后台随后核对到现有 Fabushi
草稿已经包含版本 `0.6.0`，因此通过后台提交了该现有草稿；提交结果明确为“待审核”，并提示
因 `host_permissions: <all_urls>` 可能进入深入审核。两次失败运行的脱敏证据分别为
artifact `10331873115` 和 `10332215035`。

Live Chrome crash/error-page 与附件/最终回复连续性现场证据仍未取得；因此 CWA-008 仍保持
`IN_PROGRESS / WEBS_STORE_PENDING_REVIEW / LIVE_CHROME_EVIDENCE_PENDING`，不把“待审核”
冒充 Chrome Web Store 已公开上架或把轻量测试冒充真实崩溃旅程通过。

## Risks and next action

- Risk: stale heartbeat 与后台节流混淆；lease 长于 stale threshold，且脚本显式 autoResume、
  owner lock 和单工作区候选共同限制抢占。
- Risk: crash 页无法执行 userscript；由宿主 reload/接管恢复票据，脚本在新文档重新取得锁并
  读取同源任务/IndexedDB。
- Risk: 误把不确定发送当作可重发；token 保留、恢复确认窗口独立、用户明确恢复才允许当前
  唯一路由绑定。
- Blocker: Chrome Web Store 版本 `0.6.0` 已提交，当前状态为外部“待审核”；自动上传流程对
  已存在的同版本草稿仍需做幂等处理，不能把 HTTP 400 当作可重复上传成功。
- Next: 保留后台审核状态证据，审核通过后核验公开 listing/安装版本；同时补齐真实 Chrome
  崩溃/卡住恢复、附件连续和 final→acceptance 的逐步截图、完整视频、trace/report/logs，
  再关闭 CWA-R013..R018 的剩余现场门禁。
