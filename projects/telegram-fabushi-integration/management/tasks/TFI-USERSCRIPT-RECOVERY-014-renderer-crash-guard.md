# TFI-USERSCRIPT-RECOVERY-014 — 并行切页 Renderer 崩溃保护与发布

- portfolio project_id: FAB-P0001
- project_key: TFI
- task_id: TFI-USERSCRIPT-RECOVERY-014
- status: IN_PROGRESS
- started: 2026-09-14 Asia/Shanghai
- updated: 2026-09-14 Asia/Shanghai
- owner: Fabushi runtime/Chrome integration
- source: projects/telegram-fabushi-integration/source/2026-09-14-userscript-renderer-crash-guard.md

## 目标

修复多任务轮换时已结束会话没有转入新会话验收，以及循环导航导致 ChatGPT renderer 崩溃后脚本失去控制的问题。由脚本请求 Chrome 宿主的受控导航能力，宿主在跨文档边界提供节流、in-flight 去重、崩溃识别和有限恢复，脚本在每次继续前重新验证任务代次。

## 范围

- userscript 2.9.24：tab-navigation-guard 请求/响应、任务代次绑定的 dispatch/recovery 票据、BFCache 安全返回、宿主拒绝后的延迟重试。
- Fabushi Chrome 插件 0.6.2：MV3 service worker navigation guard、content bridge、unloaded/crash 识别、标签页生命周期清理与 recovery watchdog 对接。
- 版本 pin、打包白名单、静态验证、Chrome packaged journey、Marketplace/Web Store 发布与当前 Chrome 安装更新。
- 项目记录、开源调研、发布/回滚证据。

非范围：改变 ChatGPT 官方页面、绕过授权/安全挑战、传输用户任务文本或附件内容、在本地构建 Electron/native/mobile 包。

## 依赖

- userscript source PR #19 必须先通过 CI 并进入 source main，parent app.js 只能 pin source canonical-main merge SHA、SHA-256 和 byte size。
- parent Fabushi PR 必须通过 protected-main checks；Chrome package/version 0.6.2 必须来自该 PR 合并后的 canonical main。
- Chrome Web Store/API 凭据、当前浏览器登录态与审核状态属于外部依赖；审核未完成时不得声称用户端已自动更新。

## 验收标准

- [ ] 已结束 Work/验收会话在下一次轮换时被识别并生成新的 review dispatch，不复用旧 route 或旧轮次。
- [ ] 每次 routine route switch 先获得宿主 permit；task/phase/round/goalRevision 不匹配、已暂停/完成、崩溃/unloaded、loading 或 in-flight 时 fail-closed。
- [ ] 5 分钟窗口最多 6 次普通导航，单次至少 30 秒冷却；达到阈值进入 60 秒 break；recovery/force 只用于受控恢复且仍受票据校验。
- [ ] renderer 崩溃/chrome-error:// /unloaded 页面不导致重复发送；原标签一次恢复失败后才允许有限的新文档接管，并保留任务/附件/发送 token。
- [ ] source regression 与 parent Chrome guard tests 通过；Chrome package validator、security/static checks 与 packaged user journey 通过并保留截图、完整视频、trace、HTML/report、日志。
- [ ] 脚本 v2.9.24 与插件 v0.6.2 已发布；插件当前安装版本可回读为 0.6.2，或由 Web Store 明确记录为等待审核/待更新。
- [ ] 发布物可回溯到 canonical main SHA，版本单调递增；回滚为上一稳定版本，不删除任务数据。

## 开源优先结论

已调研 WICG Page Lifecycle、GoogleChromeLabs page-lifecycle、Playwright BrowserContext/frame 生命周期。没有兼容且必要的现成 Fabushi 插件依赖；保留自身 task/lease 边界，采用短生命周期 permit、重新获取页面状态、fail-closed 恢复。未复制第三方代码。

## 实现记录

