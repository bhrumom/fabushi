# GBF-509 — Grok study avatar motion parity

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-509`
- Stage: `M5`
- Status: `IN_PROGRESS`
- Owner: Fabushi desktop / UI
- Source: `projects/grok-bot-fabushi-integration/source/2026-09-14-grok-icon-study-avatar-parity.md`
- Reference: `bhrum/grok-icon-study@main` (`replica/` behavior study only)
- Branch: `codex/gbf-509-grok-avatar-motion-parity`

## Objective

Upgrade the existing Fabushi-owned avatar runtime from simple sinusoidal bob/blink motion to a richer stateful spring character system that matches the observable liveliness of the Grok icon study while preserving Fabushi ownership, identity continuity, accessibility, performance controls, and the existing single production runtime chain.

## Acceptance criteria

- [ ] `FabushiAvatarRuntime` uses frame-rate-independent spring channels for pose, gaze, blink/eye scale, squash and action impulses.
- [ ] All existing `BotMarkState` values retain support and feed distinct pose/eye/gaze behavior.
- [ ] Ambient deterministic micro-actions (gaze changes, nod/hop, occasional wink-like asymmetric eye response) are identity-seeded and do not require React state updates per frame.
- [ ] Existing `spin`, `bounce`, `burst`, explicit gaze and pointer-follow API remain compatible.
- [ ] Agent/product states expose Fabushi-owned visual overlays/reactions without importing reference geometry/assets.
- [ ] Pause/hidden/reduced-motion paths remain deterministic and low-cost.
- [ ] `.github/scripts/assert-bot-mark-motion.py` fails closed if the spring/micro-motion runtime regresses or prohibited upstream runtime/assets return.
- [ ] Pull request CI passes on exact head.
- [ ] Protected-main merge, canonical-main readback, packaged Electron visual E2E/evidence and Release are present before task closure.

## Verification

1. Repository motion/provenance guard.
2. Frontend TypeScript/build gates in GitHub Actions.
3. Electron packaged Messenger/avatar visual journey with screenshots/video/trace on canonical main.
4. Post-main Release delivery bound to the accepted canonical main SHA.

## Provenance constraint

No `geometry-data.js`, extracted Grok package code, proprietary eye polygons/body shapes, Grok branding, or reconstructed renderer is copied into Fabushi. The implementation is behavior-level clean-room adaptation under existing ADR-0005 and D8 rules.

## Current round

- Open-source reference and current Fabushi runtime inspected.
- Primary gap identified: current runtime has a single sinusoidal body motion and symmetric ellipse eyes; it lacks independent springs, state-specific eye choreography and seeded micro-actions.
- Implementation and CI evidence pending.
