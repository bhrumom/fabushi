# CWA-008 — 用户脚本恢复能力与标签页 watchdog

## Identity

- Portfolio Project ID: `FAB-P0011`
- Project Key / Task ID: `CWA / CWA-008`
- Started: `2026-09-14T08:00:00+08:00`
- Updated: `2026-09-14T09:30:00+08:00`
- Status: `IN_PROGRESS`

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
- [ ] A07：精确 canonical main SHA 的 packaged Fabushi Release/Web Store delivery 已验证；
  在此前保持 `IN_PROGRESS`。

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

Branch / commit / PR / CI / merge / post-main Release / Web Store evidence 待后续回填。

## Risks and next action

- Risk: stale heartbeat 与后台节流混淆；lease 长于 stale threshold，且脚本显式 autoResume、
  owner lock 和单工作区候选共同限制抢占。
- Risk: crash 页无法执行 userscript；由宿主 reload/接管恢复票据，脚本在新文档重新取得锁并
  读取同源任务/IndexedDB。
- Risk: 误把不确定发送当作可重发；token 保留、恢复确认窗口独立、用户明确恢复才允许当前
  唯一路由绑定。
- Next: 完成 source 与 parent PR/required CI，protected merge 后驱动 exact-main packaged
  crash-recovery journey、Release/Web Store 及真实 Chrome evidence。
