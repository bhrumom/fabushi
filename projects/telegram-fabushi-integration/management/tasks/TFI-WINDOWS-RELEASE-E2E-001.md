# TFI-WINDOWS-RELEASE-E2E-001 — Windows 发布-测试-修复闭环

- Project: FAB-P0001 / TFI
- Status: in-progress
- Owner: execution / test-release closure
- Started: 2026-09-06
- Canonical starting main: `3f633e07cae0b022cce1ff3e6aeb8bfa92aa463d`
- Branch: `fix/tfi-windows-interactive-release-e2e-20260906`
- Product PR: `#2396`

## 用户目标

只在 Chat 会话推进 Windows 平台完整发布-测试-修复闭环。所有 Windows 构建、安装测试、E2E 与视频证据只允许在 GitHub Actions；禁止本机 build/test。测试时只允许控制本轮 GitHub Actions 中安装 Fabushi、登录受保护测试账号后由 **Fabushi App 自己注册** 的新 Windows App-owned device；禁止 KRIS、历史设备和 runner-owned gateway。

## 2026-09-06 live 基线

- `main`: `3f633e07cae0b022cce1ff3e6aeb8bfa92aa463d`。
- `app-version.json` / `desktop/package.json`: `1.2.35`。
- 当前可读回的最新 Windows 安装资产仍属于 Desktop `1.2.21` 系列（`fabushi-1.2.21-setup.exe`）；后续 `v1.2.23+` 测试发布为 macOS 专用资产，Windows 发布链明显落后于 canonical main。
- 最新 main Electron desktop quality gate run `34013938250` 已 cancelled，未形成新的 Windows 发布闭环证据。
- `@fabushi test list_devices` 基线仅发现历史 iOS/macOS GitHub Actions 设备且均离线；本轮基线时不存在 Windows device，因此任何历史设备都不得被选择。
- 仓库已有成熟 `macos-interactive-app-e2e.yml`，但不存在等价 Windows interactive App-owned workflow；这是本轮第一个真实交付缺口。

## 原子问题 001 — Windows 缺少 App-owned interactive release E2E

### Root cause

Windows 仅作为 `electron-desktop.yml` 的 build/package matrix 成员；没有“最新发布安装包 -> 录屏 -> 安装 -> 受保护账号登录 -> installed App 自注册 -> 外部 semantic MCP 六工具 -> 完整 journey -> always 证据上传”的 Windows job。因此即使 Windows installer 曾被打包，也无法满足发布后真实 App-owned 设备验收与审计合同。

### Open-source-first startup gate

- 复用仓库已验证的 `macos-interactive-app-e2e.yml` 生命周期/证据合同，不另造远程控制协议。
- 核对 GitHub `actions/runner-images` 当前 `windows-latest` 为 Windows Server 2025，包含 Chocolatey、GitHub CLI、Node、ImageMagick 等标准 runner 工具。
- 检索公开 Windows 桌面录制方案，FFmpeg `gdigrab` / Desktop Duplication 是成熟路径；本任务只把 FFmpeg 当 CI 录制工具，在 runner 无现成命令时通过 Chocolatey 临时安装，不向产品运行时增加依赖。

### 实现边界

1. 新增 `.github/workflows/windows-interactive-app-e2e.yml`，Windows-only，避免三平台矩阵和无关重型 CI。
2. **录制必须先于 Fabushi 安装**；完整 journey 始终保留视频。
3. 从 GitHub Releases 实时解析最新带 `fabushi-X.Y.Z-setup.exe` 的已发布 Release；记录 release id/tag/target SHA/asset digest。
4. 静默安装该 exact installer，验证可执行文件与版本后再登录。
5. 使用现有 `FABUSHI_CI_TEST_USERNAME` / `FABUSHI_CI_TEST_PASSWORD` secret 登录并导出 bounded、无 refresh token 的 App session。
6. 只启动 installed `fabushi.exe`；不得启动 standalone runner/KRIS device agent。设备 ID 固定为 `gha-<run>-<attempt>-windows-app`，由 App 日志 `controllable device online` 与 discovery file 共同证明 App-owned registration。
7. live 控制必须至少成功调用：`fabushi.app.status`、`fabushi.app.snapshot`、`fabushi.app.find`、`fabushi.app.action`、`fabushi.app.wait`、`fabushi.app.assert`。
8. 完整 Windows journey 类别：`startup,login,main,conversations,search,send,receive,reply,edit,delete,forward,draft,pin,mute,unread,contacts,groups,bot,agent,miniapp,webmcp,media,file,notifications,sync,settings,update`；logout 必须最后执行。
9. 失败不得删断言、伪造 note 或用 release 上传代替 pass；失败同样上传完整证据。
10. evidence 至少包含：whole-session video、分步截图、`device-calls.jsonl`、remote notes、Fabushi stdout/stderr、release 元数据、workflow jobs、report、generated regression、evidence file index。
11. artifact retention 目标 90 天。

