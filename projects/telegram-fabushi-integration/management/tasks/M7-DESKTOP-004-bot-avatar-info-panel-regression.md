# M7-DESKTOP-004 — Bot avatar + info panel regression closure

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M7-DESKTOP-004`
- **Stage**: `M7 Bot/Agent 统一联系人体系`
- **Status**: `IMPLEMENTED`
- **Started**: `2026-08-25`
- **Branch**: `fix/tfi-bot-avatar-info-panel`
- **Source**: `../../source/2026-08-25-bot-avatar-info-panel-regression.md`

## Root causes

1. `MahayanaAgentWorkbench` hides the currently active peer's original BotMark when moving its animated avatar into a React portal. Hidden marks were only restored when the workbench unmounted, so every peer that had once been active could remain `display:none` after switching away.
2. Workbench portal BotMarks used new `header:*` / `peer-active:*` / `info:*` IDs, changing the deterministic Motion v2 identity seed instead of preserving the Messenger BotMark identity.
3. `MessengerWorkspace` included `wideInfoLayout` in `infoPanelVisible`, so at CSS widths `<=1280` the info panel was never rendered even when the user toggled it.

## Implementation

- Restore stale hidden BotMarks every portal refresh; only the three currently replaced originals may remain hidden.
- Copy each original BotMark's `data-bot-id` / label into the portal target and reuse it for the animated replacement.
- Scope workbench animation state to the selected conversation rather than leaking an active run from another Bot.
- Render info panel whenever the user opens it; dock it only on wide layouts and render it as an absolute right drawer on narrower layouts.
- Add stable test IDs for the info toggle and panel.
- Add Playwright regression covering two peer switches, one visible Motion v2 avatar per peer/header, preserved identity, and narrow-width right-panel open/close.

## Acceptance

- `git diff --check` passes locally.
- GitHub Actions desktop typecheck/build and Messenger regression Playwright pass on current PR head.
- PR merges to protected `main` and canonical main is re-read.
- Exact-main packaged desktop E2E retains screenshot/video/trace evidence.
- This fix and M8 marketplace implementation are both included before publishing the next desktop Release.

## Completion gate

Keep below `RELEASED` until required current-head CI, protected merge, canonical-main readback, exact-main packaged E2E and the new GitHub Release all exist.

## Exact-main delivery retry — 2026-08-25

- Product main `3dd5e2e8122f0ac142a33002c969930ab4c05bf8` reached Electron run `32812505326`.
- Linux real-Host E2E retained diagnostics artifact `9550324929` and correctly blocked publication.
- New regression failed because the active peer contained two visible Motion v2 marks after Messenger re-render: the React-owned original mark had its external inline `display:none` overwritten while the Workbench portal mark remained.
- Follow-up branch `fix/tfi-avatar-portal-e2e` replaces fragile inline-only hiding with a parent portal marker and CSS-enforced direct-child suppression, while clearing the marker whenever the portal moves.
- Status remains `IMPLEMENTED`; Release is blocked until the follow-up merges and a new exact-main delivery is green.

## Exact-main selector correction — 2026-08-25

- Follow-up product main `c0b5534d0c0e1b6fb916819c499adbdd5b855b46` reached Electron run `32812950533`; the real-Host journey retained diagnostics artifact `9550478342` and again blocked publication.
- The retained screenshot shows one rendered BotMark. Source inspection proves the semantic BotMark wrapper and its inner SVG both intentionally carry `data-engine="fabushi-motion-v2"`, so the original regression locator counted two DOM nodes for one visible avatar identity.
- Acceptance is corrected, not weakened: only the semantic outer BotMark carrying `data-bot-id` is counted via `[data-engine="fabushi-motion-v2"][data-bot-id]:visible`.
- Peer switching, stable `data-bot-id` identity, and the 1100px right info drawer remain mandatory assertions.
- Branch `fix/tfi-avatar-regression-selector-v2` is based on the current canonical main `54eeb8ad3caf64c02ef834142cb63d38b12033a9`; Release remains blocked until this correction passes protected merge and a later exact-main product delivery is fully green.

## Exact-main selected-peer identity follow-up — 2026-08-25

- Canonical `main@6ae21cba7878d113ac2902df94d867e7d3b7cd34` entered Electron delivery run `32813752100`.
- The real Linux Rust Host journey failed only the task-specific avatar regression after 17/18 E2E cases passed; diagnostics artifact `9550721736` was retained. Windows and signed/notarized macOS packages were also blocked by packaged-user E2E rather than published.
- The failure is a real identity mismatch: after selecting `Incident Bot`, the selected peer row exposed `peer:bot:incident-bot` while the Header portal still rendered `peer:conversation:codex:agent:assistant`.
- Root cause: `activePeerContext()` queried the Header identity subtree, where the Workbench-owned portal can still be the first matching `peer:*` BotMark after a switch. In parallel, `ensurePortalRoot()` mutated `dataset.sourceBotId` on a stable portal DOM node, but mutable DOM metadata is not React state and therefore did not itself trigger a render.
- Follow-up branch `fix/tfi-selected-peer-avatar-identity` makes the selected peer row's direct semantic BotMark the canonical identity source, stores active `botId`/label in React portal target state, and keeps Mahayana run state separate from Messenger peer identity. Header, selected row and info-panel portal marks now render from the same selected-peer identity.
- Acceptance is strengthened to assert identity equality on the first peer, second peer, the 1100px info drawer, and a switch back to the first peer.

### Open-source-first decision

- Reviewed the official `facebook/react` portal/reconciliation design (MIT). The relevant architectural lesson is ownership, not code reuse: portal rendering must be driven by React props/state; external DOM `dataset` mutation is not a reliable reactive source.
- Fabushi keeps its custom Motion v2 / Messenger integration because upstream React does not provide product identity semantics. No upstream code is copied.
- Status remains `IMPLEMENTED`; Release is blocked until this follow-up passes protected merge and the resulting latest-main exact delivery is green.

## Exact-main peer-selection observer follow-up — 2026-08-25

- `main@eb4b340ce4d9d18cc69b4e60ec97037cbcb2c878` Electron delivery run `32822744019` again retained the failure instead of publishing. Linux real-Host diagnostics artifact: `9553768019`; 17/18 cases passed.
- The selected-row identity fix was correct but propagation was not event-driven: `activePeerButton()` derives selection from the CSS-module `peerActive` class, while the Workbench MutationObserver watched only `childList`. Messenger reuses peer row DOM nodes and changes `class`, so the Workbench could remain stale until the 500 ms recovery interval.
- Follow-up branch `fix/tfi-peer-selection-observer` observes peer-button `class` mutations (filtered to `button[data-testid^="peer-"]`) and refreshes portal identity immediately after the React commit; the 500 ms interval remains recovery-only.
- E2E now waits for the selected peer's `peerActive` class and then polls Header semantic identity equality, so the assertion models the asynchronous React portal commit without accepting a permanently stale identity.
- Status remains `IMPLEMENTED / RELEASE_BLOCKED` pending protected merge and a green exact-main delivery.

## Exact-main narrow info drawer follow-up — 2026-08-25

- Canonical `main@adcd73d0b68ddff403d5804d1b8d10f9b5e6c202` reached Electron run `32823782495`; the real Linux Rust Host journey advanced past the selected-peer/Header identity assertions and failed only when opening the 1100px info drawer. Diagnostics artifact: `9554164364`; 17/18 E2E cases passed.
- Retained screenshot and accessibility context show the selected `Incident Bot` identity is correct and the `资料` toggle is reachable, but `messenger-info-panel` is absent after the click.
- Root cause is a stale responsive CSS rule: the new JS layout already renders `data-overlay="true"` for widths `<=1280`, but legacy `@media (max-width: 1280px) { .infoPanel { display:none; } }` still hides every info panel. When `infoOpen` is already true, the drawer exists in state but is visually suppressed; clicking the toggle can then close the state rather than reveal anything.
- Follow-up branch `fix/tfi-narrow-info-panel-toggle` scopes the legacy hide rule to non-overlay panels and explicitly keeps `[data-overlay="true"]` at `display:flex`. Existing Playwright acceptance remains unchanged and must now prove the real 1100px drawer opens and follows the selected Bot identity.
- No external dependency is needed: the product already has the correct overlay state/layout model; this is removal of a stale internal CSS override.
- Status remains `IMPLEMENTED / RELEASE_BLOCKED` until protected merge and a later exact-main desktop/mobile delivery are fully green.
