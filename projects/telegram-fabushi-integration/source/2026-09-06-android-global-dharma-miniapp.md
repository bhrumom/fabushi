# 2026-09-06 — Android 全球法布施 Mini App 主线需求

## User request

在 Fabushi canonical main 和既有统一 WebMCP / Mini App Host 上推进 Android “全球法布施”，不得另起 Bot、账号、支付账本或第二套 Mini App runtime：

1. Marketplace 可搜索并安装“全球法布施”。
2. 安装后统一 Messenger 中出现该 Mini App 的 canonical Bot projection。
3. Bot 自然语言请求继续走 manifest/Host 已定义的统一 WebMCP Tool contract 与同一 runtime，不新建第二 Agent backend。
4. Bot 顶部“打开应用”进入 Telegram Mini App 类 Web UI；已安装本地 HTML 优先，Hosted 仅做受控 fallback。
5. Bot 与 Web UI 必须共享同一 App-owned Mahayana Host、同一操作/状态事件源；Bot 执行到哪里，Web UI 可实时观察同一状态。
6. Fabushi 已登录账号通过现有 `feature.auth.*` 会话向本地 Mini App 投影最小安全身份，不提供第二登录页，不向 WebView 暴露 refresh token / device credential。
7. CNY 1080 lifetime “本地转经轮”必须使用 canonical Fabushi Pay / PLATFORM_DB entitlement，精确能力为 `local.prayer-wheel.start`；Android 测试模式支持购买、恢复与授权校验。客户端状态、WebView storage、SharedPreferences 均不得解锁该能力。
8. Google Play/PSP 商品、测试账号、provider binding 或沙箱配置缺失时 fail closed，并保存精确阻塞证据，不伪造 purchase/restore success。
9. 遵守 `FAB-P0001/TFI` 与 `FAB-P0008/AAC` 治理。重型 Android build、packaging、instrumentation、模拟器/设备 E2E 只在 GitHub Actions。
10. packaged app 完整旅程必须保存逐步截图、完整操作视频、instrumentation report、logcat、App-owned gateway trace 和报告，并提供真实可下载 artifact/video URL。
11. `fabushi test` 仅能在 APK 已安装、Fabushi 已登录、且 App 自己完成 `github-actions-android-app` App-owned device 注册后发现/控制该设备；严禁等待不存在的 runner 预安装、使用 runner-owned gateway、KRIS、旧设备或历史 run 设备替代。

## Existing canonical boundaries to reuse

- `FAB-P0001 / TFI` Marketplace 是唯一 catalog；WebMCP 是打开 Mini App 后的前台统一 Agent Tool API；Host/Rust/CLI/Bot 都是同一 capability/tool truth 的投影或适配器。
- `M8-WEBMCP-001` 已在 Android 提供 local-first controlled WebView、Tool contract 注入、native approval 和 Rust `runtime.call`。
- `M9-GLOBAL-DHARMA-003` 已由 PR #2135 建立 server-authoritative Global Dharma entitlement truth：CNY 30 / 30-day + CNY 1080 lifetime，均映射 `local.prayer-wheel.start`；Apple/Google provider binding 未 active 时不得显示为可购买 rail。
- `FAB-P0008 / AAC` 是账号级角色/entitlement 审计真源；Android Mini App 只消费既有 Fabushi account session 与 canonical entitlement decision。
- `TFI-M11-ANDROID-INTERACTIVE-001` 已定义 released-APK、录制先于安装、登录后 App-owned self-registration、六个 `fabushi.app.*` semantic tools 与 always-upload evidence 门禁。

## Open-source-first startup gate

本轮先比较并只采用可安全复用的模式，不复制不相容代码：

- Telegram Android (`DrKLO/Telegram`, GPL-2.0): 只参考 Mini App / WebView / Bot menu interaction pattern；不复制 GPL 产品代码到 Fabushi。
- AndroidX WebKit (`androidx/androidx`): 参考 origin-scoped WebView bridge/message 安全边界；优先继续使用现有 local-only Native bridge 与 origin allowlist，而不是自造无边界 JS bridge。
- Google Play Billing samples (`googlesamples/play-billing-samples`): 参考一次性商品 purchase lifecycle、pending/acknowledgement/re-query/restore 测试语义；Google receipt 只能作为 canonical Fabushi Pay server verification 的输入，客户端 Billing 状态不能成为 entitlement truth。

结论：复用现有 Mahayana Host、Mini App manifest、WebMCP、Fabushi Pay 和 AAC；本轮只补 Android projection/bridge/gate/test gaps。

## Acceptance invariants

- One Bot truth: Mini App Bot identity/menu metadata来自 canonical Marketplace manifest/installed state；不创建独立 Bot storage。
- One auth truth: 只用现有 Fabushi account session；Mini App 只收最小身份投影。
- One event truth: Marketplace/Bot/WebView 共享同一 process-owned Mahayana Host session；不以两个独立 native Host 实例伪装实时同步。
- One pay truth: `local.prayer-wheel.start` 的 allow/deny 只来自 canonical server entitlement access decision。
- Purchase amount/currency/SKU/provider 由 server `purchaseOptions` 决定；Android client 不接受 caller-supplied amount/currency。
- Lifetime purchase/restore 重试必须幂等；无 entitlement 时 capability 必须 fail closed。
- 本轮只有 protected PR merge、canonical main readback、exact-main packaged Android journey 和完整 evidence 全部通过后才能标记完成。