## Acceptance

- [ ] Windows-only workflow 在 GitHub-hosted Windows runner 执行。
- [x] 录屏在 installer 执行前已启动（run `34014756838` step 6 success；该 run 在安装前由合同错误 fail-closed）。
- [ ] 使用最新实际发布 Windows installer，而非本地或 source build。
- [ ] 受保护测试账号登录成功，App 自注册新的 Windows App-owned device。
- [ ] `list_devices` 可读到该新 device，metadata 绑定本轮 repo/workflow/run/SHA。
- [ ] 六个 `fabushi.app.*` semantic tools 均有真实 successful trace。
- [ ] 完整 Windows 功能矩阵按真实 UI/状态执行，最终 logout。
- [x] 失败路径已证明视频/截图/trace/log/report artifact 在 `always()` 上传。
- [ ] 发现的每个产品缺陷独立写回项目并通过 PR + protected main 修复。
- [ ] 修复后 bump 到严格更高版本，发布新的 Windows 测试 Release，再对新 Release 重跑同一闭环。
- [ ] 最终 canonical main / PR / merge SHA / Release / run / device / evidence links 全部可读回。

## 风险与回滚

- GitHub Windows hosted runner 若无 FFmpeg，workflow 只在 CI 临时安装；安装失败应 fail closed，不允许无视频继续认定通过。
- NSIS 默认 per-user 安装路径可能随 electron-builder 变化；workflow 通过受限候选路径 + installer metadata 解析定位，不启动仓库 source executable。
- 远程 semantic control 未完成/超时、App 退出、缺任意六工具、缺视频或缺 evidence bundle 都必须失败。
- 回滚只需移除 Windows interactive workflow/contract，不影响产品运行时代码；但若发布/产品 bug 被后续真实测试发现，必须通过独立修复 PR 处理，不以回滚测试合同掩盖问题。

## Evidence ledger

### Diagnostic run 1 — `34014658237`

- Source: early Windows workflow branch revision。
- Result: fail-closed before release/install/App launch；合同将“`No standalone Runner/KRIS...`”负向说明中的 `KRIS` 错当成执行标记。
- Fix: 收窄 forbidden contract 到真实 standalone runner execution markers；保留 App-owned 与六工具断言，不删除安全门禁。
- Failure evidence artifact: `9983548899`, `fabushi-windows-interactive-evidence-34014658237-1`, SHA256 `38b743c4d5ae15d4c789aaf9e5e697f0d422700af681d925ac286839445ba514`, 90-day retention。
- 因安装/启动未发生，本 run 不产生可选 Windows device。

### Diagnostic run 3 — `34014756838`

- Exact source: `9a6b9f8d85d82040873a47e1c7dce42b7291c79d`。
- Runner: GitHub-hosted Windows Server 2025；FFmpeg `9.0.1` 由 Chocolatey 仅在 CI 安装。
- Whole-session recorder step success，且明确早于 release/install；使用移除 `RUNNER_TRACKING_ID` 的后台进程生命周期以跨 step 保留录像。
- Exact failure: `chatgpt-vps-control/package.json` 为 `type: module`，但新增合同文件使用 CommonJS `require`，Node `24.19.0` 报 `ReferenceError: require is not defined in ES module scope`；因此 release/install/login/App launch/remote hold 均被正确跳过。
- Cascading issue: 因 installer 未产生 executable，二级 Playwright 在空 `FABUSHI_ELECTRON_EXECUTABLE` 下回退下载 Electron，并在 browser-login waiting phase 超时；这不是 installed Windows product 结论。
- Fix: 合同文件改为原生 ESM imports；后续 secondary packaged Playwright 只应在 install success 后执行，避免无意义级联和额外耗时；evidence collection/upload 继续 `always()`。
- Failure evidence artifact: `9983578958`, `fabushi-windows-interactive-evidence-34014756838-1`, SHA256 `96ce98d8224dc8127dfda87a73fbafda4c7d84468b0526d4d897ed322258622d`, 45 files, 1,035,739 bytes, 90-day retention。
- 因安装/启动未发生，本 run 同样不产生可选 Windows device。

