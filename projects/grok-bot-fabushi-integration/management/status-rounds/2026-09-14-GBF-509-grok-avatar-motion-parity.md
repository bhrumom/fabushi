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

## 2026-09-15 closeout readback

The implementation round was previously left with a stale `IN_PROGRESS` note after delivery had already completed. Live GitHub state was re-read and the durable project record is now reconciled:

- PR `#2621` exact head `72d987e5e32546ab31a7c6650219ed58dcf1a1bf` merged on 2026-09-14 as `8ecfaa9fc777c8286d7e15d80c4cd8bd45202764`.
- The exact implementation head has successful Electron desktop, security and protected-merge authorization results; no failed check was found in the exact-head check-run set used for this closeout.
- Canonical `main` retains the single Fabushi-owned `spring-character-v2` runtime and its provenance guard.
- Stable Release source `4f484be2fd72f13289473f9c4917e03b78a92022` descends from the GBF-509 merge by 19 commits without modifying `frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx` in between.
- Electron quality gate run `34922024240` succeeded on that Release source and retained macOS, Windows and Linux packaged E2E diagnostics; the Windows/macOS packaged user journey completed successfully.
- Stable immutable Release `desktop-1.2.65-4f484be2fd72` published the verified descendant source.
- A separate `Protected account production MCP preflight` failed on that later source. It is unrelated to the avatar runtime and is recorded rather than hidden; it is not used as GBF-509 acceptance evidence.

## Final acceptance

GBF-509 is `RELEASED`. The shipped result is observable-behavior parity implemented in Fabushi-owned code: spring motion, state-specific eyes, seeded micro-actions, pointer gaze, overlays, spin/bounce/burst reactions, reduced-motion handling and canonical identity continuity. Pixel-identical reuse of proprietary xAI/Grok geometry, eye polygons or extracted renderer assets remains intentionally excluded by the provenance boundary.
