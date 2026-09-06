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

## Completion gate

只有受保护 PR 合并、canonical main SHA 回读、post-main delivery gate、exact released packaged Android 旅程、六工具 App-owned 控制、entitlement fail-closed/购买/恢复证据和完整 artifacts/video 都通过，才允许 `DONE`。任一外部支付沙箱/设备/签名/权限事实缺失则保持 `BLOCKED` 并记录精确 live evidence。