待后续成功 Actions/PR/Release 产生后继续写回真实 run、artifact、device、PR、merge SHA 与 Release 链接。


## 原子问题 002 — protected account helper 未允许 Windows App-owned device id

### Root cause

Diagnostic run `34015769297` 在安装 Desktop `1.2.21` 后进入受保护账号 helper，但 `login-ci-test-account.mjs`、`export-ci-app-account-session.mjs` 与底层 `fabushi-account-session.js` 的受保护 GitHub Actions device-id allowlist 仅允许 `interactive|ios-app|macos-app`。Windows workflow 按合同生成 `gha-<run>-<attempt>-windows-app`，因此 helper fail-closed，bounded App session 未生成，installed App 未启动，自然也没有新 App-owned Windows device。

### Fix boundary

- 只把精确后缀 `windows-app` 加入上述三个现有 protected GitHub Actions device-id 正则；不接受任意 device id，不放宽 `gha-<numeric run>-<numeric attempt>-<exact suffix>` 结构。
- 在 Windows workflow contract 中增加 helper 三点回归断言，防止 workflow 与账号 helper 的 device-id 合同再次漂移。
- 不修改账号凭据、token 生命周期、gateway ownership、App 注册方式或任何其它平台语义。

### Diagnostic run 4 — `34015769297`

- Workflow source: `cd96890365298768488d2489267416edf48a376d`; release under test: `desktop-1.2.21-4bc3e832fffe` -> `4bc3e832fffe4eaff21aa6fbf617a33133302c62`; installed version `1.2.21.0`.
- Exact device id rejected: `gha-34015769297-1-windows-app`.
- Exact errors: both protected account helpers threw `DEVICE_ID must be a protected GitHub Actions test device id.`; `FABUSHI_CI_ACCOUNT_SESSION_FILE` therefore did not exist.
- No App-owned Windows device was registered; zero semantic device calls completed.
- Failure evidence artifact: `9983870969`, `fabushi-windows-interactive-evidence-34015769297-1`, 117,772,660 bytes, uploaded on failure.
- PR `#2396` subsequently passed required merge-queue CI run `34019687072` and merged to canonical main as `820ae7ecea1cca8f6d399fbb4089867bc7614cfd`; later Android version PR advanced canonical main to `6ea18f731759081a5e64d26ccb10d31d1f720ea6` before this atomic allowlist branch was cut.

### Acceptance for atomic problem 002

- [ ] narrow CI proves the three protected-account helper sources accept exact `gha-<run>-<attempt>-windows-app` while retaining numeric run/attempt and exact suffix constraints.
- [ ] fix PR merges through the protected merge queue.
- [ ] canonical main is then bumped to a strictly newer desktop/Windows test version and a new Windows installer Release is published.
- [ ] the new Release run logs in, exports a bounded session, launches the installed App, and the App itself registers the new Windows device.


## 2026-09-06 Windows 1.2.40 retest candidate

Protected merge of the allowlist repair PR `#2408` produced canonical `main@f73366aba896a1d6e71a7cbdeb87b044d67f59f3`; canonical version remained `1.2.39`. The next governed candidate is therefore `1.2.40` on `release/tfi-windows-1-2-40-20260906`. This branch changes version mirrors/release assertions plus this task's durable evidence only; no product behavior changes are included. Status remains `IN_PROGRESS` until the version PR merges through the queue, an immutable Windows installer Release is published from exact protected main, a fresh App-owned Windows device appears, all six semantic tools and the full journey with final logout pass, and the required video/screenshots/trace/log/report artifact is verified.


## 原子问题 003 — post-main iOS UI test 仍假设认证后直接进入 legacy app-shell

