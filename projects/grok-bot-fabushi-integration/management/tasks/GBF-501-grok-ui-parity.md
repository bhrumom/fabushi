# GBF-501 — Grok UI / interaction parity

- **Project ID**: `FAB-P0004`
- **Project Key**: `GBF`
- **Task ID**: `GBF-501`
- **Stage**: `M5 UI 与动画引擎`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-24`
- **Updated**: `2026-08-24`
- **Branch**: `feat/gbf-grok-parity-v1`

## Objective

把当前混合 Telegram 亮色视觉的 Desktop Messenger 收敛为 Grok/Fabushi 单一视觉语言，在不删除现有消息、支付、Mini App、通话、搜索、设置能力的前提下，实现 Grok Bot 可观察的深色层级、紧凑密度、浮层、composer、侧栏和动态身份表现。

## Source

- `../../source/2026-08-24-grok-parity-reimplementation.md`
- `../../source/grok-bot融合优化.txt`
- pinned historical Grok inputs/evidence under `evidence/GBF-101..105`
- existing Fabushi BotMark engine and canonical Electron Messenger on `main`

## Open-source-first review

- `xai-org/grok-build` (Apache-2.0, Rust): reviewed as a current official xAI open-source agent implementation and evidence that Rust remains compatible with the product direction. It is not a drop-in desktop Messenger/UI implementation, so this task does not vendor it.
- Existing Fabushi React/Electron/CSS Modules and Rust Mahayana Host are reused rather than introducing a second UI/runtime framework.
- Grok Bot production/reference assets with unclear provenance remain behavior/reference-only; production code is rewritten in Fabushi-owned files.

## Acceptance criteria

1. Authenticated desktop shell defaults to a coherent dark Grok/Fabushi material instead of Telegram white/bright-blue primary styling.
2. Sidebar, peer list, workspace, chat header, message bubbles, composer, info panel, popovers/dialogs, search/settings and marketplace surfaces share the same color/material/spacing system.
3. Existing BotMark motion remains the only animated identity primitive and is visually integrated into the new surface.
4. Existing functional selectors and product behavior remain intact; styling changes do not create a parallel Messenger implementation.
5. Electron typecheck/build, Messenger/packaged Playwright and relevant governance checks pass on GitHub Actions before task closure.
6. Task remains `IN_PROGRESS` until protected merge, canonical-main readback, packaged E2E and Release evidence are complete.

## Implementation round 1

- Add a dedicated, product-owned `grok-parity.css` surface layer loaded by Electron/Vite.
- Scope it with a root `data-fabushi-surface="grok-parity-v1"` marker so parity styling can be audited/removed independently.
- Convert the visible Telegram light palette to a dark graphite/black material with low-contrast borders and restrained blue accent.
- Preserve existing React components and selectors so runtime behavior is unchanged in this first visual convergence round.

## Verification

- Static HTML/CSS contract check: parity stylesheet is bundled from `public/` and explicitly linked from `index.html`.
- Existing Electron/Messaging CI must typecheck/build and run packaged journeys.
- Visual screenshot/E2E comparison will be added in follow-up GBF-501/502 rounds.

## Blockers / risks

- This round establishes the common visual substrate; exact pixel/animation parity still requires follow-up screenshot-driven tuning and BotMark state integration.
- Grok proprietary/vendored reference code must not become a production dependency.

## Next action

Land the parity theme layer, then add screenshot contracts and state-driven BotMark/UI transitions before promoting GBF-501 beyond `IN_PROGRESS`.
