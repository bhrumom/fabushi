# 2026-09-14 — Grok icon study avatar motion parity

## User requirement

Integrate the avatar animation behavior demonstrated by `https://github.com/bhrum/grok-icon-study/tree/main` into Fabushi so the existing Bot avatar feels and reacts like the study reference instead of using a simple static/oscillating mark.

## Reference inspected

- Repository: `bhrum/grok-icon-study`
- Default branch: `main`
- Study surface: `replica/`
- Public README describes the reference as a study/reconstruction of the Grok Bot 0.18.0 login character animation and explicitly says the extracted shapes/assets belong to xAI / their rights holders and are not for commercial redistribution.
- Behavior-level observations used for clean-room implementation: independent springs for pose/gaze/blink/squash, state-specific eye behavior, deterministic/random micro-motions, pointer gaze, imperative spin/bounce/burst, lifecycle/product state overlays, and reduced-motion handling.

## Provenance / license decision

Do **not** copy `geometry-data.js`, extracted package code, Grok brand assets, eye polygons, proprietary body geometry, or the study repository's reconstructed renderer into the Fabushi product.

Fabushi will keep ADR-0005 and D8 policy intact: only independently implemented observable behavior and animation architecture may be adapted. Production remains `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime`, with Fabushi-owned SVG geometry and motion code.

## Acceptance

1. Replace the current sinusoidal-only avatar motion with a Fabushi-owned spring character runtime.
2. Preserve every existing `BotMarkState` and drive visually distinct gaze/eyes/pose behavior from state.
3. Add deterministic micro-motion (look/nod/hop/wink-like behavior), state overlays, and richer spin/bounce/burst reactions without React rerender-per-frame.
4. Preserve canonical Bot identity, pointer gaze, visibility pause, `prefers-reduced-motion`, and the existing imperative `BotMarkHandle` API.
5. Add repository guard coverage proving the richer runtime is present and proving no upstream renderer/assets are imported.
6. Validate through GitHub CI / Electron packaged visual journey; local developer builds are not acceptance evidence.