Windows `1.2.40` exact-main Electron run `34020086944` 已证明 Windows package 与 packaged Windows journey 成功，但 governed post-main delivery 被 exact-source Native mobile run `34020086941` 阻塞。Native iOS job `101450938184` 的两个真实 UI case 各两次稳定失败在旧 helper 的 `app-shell` 等待；当前产品认证后先进入 `GrokMobileShell` 的 `grok-mobile-home`，legacy workbench 是显式入口。修复必须只补现有入口的稳定 XCTest identifier 并校正测试导航，不修改产品登录/导航语义。完整证据见 `evidence/TFI-WINDOWS-RELEASE-E2E-001/2026-09-06-postmain-ios-grok-shell-test-contract.md`。

## 原子问题 004 — Windows protected login helper 硬编码 POSIX RUNNER_TEMP 分隔符

### Live failure

- Windows interactive run `34023032996` / job `101458986749` 在 `main@2ec0fbd5cc30a61e043e5050dff4a70e8a33e06e` 上执行。
- Workflow 成功解析并安装当时仍为最新的 Windows installer：`desktop-1.2.21-4bc3e832fffe` -> `4bc3e832fffe4eaff21aa6fbf617a33133302c62`，`fabushi-1.2.21-setup.exe`，installed `1.2.21.0`。
- Whole-session recording 已在 installer 前启动；Windows workflow ownership/allowlist contract 4/4 通过。
- 受保护账号登录前，`login-ci-test-account.mjs` 抛出 `Fabushi account session must live under RUNNER_TEMP.`。该 run 的合法路径实际为 `D:\a\_temp\fabushi-account\session.json`。
- App 因此未启动、未自注册；本 run 没有可选 Windows App-owned device，semantic device-call 成功数为 0。
- always evidence artifact: `9986191161`, `fabushi-windows-interactive-evidence-34023032996-1`, 118,121,951 bytes, SHA256 `6c5587b847e69d7ce1ebcc30b4d96de758ae8191562ef4725928496f0aca8da3`。

### Root cause / smallest repair

`login-ci-test-account.mjs` 用 `sessionPath.startsWith(`${RUNNER_TEMP}/`)` 校验私有 session 路径，硬编码 `/`；Windows Actions 的 `RUNNER_TEMP` 和 session path 使用 `\`，所以合法路径被 fail-closed。仓库现有 `export-ci-app-account-session.mjs` 与 `renew-ci-app-account-session.mjs` 已使用 Node `path.resolve()` + platform `path.sep` 做同一安全边界，因此本修复复用该成熟模式，不引入新路径协议。

修复仅：
1. 对 login helper 的 session path 与 RUNNER_TEMP 做 `resolve()`；
2. 用 `${root}${sep}` 做 platform-aware descendant 检查；
3. 增加 Windows contract regression，禁止重新出现 `RUNNER_TEMP + '/'`；
4. 不修改账号凭据、token 生命周期、device-id allowlist、App-owned gateway ownership、发布选择或其它平台语义。

Branch: `fix/tfi-windows-runner-temp-path-20260906`。重型验证继续只走 GitHub Actions；修复合并后必须从最新 canonical main 严格升版并发布新的 Windows installer，再只用该 release/run 新注册的 App-owned Windows device 完成六工具与全 journey 验收。

## 2026-09-06 Windows 1.2.45 post-RUNNER_TEMP retest candidate

PR `#2423` repaired the Windows-only protected login path validation and merged as `main@43d8a1530868c2a8958778ae10e4ac9e8314aba8`. Before the governed version branch was cut, canonical main advanced again to `bea626269afd26f84e0b92b32bbf357beb481802` while remaining at semantic version `1.2.44`. The next eligible Windows package is therefore `1.2.45`, cut from that exact base. It is not accepted until the protected merge, exact-main Electron package/E2E, immutable tested desktop Release, newly self-registered `gha-<run>-<attempt>-windows-app` device, all six semantic tools, complete journey with final logout, and whole-session evidence all pass.

## 2026-09-06 Windows 1.2.48 live takeover

