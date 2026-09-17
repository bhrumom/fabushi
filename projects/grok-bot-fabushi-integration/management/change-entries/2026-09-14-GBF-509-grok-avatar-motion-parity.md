# 2026-09-14 — GBF-509 Grok-study avatar motion parity

## Changed

- `frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx`
  - multi-channel spring character dynamics;
  - state-specific eye choreography;
  - deterministic identity-seeded ambient micro-actions;
  - state overlays and richer imperative reactions;
  - preserved pause/reduced-motion/pointer-gaze contracts.
- `.github/scripts/assert-bot-mark-motion.py`
  - requires spring-character-v2 markers and richer state mechanics;
  - rejects study/reconstructed geometry/runtime references from production avatar code.

## Architecture

No second avatar runtime was introduced. `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime` remains the single production path, and the Mahayana Workbench remains the source of real Agent state.

## Provenance

Behavior-level clean-room adaptation only. No Grok/xAI extracted asset, eye polygon table, body geometry table, brand file or reconstructed renderer is copied into Fabushi.

## Rollback

Revert the GBF-509 product/guard commits as one unit. Do not restore an upstream renderer or study asset as a rollback mechanism.

## Delivery state

Implementation branch only; PR/CI/main/package/Release closure is pending and the task remains `IN_PROGRESS`.
