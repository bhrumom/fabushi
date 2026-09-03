# GBF-505 Evidence — Fabushi-owned visual/runtime closure

## 2026-08-28 implementation round

Canonical base: `main@dea04b588e07a45c5871f1c8027d8376d078ff04`.

Branch: `gbf/505-fabushi-owned-avatar-runtime`.

### Production source changes

- Added `frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx`.
  - Fabushi-owned procedural SVG geometry.
  - Fabushi-owned gradient/shading.
  - Agent-state motion profiles.
  - `requestAnimationFrame` animation loop with pause cleanup.
  - gaze/pointer-follow support.
  - imperative spin/bounce/burst actions.
  - `prefers-reduced-motion` handling.
- Updated `fabushi-bot-mark-engine.tsx` to render only `FabushiAvatarRuntime`.
- Updated `bot-mark.tsx` renderer identity to `fabushi-motion-v3` / `fabushi-owned-svg-runtime`.
- Deleted `openmaus-cursor-avatar.tsx`; no vendored mascot implementation remains in the production avatar path.

### Fail-closed guard

`.github/scripts/assert-bot-mark-motion.py` now requires the Fabushi-owned runtime and rejects production references to:

- `openmaus-cursor-avatar`
- `CursorAvatar`
- `DEFAULT_SILHOUETTE`
- `milind-soni/OpenMausBot`
- `GrokBotMarkEngine`
- `grok-bot-mark-engine`
- `index-UbX-y3il.js`
- `checksum-pinned-artifact-runtime`
- `shipped renderer`

Historical project/evidence files may retain those terms for provenance and comparison; they are not runtime inputs.

### Acceptance evidence still required

- PR CI: frontend typecheck/build and Electron Feature Host contract.
- Protected merge to canonical `main`.
- Canonical-main packaged Electron visual journey for BotMark states.
- Required screenshot/video/trace bundle.
- Verified Release/tag/assets tied to the accepted main SHA.

GBF-505 remains `IN_PROGRESS` until these delivery gates are proven.