- Exact-main Electron run `34024602084` completed `success` for accepted SHA `a14ce9298a287953e6f9d457074367eeda4761b0`; Windows job `101463220859` built/tested version `1.2.45` from that same SHA.
- Post-main run `34025569116` bound `SOURCE_SHA=a14ce9298a287953e6f9d457074367eeda4761b0` and `ELECTRON_RUN_ID=34024602084`; it failed later on `Native mobile result` for the same SHA. This is not Windows SHA-binding drift, and release publication was skipped.
- Canonical `main@3ade251d5d73764255bac324d06fd788ec07edb2` already carries global version `1.2.47`, so the next governed Windows candidate is strictly newer `1.2.48` on `release/windows-1.2.48-20260906`.
- This continuation does not reopen completed `#2409/#2419/#2422` work.
- Status remains `IN_PROGRESS` until protected merge, exact-main/post-main delivery success, immutable Windows installer publication, a brand-new App-owned `gha-<run>-<attempt>-windows-app` self-registration, real six-tool + CI-session control, the complete Windows journey through final logout, and always-uploaded video/screenshots/trace/log/report evidence are all verified.

## 2026-09-06 Windows 1.2.48 native-iOS post-main blocker

Exact-main Windows `34027494210 / 101470965448` passed on `9ab20bc7c4547fa8d8a6c073f7eb859fbb696fe3`, produced `fabushi-1.2.48-setup.exe`, ran 27/27 packaged Electron tests, and uploaded Windows package/diagnostic artifacts. The same-SHA native run `34027494208` then failed only its iOS UI job `101470965413`; Android passed. The iOS failure repeated at the remote-computer `返回` control because the root `remote-computer-surface` accessibility identifier projected onto the child Button and XCTest could not complete `AXScrollToVisibleAction`. Candidate `1.2.48` is therefore superseded and must not be published. Atomic repair branch `fix/tfi-ios-remote-close-ax-containment-20260906` contains only the iOS accessibility-containment correction plus project evidence; after protected merge the governed Windows release must advance to a strictly newer version from then-current canonical main.

## 2026-09-06 Windows 1.2.50 governed retest after iOS AX repair and Android version advance

PR #2434 protected-merged the remote-computer Accessibility containment repair as `a2c25b12f64e3e8076bd456f90bd5d49a1677154`. The failed `1.2.48` candidate is superseded. While the Windows release PR was validating, protected Android PR #2436 advanced canonical main to global version `1.2.49` as `496d9f0910b1fced2eb594eded5310d5b8e5612c`. The existing Windows PR was therefore dequeued, updated with that exact main, and advanced strictly again to global version `1.2.50`. Protected macOS PR #2435 then advanced canonical main to `49c9c4c91157898f97a8cd74e222a7d505d83fcb` while retaining global `1.2.49`; #2437 was resynchronized to that final base without another version bump. Full acceptance still requires same-SHA Electron + Native iOS/Android success, successful post-main source binding/publication, a fresh run-bound App-owned Windows device, all six semantic App tools plus CI-session controls, the complete Windows functional journey, final `settings-logout`, and complete always-upload evidence.

## 原子问题 005 — Rust Host 未允许 Windows App-owned bounded CI session

- Diagnostic baseline: `main@2bfa9898d453a91119f7dd9a072322970423cd6b`, Windows interactive run/job `34060996833` / `101561382562`.
- Exact Release resolution/install/login passed: `desktop-1.2.53-2bfa9898d453`, installed `1.2.53.0`, bounded refresh-token-free session exported for `gha-34060996833-1-windows-app`.
- Always-upload artifact `9997771414` proves the installed App failed to register; App stdout repeatedly reports `CI account session failed its provenance, identity, or lifetime contract`; `device-calls.jsonl` stayed empty and Playwright was skipped.
- Source audit on protected `main@74f92d67575650b6fe44686d777ed47865389edb` proves the Rust validator admits only `-interactive|-macos-app`, while the protected JS login/export/session helpers already admit the exact set `interactive|ios-app|macos-app|windows-app`.
- Minimal repair: add only exact `device_id.ends_with("-windows-app")` to the Rust predicate and extend the existing account-binding contract. Preserve provider/ciRunner/Bearer/no-refresh-token/token safety/session prefix/`gha-` prefix/user identity/30-second-to-5-hour lifetime gates and App-owned gateway ownership.
- Acceptance: required PR CI green -> normal protected merge -> re-read new main -> exact-main Electron/Native/security/post-main/Release -> fresh Windows interactive App-owned registration -> all six semantic tools, full journey, final logout, and full video/screenshots/trace/Playwright/App logs/Release metadata artifact.
- No local build/test; GitHub Actions remains the only execution gate.
