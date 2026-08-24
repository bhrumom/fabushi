# GBF-501 — Grok UI / interaction parity

- **Project ID**: `FAB-P0004`
- **Project Key**: `GBF`
- **Task ID**: `GBF-501`
- **Stage**: `M5 UI 与动画引擎`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-24`
- **Updated**: `2026-08-24`
- **Active branch**: `feat/gbf-grok-motion-parity-v1`
- **Merged rounds**: PR #2098, PR #2101

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
5. Agent states `thinking/searching/working/tool-running/speaking/result/error/alerting` have visibly distinct motion choreography without replacing the authoritative `fabushi-motion-v2` SVG engine.
6. Electron typecheck/build, Messenger/packaged Playwright and relevant governance checks pass on GitHub Actions before task closure.
7. Task remains `IN_PROGRESS` until protected merge, canonical-main readback, packaged E2E, screenshot-level comparison and Release evidence are complete.

## Implementation round 1 — merged PR #2098

- Added dedicated product-owned `desktop/public/grok-parity.css` loaded by Electron/Vite.
- Scoped with root `data-fabushi-surface="grok-parity-v1"` marker so parity styling can be audited/removed independently.
- Converted visible Telegram light palette to dark graphite/black material while preserving current React/runtime behavior.
- Added `desktop/e2e/grok-parity.spec.ts` and structured Mahayana Host lifecycle events/fault coverage in the same convergence round.
- PR #2098 merged to canonical `main` as `eae1503d0ca06fd099535bba34b96849874ffe04`.

## Implementation round 2 — merged PR #2101

- Calibrated the surface to the historical Grok renderer's observable metrics rather than approximate values: `#070707/#111111/#242424/#2f2f2f/#3b3b3b`, 54px sidebar header, 68px chat header, raised active rows, 760px composer, `#1c1c1c` composer material, user `#4a4a4a` bubble and unboxed assistant content.
- Only the Fabushi-owned parity stylesheet changed; no Grok runtime/vendor dependency was introduced.
- PR #2101 passed PR CI/Electron gates and merged through repository automation as `14d79649ff1c5d45382a4046c7c42882432321c8`.

## Implementation round 3 — active

- Add `desktop/public/grok-motion-parity.css` as an outer choreography layer around the existing `fabushi-motion-v2` engine.
- `thinking`: slow focus/breath + staggered thought particles.
- `searching`: radar/sweep cadence.
- `working/tool-running/writing/sending/receiving/uploading/dragging`: four-beat focus → act → settle → re-check microcycle so a long-running task is not a generic repeated pulse.
- `speaking`: tighter voice cadence.
- `result`: calm confirmation bloom.
- `error/alerting`: deliberate two-beat signal instead of constant frantic motion.
- Reduced-motion disables all added choreography.
- Add packaged Electron Playwright CSSOM/computed-style contract proving the state selectors and keyframes are actually loaded/applied.

## Verification

- PR #2098: required PR CI/Electron/security/governance gates passed before merge.
- PR #2101: CI and Electron desktop quality gate passed on head `802e8472...` before merge.
- Round 3: GitHub Actions pending; no local heavy build is substituted for repository evidence.
- Packaged screenshot-level comparison and exact-main Release evidence are still required for task closure.

## Blockers / risks

- Current Messaging Bot execution state is coarse (`queued/running/waitingForApproval/completed/failed/cancelled`), so `running` still maps to `working`; the outer microcycle improves continuous-work expression without inventing fake backend phases. Fine-grained true Agent phase events remain a later protocol/runtime improvement.
- Grok proprietary/vendored reference code must not become a production dependency.
- DevSpace local editing connection returned 502 during this round, so large-engine internal edits are intentionally deferred rather than replacing a 37KB production file through an unsafe whole-file API operation.

## Next action

Merge round 3 after CI, then use canonical packaged Electron screenshots/E2E to tune any remaining layout/state differences and add true fine-grained Agent presence only from authoritative runtime events.
