# GBF-509 — Grok study avatar motion parity

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-509`
- Stage: `M5`
- Status: `IN_PROGRESS`
- Owner: Fabushi desktop / UI
- Source: `projects/grok-bot-fabushi-integration/source/2026-09-14-grok-icon-study-avatar-parity.md`
- Reference: `bhrum/grok-icon-study@647e9bd7c60290c42a738fad586589b3f36a4680` (`replica/` behavior study only)
- Direct parity source: `projects/grok-bot-fabushi-integration/source/2026-09-18-grok-icon-reference-motion-parity.md`
- Frozen parity contract: `desktop/e2e/fixtures/avatar-motion-parity.v1.json`
- Acceptance branch: `codex/gbf-509-reference-motion-parity-20260918`
- Implementation branch: `codex/gbf-509-grok-avatar-motion-parity`
- Implementation PR: `#2621`
- Implementation head: `72d987e5e32546ab31a7c6650219ed58dcf1a1bf`
- Merge commit: `8ecfaa9fc777c8286d7e15d80c4cd8bd45202764`
- Verified Release: `desktop-1.2.65-4f484be2fd72`

## Objective

Upgrade the existing Fabushi-owned avatar runtime from simple sinusoidal bob/blink motion to a richer stateful spring character system that matches the observable liveliness of the Grok icon study while preserving Fabushi ownership, identity continuity, accessibility, performance controls, and the existing single production runtime chain.

## Direct reference parity re-open — 2026-09-18

The prior packaged/release closeout did not contain synchronized direct reference-vs-Fabushi numerical motion evidence. The original objective therefore remains open. The v1 thresholds were frozen in `a154fe90542fb92a30de6726412c5b09bc7743e8`; the initial timeline was frozen in `e2ec6ca0e325296ed8fa4afb28b98a0e000fd320`. Before the first capture existed, coverage review found hop was not independent from bounce, so `1c70ca34b3e72f8d5a362003d9067c684676d83e` added a deterministic `curious-hop` timeline. No v1 threshold changed, and no capture/tuning preceded that correction.

Additional required acceptance:

- [ ] fixed reference commit and deterministic timelines cover idle, curious, pointer gaze, blink, nod/hop/wink, spin, bounce, burst and major state transitions;
- [ ] reference and packaged macOS Electron run at 640x480, 64px and reduced-motion=false on the same timelines;
- [ ] body Y/roll/squash, L/R eye openness, gaze X/Y, blink cadence, transition settling and spin/bounce/burst peak/period/damping metrics pass frozen v1 thresholds;
- [ ] paired frame sequences, side-by-side/overlay evidence, both videos, traces/logs and artifact digest are retained;
- [ ] any remediation changes only the existing `FabushiAvatarRuntime` parameter/timing surface and keeps reference geometry/assets out of production;
- [ ] exact-head PR capture passes, protected merge completes, then the same capture passes on exact canonical main and runtime lineage is re-read;
- [ ] evidence/acceptance/status records are updated only after exact-main proof.

## Acceptance criteria

- [x] `FabushiAvatarRuntime` uses frame-rate-independent spring channels for pose, gaze, blink/eye scale, squash and action impulses.
- [x] All existing `BotMarkState` values retain support and feed distinct pose/eye/gaze behavior.
- [x] Ambient deterministic micro-actions (gaze changes, nod/hop, occasional wink-like asymmetric eye response) are identity-seeded and do not require React state updates per frame.
- [x] Existing `spin`, `bounce`, `burst`, explicit gaze and pointer-follow API remain compatible.
- [x] Agent/product states expose Fabushi-owned visual overlays/reactions without importing reference geometry/assets.
- [x] Pause/hidden/reduced-motion paths remain deterministic and low-cost.
- [x] `.github/scripts/assert-bot-mark-motion.py` fails closed if the spring/micro-motion runtime regresses or prohibited upstream runtime/assets return.
- [x] Pull request CI passed on exact implementation head.
- [x] Protected-main merge, canonical-main readback, packaged Electron user-journey evidence and a Release containing the unchanged implementation are proven.

## Verification

1. Repository motion/provenance guard is present on canonical `main` and explicitly requires `spring-character-v2`, state eye choreography, seeded micro-motion and overlays while rejecting reconstructed/upstream runtime markers.
2. PR `#2621` merged on 2026-09-14 with exact head `72d987e5e32546ab31a7c6650219ed58dcf1a1bf`; merge commit is `8ecfaa9fc777c8286d7e15d80c4cd8bd45202764`.
3. Exact implementation head exposed 39 GitHub check runs; Electron desktop, computer-control security and protected-merge authorization results completed successfully, with no failed exact-head check found in the recorded check-run set used for this closeout.
4. Canonical `main` still contains `frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx` with `data-motion-model="spring-character-v2"`, independent spring dynamics, state-specific eyes, deterministic micro-actions, pointer gaze, overlays, and imperative reactions.
5. Release source `4f484be2fd72f13289473f9c4917e03b78a92022` is 19 commits ahead of the GBF-509 merge commit and does not modify the avatar runtime file in that interval, so the released binary contains the accepted implementation unchanged.
6. Electron desktop quality gate run `34922024240` on release source `4f484be2fd72f13289473f9c4917e03b78a92022` completed successfully. The Windows lane packaged the app, ran the complete packaged Electron user journey successfully, and uploaded diagnostics; macOS and Linux E2E diagnostics were also retained.
7. Packaged evidence includes `fabushi-electron-mac-e2e-diagnostics` (`sha256:c6a1baa21f53c3356f5a7c0cc80e3a40b873ff8b6606f08b924a212c105c4907`), `fabushi-electron-win-e2e-diagnostics` (`sha256:d6974d13f4e287e767a2d227d7dd8fcbf370d66ee758fb8a85bad161c47532b3`), and `fabushi-electron-linux-e2e-diagnostics` (`sha256:3c4b6adba7bb0e13a2be3057736dc174603c58b7cd0429162219f96cd1fc68aa`).
8. Stable Release `desktop-1.2.65-4f484be2fd72` targets the verified descendant source and carries desktop package assets.

## Provenance constraint

No `geometry-data.js`, extracted Grok package code, proprietary eye polygons/body shapes, Grok branding, or reconstructed renderer is copied into Fabushi. The implementation is behavior-level clean-room adaptation under existing ADR-0005 and D8 rules. The reference repository itself labels extracted shapes/assets as belonging to xAI / their rights holders and not for commercial redistribution, so pixel-identical proprietary geometry is intentionally outside this task's accepted scope.

## Closeout note — 2026-09-15

This record was previously stale and still said implementation/CI were pending after PR `#2621` had already merged. Live GitHub facts were re-read from canonical `main`, the exact implementation head, the later release lineage, Electron packaged E2E run, retained artifacts and Release before changing the task to `RELEASED`.

A separate failure on release-source check runs named `Protected account production MCP preflight` is unrelated to GBF-509 avatar behavior and did not block the successful Electron packaged quality gate or the published desktop Release; it is not treated as avatar acceptance evidence in either direction.
