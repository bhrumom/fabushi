# TFI-M11-ANDROID-GLOBAL-DHARMA-001 — Android 全球法布施 Mini App 主线

- Project: FAB-P0001 / TFI
- Cross-project dependency: FAB-P0008 / AAC
- State: IN_PROGRESS
- Baseline: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`
- Branch: `feat/tfi-android-global-dharma-miniapp-20260906`
- Source: `projects/telegram-fabushi-integration/source/2026-09-06-android-global-dharma-miniapp.md`

## Scope

在 Android 默认统一 Messenger 上复用现有 Marketplace、Mahayana FeatureHost、WebMCP/Mini App Host、Fabushi account session 与 Fabushi Pay，完成“全球法布施”安装→Bot→自然语言 WebMCP→打开 Web UI→实时状态同步→Fabushi 自动登录→CNY 1080 lifetime 本地转经轮 entitlement 购买/恢复/权限保护的真实 packaged-app 旅程。

## Invariants

1. **No second Bot**: Bot identity/menu/conversation metadata 只由 canonical Mini App manifest/installed projection产生，不创建 Android 私有 Bot 数据库。
2. **No second auth**: Mini App 只消费现有 `feature.auth.status` 的最小账号投影；不暴露 refresh token、device credential、session secret。
3. **One Host/event truth**: Android Marketplace/Bot/WebView 复用同一 process-owned Mahayana AppHost session 与事件分发；禁止以多个独立 `MahayanaHost` controller 模拟同步。
4. **One WebMCP truth**: Web UI Tool contract 继续调用 native approval + Rust `runtime.call`，Hosted fallback 不得获得 local native bridge。
5. **One pay truth**: `local.prayer-wheel.start` 只认 canonical server entitlement decision；WebView/local preferences/Play Billing local state均不可直接解锁。
6. **Server-authoritative price**: lifetime 固定由服务端 `purchaseOptions` 选择 `CNY 1080`；caller 不得传价格/币种覆盖。
7. **Fail closed**: Google Play provider binding、test product、tester、signed package/Play sandbox 任一缺失时记录 BLOCKED，不伪造购买/恢复成功。
8. **CI-only heavy work**: Android build/package/instrumentation/emulator/device E2E 只在 GitHub Actions。
9. **App-owned control**: `fabushi test` 仅控制本轮 packaged APK 已安装、Fabushi 已登录、App 自注册且绑定 run 的 `github-actions-android-app` 设备；不等待 runner 预安装，不使用 KRIS/旧设备/runner-owned gateway。

## Atomic rounds

### A — Shared Android Host/event session
- [ ] MarketplaceViewModel 与 MobileBotViewModel 使用同一 App-owned Mahayana host session。
- [ ] 唯一 `feature.receive` pump 将 Host events fan-out 给 Bot 和 Mini App Web UI，防止多个 controller/consumer 抢事件。
- [ ] native WebMCP `runtime.call` 继续在同一 session 上执行。

### B — Marketplace → Bot → Open app projection
- [ ] 搜索“全球法布施”得到 canonical `global-dharma` listing。
- [ ] install 完成后记录 installed projection，并从 manifest bot metadata 投影到默认 Messenger Bot 列表。
- [ ] Bot header 提供 canonical menu button（用户可见“打开应用”），打开现有 `MiniAppWebMcpSurface`。
- [ ] 自然语言仍通过现有 FeatureHost/Bot/WebMCP contract 执行；不新增第二 backend。

### C — Auth + realtime Web UI bridge
- [ ] local installed Web UI 获取最小安全 Fabushi identity projection；无第二登录页。
- [ ] Web UI 接收同一 Host operation/chat/agent/miniapp event 的安全投影并触发 DOM event。
- [ ] hosted fallback 保持 origin isolation，不注入本地 native auth/WebMCP bridge。

### D — CNY 1080 lifetime entitlement
- [ ] Android Host 可读取 canonical `global-dharma / local.prayer-wheel.start` access + `purchaseOptions`。
- [ ] test mode purchase 通过 canonical Fabushi Pay test backend/ledger，idempotency replay 不重复 entitlement。
- [ ] restore 重新读取 server purchase/entitlement truth；无 client-local unlock。
- [ ] `local.prayer-wheel.start` Host request 在 native boundary 强制 entitlement gate。
- [ ] Google Play sandbox provider 未 active/configured 时 rail fail closed 并输出结构化 blocker。

### E — GitHub Actions packaged journey
- [ ] PR narrow CI：Rust/Kotlin static/unit + Android assemble + instrumentation。
- [ ] protected merge 后 exact-main 严格递增 Android 测试版本。
- [ ] recording before install → exact released APK install → test-account login → App-owned device self-registration。
- [ ] 只选择本轮 fresh Android App-owned device，真实调用 `fabushi.app.status/snapshot/find/action/wait/assert`。
- [ ] 用户旅程：Marketplace 搜索→安装→Messenger Bot→自然语言→WebMCP→打开应用→状态同步→购买/恢复 lifetime entitlement→本地转经轮 gate→最终 logout。
- [ ] always upload：完整视频、meaningful checkpoint 截图、instrumentation report、logcat、trace、release identity/checksum、report/logs（失败也上传）。
- [ ] evidence index 写回本任务及 `projects/telegram-fabushi-integration/evidence/TFI-M11-ANDROID-GLOBAL-DHARMA-001/README.md`，所有 URL 必须真实可下载/可读回。


### F — Packaged Bot canonical installed projection repair (2026-09-07)

- Triggering exact-main run: `34048304925` on `8595a50196309c8ebb91c3f8077125d7dc9e3ffa`.
- Triggering App-owned device: `gha-34048304925-1-interactive`; device is now offline and must not be reused.
- Existing evidence artifact: `9994017895` (`android-interactive-app-e2e-34048304925-1`).
- Implementation baseline: live canonical `main@c82b29cd6404c2f19b93d8479b2e2cae45469249`; the intervening main commit changes Web/service/AAC surfaces, not Android app files.
- Verified boundary: `refreshBots()` coupled canonical projection read to repeated `POST /v1/marketplace/plugins/{id}/add` writes and treated any HTTP/manifest/projection failure as an all-or-nothing Bot refresh. The packaged artifact retained only the generic UI failure plus later stale semantic generations, so the exact prior HTTP status/body is not recoverable from that artifact.
- Repair branch: `fix/tfi-android-bot-installed-projection-20260907`.

Acceptance for this atomic repair:

- [ ] Marketplace install is not called successful until account-authoritative `/v1/marketplace/added` contains the installed plugin.
- [ ] Messenger installed-Mini-App refresh is read-only and never calls `/add` or `feature.plugin.listInstalled` to mutate/reconcile account state.
- [ ] A failed canonical refresh retains the last validated in-process canonical Mini App projection; no Android-private persistent Bot/install database is introduced.
- [ ] Exact projection/HTTP diagnostic remains visible in UI and through `grok-bot-error` semantic status without hiding retained Bots.
- [ ] PR contract Action compiles Kotlin, validates the projection/packaged-E2E semantic contract, and uploads a contract evidence artifact.
- [ ] After protected merge/release, a fresh App-owned Android device reruns Marketplace→全球法布施 install→Messenger Bot→WebMCP→Open App/revision sync→auth→test-mode CNY1080 purchase/restore→entitlement→local prayer wheel. Until generated, new video/screenshots/trace/report remain `PENDING`.

## Completion gate

只有受保护 PR 合并、canonical main SHA 回读、post-main delivery gate、exact released packaged Android 旅程、六工具 App-owned 控制、entitlement fail-closed/购买/恢复证据和完整 artifacts/video 都通过，才允许 `DONE`。任一外部支付沙箱/设备/签名/权限事实缺失则保持 `BLOCKED` 并记录精确 live evidence。

### G — Protected packaged retest release 1.2.52 (2026-09-07)

- Repair PR #2451 protected-merged as `8103b2d495f4223a4736be65ce4c0cfc0a1fbabc` after required checks.
- PR contract evidence: run `34050104893`, job `101532053914`, artifact `9994301970`.
- Canonical version before this round: `1.2.51`; next governed Android test version: `1.2.52`.
- [x] Protected version PR merged to canonical main (`380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab`).
- [x] Exact-main Native Android GitHub release succeeds: `android-v1.2.52-262491811`, run `34050780156`, artifact `9994614114`.
- [x] Fresh App-owned device `gha-34051316405-1-interactive` self-registers from the released APK in run `34051316405`.
- [ ] Six semantic tools drive the complete Global Dharma packaged journey.
- [ ] Full video, meaningful screenshots, trace/report/logcat/release identity are always uploaded and linked here.

### H — 1.2.52 packaged retest result

- Interactive run `34051316405` / job `101535343430`: **FAILURE** at final evidence gate; artifact `9994884584` is retained.
- `report.json`: `status=failed-timeout`, release `android-v1.2.52-262491811`, release/workflow SHA `380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab`, fresh device `gha-34051316405-1-interactive`.
- Trace contains successful `fabushi.app.status`, `snapshot`, `find`, `action`, `wait`, `assert` calls; two action calls fail `stale_app_surface_generation`.
- Terminal connection failure: `connection-refresh-failed` with `transport_error:IllegalStateException`, followed by `disconnected reason=refresh-failed`; no `disconnected reason=logged-out` appears.
- Evidence includes 21 step screenshots, trace, logcat and six screenrecord segments. `android-session.mp4` was not produced, so a single complete video link is PENDING.
- Next atomic repair must address the App-owned refresh/session lifecycle and generation-safe action continuation, then publish a strictly newer Android test release and rerun from a fresh App-owned device.
