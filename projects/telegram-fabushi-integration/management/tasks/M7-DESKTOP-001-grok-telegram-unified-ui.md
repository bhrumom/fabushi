# M7-DESKTOP-001 — Grok Bot × Telegram unified desktop UI

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M7-DESKTOP-001`
- **Stage**: `M7 Bot/Agent 统一联系人体系`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-23`
- **Updated**: `2026-08-23`
- **Primary implementation PR**: `#2046`
- **Product-gate repair PR**: `#2048`
- **Auth gateway repair PR**: `#2049`
- **macOS Keychain/formal package repair PR**: pending

## Objective

将 Grok/Fabushi Agent 的优秀交互设计融合进 Telegram-class Messenger，而不是继续维持“AI 工作区”和“消息工作区”两套产品界面。最终桌面端只保留一套 Fabushi Messenger Shell：真人、Bot、AI Agent、群组、频道、Mini App、支付共用同一信息架构和视觉语言。

同时修复用户当前看到的 browser-first 登录 404，确保 `api.ombhrum.com/api/auth/browser/start` 真实到达 Mahayana Platform，而不是落到 legacy Worker 或 Cloudflare workers.dev placeholder。

## Source requirements

- `docs/02-产品需求-PRD.md`：AI Agent 是一等联系人，通信不是外挂 IM。
- `docs/07-客户端架构与交互.md`：桌面端采用 Telegram 类成熟 IM 密度，但使用 Fabushi 设计语言。
- `management/wbs/M7.md`：真人和 Agent 使用同一消息内核，UI 不再使用独立第二套聊天实现。
- 用户 2026-08-23 明确要求：把 Grok Bot 融合进 Telegram UI，吸收 Grok Bot 的优秀设计，并修复当前登录错误与双侧边栏。

## In scope

- 删除 DesktopShellV2 最外层 `AI / 消息` 产品切换 rail，避免双侧边栏。
- Messenger 成为唯一桌面主壳；AI/Bot 作为统一 peer/conversation 出现在同一会话系统。
- 复用 Fabushi Motion v2 / BotMark 作为 AI Bot/Agent 动态身份头像，并把执行状态映射到视觉状态。
- 将 Messenger 视觉层收敛为 Fabushi/Grok 深色、玻璃、动态层次，同时保留 Telegram 的高密度信息架构与成熟交互。
- 修复生产 browser-first auth 网关并建立部署 smoke 防回归。
- 修复 macOS browser-login 回跳触发历史 `mahayana-cli` Keychain 密码弹窗；正式安装包必须使用稳定 Developer ID、Apple notarization/stapling，并完整携带 Host、ASR、图标与隐私说明。

## Out of scope

- 不重写 Rust Messaging Core。
- 不引入第二套 Agent runtime / Host runtime / messaging state machine。
- 不复制 Grok 商标、品牌资源或外部运行时；仅融合已经进入 Fabushi 的自研 Motion v2/Agent 交互能力。

## Acceptance criteria

1. Electron renderer 不再渲染外层 `AI / 消息` 双产品切换。
2. Messenger 主导航只保留一套 rail；Bots/Agents 与真人联系人在同一会话列表/聊天区工作。
3. AI/Bot peer 使用 `BotMark` 动态身份表现，运行中/等待审批/失败等状态能映射到视觉状态。
4. Playwright 明确断言不存在第二层 `AI / 消息` rail，并覆盖 AI peer 在统一 composer 发送消息。
5. 生产 `POST /api/auth/browser/start` 返回 200 且 payload 含 `attemptId` / `pollSecret` / `loginUrl`，不得返回 legacy/Cloudflare 404。
6. Desktop/Messaging/Platform relevant GitHub Actions 通过。
7. 受保护 main 合并、production CD 与 canonical/live readback 后才允许关闭任务。
8. Electron 桌面认证不得读取历史 `mahayana-cli` / `codex` Keychain ACL；升级后允许一次 browser-first 登录建立新的 Fabushi desktop secret namespace，但不得要求用户输入 macOS 登录钥匙串密码。
9. 正式 macOS 包中 App、`mahayana-app-host`、离线 ASR 必须归属于同一个非空 Apple TeamIdentifier；App 与 DMG 均须 notarize + staple + Gatekeeper 验证，且签名后的生产 App 禁止原地 hot-patch。

## Implementation summary

### UI convergence — PR #2046

- `DesktopShellV2` 已移除外层 `AI / 消息` product rail；未登录继续复用 browser-first 登录体验，认证后直接进入唯一 Messenger。
- Messenger rail 成为唯一主导航；AI/Bot 与真人 peer 共用列表、聊天区和 composer。
- 列表头像、会话 header、空态和资料页复用 `BotMark` / `fabushi-motion-v2`。
- `MessagingBotExecution` 的 `queued/running/waitingForApproval/completed/failed/cancelled` 映射到动态视觉状态。
- Messenger 吸收 Fabushi/Grok 的深色玻璃、紫色动态材质和状态反馈，同时保留 Telegram-class 三栏密度与交互效率。
- E2E 新增“不存在 `open-messenger` 第二产品切换器”以及 Assistant Motion v2 identity 断言。
- #2046 已通过受保护流程合并到 `main`，merge commit `fea29e5c7958c31461af555f4292bfbf9ee443cc`。

