# GBF-501 — Grok UI / interaction parity

- **Project ID**: `FAB-P0004`
- **Project Key**: `GBF`
- **Task ID**: `GBF-501`
- **Stage**: `M5 UI 与动画引擎`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-24`
- **Updated**: `2026-08-24`
- **Active branch**: `fix/gbf-grok-visual-evidence`
- **Merged rounds**: PR #2098, PR #2101, PR #2102
- **Active repair PR**: #2104

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
- Packaged visual evidence uses Playwright's built-in deterministic animation suppression rather than custom screenshot polling/timeouts.

## Acceptance criteria

1. Authenticated desktop shell defaults to a coherent dark Grok/Fabushi material instead of Telegram white/bright-blue primary styling.
2. Sidebar, peer list, workspace, chat header, message bubbles, composer, info panel, popovers/dialogs, search/settings and marketplace surfaces share the same color/material/spacing system.
3. Existing BotMark motion remains the only animated identity primitive and is visually integrated into the new surface.
4. Existing functional selectors and product behavior remain intact; styling changes do not create a parallel Messenger implementation.
5. Agent states `thinking/searching/working/tool-running/speaking/result/error/alerting` have visibly distinct motion choreography without replacing the authoritative `fabushi-motion-v2` SVG engine.
6. Electron typecheck/build, Messenger/packaged Playwright and relevant governance checks pass on GitHub Actions before task closure.
7. Stable packaged screenshots are produced with animations frozen for layout/material comparison; motion correctness is verified separately by the motion contract.
8. Task remains `IN_PROGRESS` until protected merge, canonical-main readback, packaged E2E, screenshot-level comparison and Release evidence are complete.

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

## Implementation round 3 — merged PR #2102

- Added `desktop/public/grok-motion-parity.css` as an outer choreography layer around the existing `fabushi-motion-v2` engine.
- `thinking`: slow focus/breath + staggered thought particles.
- `searching`: radar/sweep cadence.
- `working/tool-running/writing/sending/receiving/uploading/dragging`: four-beat focus → act → settle → re-check microcycle so a long-running task is not a generic repeated pulse.
- `speaking`: tighter voice cadence.
- `result`: calm confirmation bloom.
- `error/alerting`: deliberate two-beat signal instead of constant frantic motion.
- Reduced-motion disables all added choreography.
- Added packaged Electron CSSOM/computed-style motion contract and packaged visual-evidence test.
- PR #2102 merged to canonical `main` as `78d6b77f67db3a96957aa91b52717e2106bed7f5`.

## RC regression found after round 3

The additional seven-gate RC workflow exposed a real post-merge blocker rather than allowing a false closure:

- Seven-gate parent run: `32703807018`.
- Electron workflow_dispatch child: `32703844541`.
- Linux: the new visual-evidence screenshot timed out twice because `page.screenshot({ animations: 'allow' })` waited on continuously animated BotMark aura/particles; a separate channel-mutation journey also timed out and must be judged again after the deterministic blocker is removed.
- Windows: the same visual-evidence screenshot timeout was the true failure; Mini App startup was flaky but passed on retry.
- Linux diagnostics artifact `9511634437` captured arbitrary extreme motion frames, proving that increasing screenshot timeout would create poor visual evidence instead of fixing the test.

## Repair round — PR #2104 active

- Switch packaged visual screenshots to Playwright `animations: 'disabled'` so layout/material evidence is deterministic and cannot stall on infinite CSS animations.
- Remove the test-only DOM mutation that forced the profile mark to `thinking`; state choreography is already verified by `grok-motion-parity.spec.ts` and should not be fabricated inside the screenshot baseline.
- Keep shell/global-search/conversation screenshots as the stable visual comparison set.
- Rerun full Electron/seven-gate validation; only after the introduced deterministic failure is removed will any remaining independent channel/Mini App failure be treated as a separate product/test defect.

## Verification

- PR #2098: required PR CI/Electron/security/governance gates passed before merge.
- PR #2101: CI and Electron desktop quality gate passed on head `802e8472...` before merge.
- PR #2102: merged after repository required checks, but the extra RC regression later failed as documented above; therefore GBF-501 remains explicitly open.
- PR #2104: pending current-head CI/Electron/RC evidence.
- Packaged screenshot-level comparison and exact-main Release evidence are still required for task closure.

## Blockers / risks

- Current Messaging Bot execution state is coarse (`queued/running/waitingForApproval/completed/failed/cancelled`), so `running` still maps to `working`; the outer microcycle improves continuous-work expression without inventing fake backend phases. Fine-grained true Agent phase events remain a later protocol/runtime improvement.
- Grok proprietary/vendored reference code must not become a production dependency.
- DevSpace local editing connection returned 502 during this round, so large-engine/internal Messenger edits are intentionally deferred rather than replacing large production files through unsafe whole-file API operations.

## Next action

Drive #2104 through the full rerun. Then inspect stable packaged screenshots, tune structural/product-language differences, and only add finer Agent presence when it comes from authoritative Rust/Mahayana runtime events.
