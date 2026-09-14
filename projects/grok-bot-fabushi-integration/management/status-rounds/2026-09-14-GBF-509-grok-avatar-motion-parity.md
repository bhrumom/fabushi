# 2026-09-14 / GBF-509 implementation round

## Source requirement

User requested direct integration of the avatar animation behavior studied in `bhrum/grok-icon-study` into Fabushi, with the resulting Fabushi avatar matching the reference liveliness.

## Findings

- Existing production chain was already correct architecturally: `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime`.
- Existing runtime already had semantic states, gaze, pointer-follow, imperative reactions, pause and reduced-motion.
- The visual gap was inside `FabushiAvatarRuntime`: one sinusoidal body bob, one shared tilt and symmetric ellipse eyes did not reproduce the independent spring/eye/micro-action composition visible in the reference study.
- Upstream README/provenance does not grant production redistribution rights for extracted geometry/assets, so behavior is learned and reimplemented; study renderer/data are not copied.

## Implemented this round

- Replaced the simple motion core with Fabushi-owned multi-channel spring dynamics.
- Added state-specific eye choreography and asymmetric eye poses.
- Added deterministic identity-seeded micro gaze/nod/hop/wink-like actions.
- Added Fabushi-owned semantic state overlays and spring-driven action impulses.
- Preserved the existing public BotMark API, canonical Bot identity, real Mahayana runtime-state mapping, visibility pause and reduced-motion behavior.
- Hardened `.github/scripts/assert-bot-mark-motion.py` so CI requires the new motion architecture and fails if study/upstream renderer/data references enter production avatar code.

## Current acceptance

Implementation is present on `codex/gbf-509-grok-avatar-motion-parity`. Task remains `IN_PROGRESS`: exact-head PR CI, protected-main merge/readback, canonical-main packaged Electron visual E2E/evidence and Release are still required before closure.