### Final messaging product gate — PR #2048

- 广义 Messaging Product Gate 暴露既有 Feature Host 测试使用已移除 `now_seconds()` 的编译错误。
- #2048 将测试时钟改为 canonical `now_millis() / 1_000`，已合并到 `main`，merge commit `ccd84bf5f9533ca4938c01715431798a7645d254`。
- Messaging Product Gate run `32623488713`：SUCCESS；Electron Messenger contract、TypeScript Messenger V2、Rust self-hosted messaging/Feature Host bridge 均通过。

### Browser-auth root cause and service-binding repair — PR #2049

- #2046 后 production CD run `32623442672`：staging Worker deploy 成功，但 staging API E2E 失败，因此 production deploy/smoke 被阻断。
- 现场探测确认：staging `/api/auth/browser/start` 响应带 `X-Fabushi-Control-Plane: mahayana-platform`，证明 Fabushi gateway 已命中；但响应体是 Cloudflare workers.dev `There is nothing here yet` 404。
- 同一时刻从外部直接调用 `https://mahayana-platform.bhrumom.workers.dev/api/auth/browser/start` 返回 200 和有效 browser-login attempt，证明 Mahayana Platform 本身健康。
- 根因收敛为同 Cloudflare account 内 Worker 通过 public `workers.dev` hostname 再 fetch 另一个 Worker 的不可靠 upstream hop。
- #2049 在 `fabushi/web/wrangler.toml` 为 default/development/production 增加 `MAHAYANA_PLATFORM -> mahayana-platform` Cloudflare Service Binding；gateway 优先使用 `env.MAHAYANA_PLATFORM.fetch()`，只保留 public HTTPS 作为 fallback。
- `platform-control-plane.test.js` 新增 service-binding 与 production/development binding 静态契约，防止未来回退到 public workers.dev hop。

### macOS Keychain prompt + formal package hardening — current repair

- 现场检查确认当前 `/Applications/fabushi.app` 与内置 `mahayana-app-host` 均为 ad-hoc 签名，`TeamIdentifier=not set`；同时登录钥匙串存在历史 `mahayana-cli` / `secrets|…` 项，因此回跳后的 Host 访问旧 ACL 会触发 macOS 密码授权弹窗。
- Electron Host 现在显式选择 `fabushi-desktop-v2` secret boundary：桌面 auth 与 managed/requested secrets 使用新的 Fabushi-owned Keychain services 和新的加密 `.age` 文件，不读取历史 `mahayana-cli`/`codex` ACL。旧桌面会话不会通过读取旧 Keychain 静默迁移；升级后最多需要重新完成一次 browser-first 登录。
- `desktop/package.json` 补齐正式 macOS Developer ID 构建配置：Hardened Runtime、显式 entitlements、1024px 正式 App icon、麦克风/摄像头用途说明、规范 artifact naming，以及 `afterSign` App notarization/stapling。
- `native-electron-release.yml` 与 canonical `electron-desktop.yml` 的 main/macOS 路径都会导入稳定 Developer ID、签名 Host 与离线 ASR、签名整个 Electron App、notarize/staple App，再 notarize/staple DMG。正式 release 仍生成 SHA256SUMS 并发布 GitHub Release。
- 新的 `verify-electron-macos-package.sh` fail-closed 验证 bundle id、App/Host/ASR TeamIdentifier 一致、`app.asar`、App icon、ASR license、隐私用途说明、code signature、stapler 和 Gatekeeper。
- 生产签名 App 不再允许 `app.asar`/Host 原地 hot patch；hot package 明确降级为开发 overlay，避免破坏 sealed code signature 后再次触发 Keychain/Notary 信任问题。

## Verification / evidence

- UI source + E2E: PR #2046 merged, `fea29e5c...`。
- Messaging product gate: run `32623488713` SUCCESS。
- Product-gate repair: PR #2048 merged, `ccd84bf5...`。
- Failed deployment evidence exposing auth root cause: CD run `32623442672`，staging deploy passed, staging API E2E failed, production skipped。
- Direct upstream probe: Mahayana Platform `/health` 200；direct browser auth start 200。
- Public production probe before #2049 deployment: `POST https://api.ombhrum.com/api/auth/browser/start` still returns HTTP 404 legacy fallback。
- Heavy build/E2E/deployment verification remains GitHub Actions only per repository policy。

## Risks / blockers

- #2049 current-head CI、protected merge、production CD 和 live endpoint readback 尚未完成，因此登录修复仍不可宣称完成。
- 当前用户安装的 Mac 客户端仍是 ad-hoc 包；必须在本修复合并后安装由 canonical main 产出的 Developer ID + notarized 完整包，并现场验证 browser-first 回跳不再出现 Keychain 密码弹窗。

## Next action

完成 macOS Keychain/formal-package repair 的 GitHub Actions 与 protected merge；等待 canonical main 产出 Developer ID + notarized macOS artifact，下载并替换 `/Applications/fabushi.app`，验证 App/Host/ASR TeamIdentifier、stapler/Gatekeeper、browser-first 登录回跳和最终统一 Messenger UI；无 Keychain 密码弹窗后再关闭 M7-DESKTOP-001。