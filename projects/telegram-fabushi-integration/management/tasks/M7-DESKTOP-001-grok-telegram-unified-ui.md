# M7-DESKTOP-001 — Grok Bot × Telegram unified desktop UI

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M7-DESKTOP-001`
- **Stage**: `M7 Bot/Agent 统一联系人体系`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-23`
- **Updated**: `2026-08-23`
- **Branch**: `feat/tfi-m7-grok-telegram-unified-ui`
- **Implementation commit**: `9c31c73dde2cbe8c3dc2246ea9918f1f32409e87`
- **PR**: `#2046`

## Objective

将现有 Grok/Fabushi Agent 交互设计融合进 Telegram-class Messenger，而不是继续维持“AI 工作区”和“消息工作区”两套产品界面。最终桌面端只保留一套 Fabushi Messenger Shell：真人、Bot、AI Agent、群组、频道、Mini App、支付共用同一信息架构和视觉语言。

同时修复当前桌面登录入口暴露的生产控制平面 404 回归：生产部署必须显式验证 `/api/auth/browser/start`，避免 `api.ombhrum.com` 回落到 legacy Worker 404。

## Source requirements

- `docs/02-产品需求-PRD.md`：AI Agent 是一等联系人，通信不是外挂 IM。
- `docs/07-客户端架构与交互.md`：桌面端采用 Telegram 类成熟 IM 密度，但必须使用 Fabushi 设计语言。
- `management/wbs/M7.md`：真人和 Agent 使用同一消息内核，UI 不再使用独立第二套聊天实现。
- 用户 2026-08-23 明确要求：把 Grok Bot 融合进 Telegram UI，吸收 Grok Bot 的优秀设计，并修复当前登录错误与双侧边栏。

## In scope

- 移除 DesktopShellV2 最外层 `AI / 消息` 产品切换 rail，避免双侧边栏。
- Messenger 成为唯一桌面主壳；AI/Bot 作为统一 peer/conversation 出现在同一会话系统。
- 复用 Fabushi Motion v2 / BotMark 作为 AI Bot/Agent 的动态身份头像，并在列表、会话 header、资料页体现运行状态。
- 调整 Messenger 视觉层：更接近 Grok/Fabushi 的深色、玻璃、动态层次，但保留 Telegram 的高密度信息架构与交互效率。
- 为生产 Worker smoke 增加 `/api/auth/browser/start` 路由验证，防止 browser-first auth 404 回归。
- 更新 Playwright/静态契约，明确只允许一套 desktop navigation shell。

## Out of scope

- 本任务不重写 Rust Messaging Core。
- 不引入第二套 Agent runtime / Host runtime。
- 不复制 Grok 商标、品牌资源或外部运行时；仅融合已经进入 Fabushi 的自研 Motion v2/Agent 交互能力。

## Acceptance criteria

1. Electron renderer 不再渲染 `productRail` 的 `AI / 消息` 双产品切换。
2. Messenger 主导航只保留一套 rail；Bots/Agents 与真人联系人在同一会话列表/聊天区工作。
3. AI/Bot peer 使用 `BotMark` 动态身份表现，运行中/等待审批/失败等状态能映射到视觉状态。
4. Playwright 明确断言不存在第二层 `AI / 消息` rail，并继续覆盖 Telegram-class 导航与 AI peer 消息发送。
5. `deploy-production.yml` 的 production smoke 对 `/api/auth/browser/start` 发起真实 POST，并拒绝 404/legacy fallback。
6. GitHub Actions 的 desktop/typecheck/Playwright/Worker relevant gates 通过后才允许提升为 TESTED。
7. 受保护 main 合并并 canonical readback 后才允许完成任务。

## Implementation summary

- DesktopShellV2 已移除外层 `AI / 消息` product rail；预登录阶段继续复用现有 browser-first Host 登录体验，认证成功后直接切入唯一 Messenger。
- Messenger rail 成为唯一主导航，品牌按钮返回 Chats，不再返回独立 AI workspace。
- AI/Bot peer 的列表头像、会话 header、空态和资料页复用 `BotMark` / `fabushi-motion-v2`；`MessagingBotExecution` 的 `queued/running/waitingForApproval/completed/failed/cancelled` 映射到动态视觉状态。
- Messenger 新增 Fabushi/Grok 风格的深色、玻璃、紫色动态材质层，同时保留 Telegram-class 三栏布局、高密度操作和统一 composer。
- Desktop E2E 新增“不存在 `open-messenger` 第二产品切换器”与 Assistant peer Motion v2 identity 断言。
- Production smoke 新增真实 `/api/auth/browser/start` POST、payload/schema/origin/legacy-fallback 检查。

## Verification / evidence

- Lightweight source gate: `git diff --check` — PASS on implementation branch.
- Live production probe on 2026-08-23: `POST https://api.ombhrum.com/api/auth/browser/start` returned **HTTP 404** with `This Cloudflare Worker is an API backend only.`. This proves the user-visible login defect is still present in production before the repair is deployed.
- PR #2046 current-head workflows started for commit `9c31c73d...`: `Messaging Product Gate`, `Fabushi self-hosted messaging`, `Electron desktop quality gate`, repository `CI`, and `Project portfolio governance`.
- Heavy build/E2E verification remains GitHub Actions only per repository policy.

## Risks / blockers

- Current production custom domain is still serving the legacy 404 path for browser auth; completion is blocked until protected merge + production CD + endpoint readback.
- Messenger still includes the intentional legacy Host conversation adapter during migration; this task must not create an additional state machine.
- BotMark is reused from the canonical Fabushi Host UI module; CI must prove cross-surface import/build compatibility.

## Next action

Wait for PR #2046 current-head CI. Repair any failures on the same branch, then merge through protected main, let Worker production CD run, verify `/api/auth/browser/start` no longer returns the legacy 404, and only then close project records.