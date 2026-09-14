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
- userscript head at task record creation: a091f07cda7745098797dbabdd58dd0f2b6a1fc3
- userscript CI: run 34836902030 was in progress when recorded; previous run 34835595632 was cancelled after exposing two fixture defects, now corrected in a091f07c.
- parent branch: codex/release-0.6.2-renderer-guard-20260914
- parent branch latest known head: 9579f6fc6dbf86bc2dd4995671b67f484a1eacc3
- parent PR: pending creation after source canonical-main SHA is known.
- source artifact expected before canonical-main readback: UTF-8 SHA-256 d82d987adb996a77dc224ca797750782a02a902221f5a76628bc571357636c41, 214840 bytes. These values are provisional until re-read from source main.

## Verification and delivery evidence

- Lightweight inspection: source/host files, manifest, packaging allowlist, validator, bridge and task records reviewed.
- Local heavy build/test: intentionally not run; repository policy requires GitHub Actions.
- Source CI: pending.
- Parent PR CI / Chrome package / packaged journey: pending.
- Canonical main readback, release tag/assets, Web Store publish/install readback: pending.
- Canonical-main E2E evidence bundle: pending; it must contain labelled screenshots at meaningful steps, complete journey video, trace/report/logs and SHA/version/run identity for pass or fail.

## Risks / blockers

- ChatGPT renderer changes remain an external UI risk; selectors remain semantic and recovery is bounded.
- Web Store review can delay current Chrome auto-update; maintain an explicit pending state.
- If source CI exposes stale timers or fixture issues, fix through the source PR before merge; do not waive a failing required check.

## Next action

Wait for source PR #19 CI run 34836902030; merge only after green, read canonical source main, then update parent immutable userscript pin and open parent PR.