- userscript branch: codex/release-2.9.24-renderer-guard-20260914
- userscript PR: https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/19
- userscript canonical source main: 71a2279b887cc7429b7ca4c547a7099f8b63c55a (source PR #19, squash-merged).
- userscript CI: GitHub Actions run 34838068938, job 103956394607, 114/114 tests passed; syntax validation passed.
- userscript release: [v2.9.24](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.24) published from canonical source main; asset size/hash verified.
- parent branch: codex/release-0.6.2-renderer-guard-20260914
- parent PR #2623: merged to canonical main as b4d2d85fcd510c51d3dce646311d19c81e6c7403.
- release-diagnostics PR #2624: merged to canonical main as 1e63a8cf14697107af62948d713cff120679694f.
- source artifact verified from canonical source main: UTF-8 SHA-256 d82d987adb996a77dc224ca797750782a02a902221f5a76628bc571357636c41, 214840 bytes.

## Verification and delivery evidence

- Lightweight inspection: source/host files, manifest, packaging allowlist, validator, bridge and task records reviewed.
- Local heavy build/test: intentionally not run; repository policy requires GitHub Actions.
- Source CI: passed — run 34838068938 / job 103956394607, 114/114.
- Parent PR CI / Chrome package / packaged journey: passed — final exact-main Chrome package run 34842044140; evidence artifact contains labelled screenshots, complete WebM segments, trace.zip, Playwright HTML report and JSON/native logs.
- Canonical main readback: verified at 396a842c7e00b8ad7c236d84cabc9230ed88d391; manifest version 0.6.2 and source pin/hash/size match.
- Chrome package/journey run 34839358565 (b4d2d85fcd510c51d3dce646311d19c81e6c7403) passed; artifact retained for 90 days with ZIP, content manifest and SHA256SUMS.
- Post-main delivery run 34840407940 passed and published the exact-main desktop Release `desktop-1.2.65-b4d2d85fcd51`, including Chrome 0.6.2 ZIP/manifest/checksum assets.
- Final workflow-diagnostic Chrome package run 34841147270 (source 1e63a8cf14697107af62948d713cff120679694f) passed; package SHA-256 c3d206172376a76c09b6f8185981f1bfe8371f9c213f11b2b5d4a83c08ced109.
- Canonical-main Chrome E2E evidence: `fabushi-chrome-web-store-1e63a8cf14697107af62948d713cff120679694f` contains labelled screenshots, complete WebM journey segments, trace.zip, Playwright HTML report and JSON/native logs.
- Web Store publisher runs 34840738917 and 34841285781 both stopped at upload HTTP 400; final redacted API response is `FAILED_PRECONDITION / NOT_UPDATEABLE`: the item already has a submission in review. After explicit user confirmation, the current Chrome unpacked extension at `/Users/gloriachan/Downloads/fabushi-0.3.0` was replaced and reloaded; the extension page and Service Worker console read back v0.6.2. The previous v0.4.1 directory is preserved at `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.4.1-20260914`.

## Risks / blockers

- ChatGPT renderer changes remain an external UI risk; selectors remain semantic and recovery is bounded.
- Web Store review can delay current Chrome auto-update; maintain an explicit pending state.
- Existing Web Store submission must finish or be explicitly cancelled before 0.6.2 can be uploaded; cancellation is not performed automatically.
- Current Chrome unpacked extension update is complete: exact final-main CI files are installed and the browser readback is v0.6.2; the previous v0.4.1 directory remains available for rollback.
- ChatGPT renderer changes remain an external UI risk; selectors remain semantic and recovery is bounded.

## Next action

Next: keep the existing Web Store review pending (or act only on a separate explicit cancellation decision), then submit 0.6.2 after the item becomes editable; monitor the installed v0.6.2 unpacked extension.

## 最终 main / Chrome 本机回读补充

- Final canonical main: `396a842c7e00b8ad7c236d84cabc9230ed88d391`。
- Chrome package run: `34842044140`；artifact `fabushi-chrome-web-store-396a842c7e00b8ad7c236d84cabc9230ed88d391`；ZIP SHA-256 `fcb28edd264facb0940bc1a61366954743f72ced557a72ae79cf96e5325b58ce`。
- Post-main run `34843041788` succeeded and published [desktop-1.2.65-396a842c7e00](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65-396a842c7e00)。
- Current Chrome path `/Users/gloriachan/Downloads/fabushi-0.3.0` is v0.6.2 and enabled; Service Worker console returned `0.6.2` with zero console messages. Previous v0.4.1 is recoverable from `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.4.1-20260914`。
- Task remains `IN_PROGRESS` only because the Web Store item is locked by an existing review; public Web Store update is not claimed.
