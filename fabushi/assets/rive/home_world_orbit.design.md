# HomeWorldOrbit Rive Asset

Runtime file path: `assets/rive/home_world_orbit.riv`

This file documents the generated Rive runtime asset used by the 2D home world.
The runtime file was generated with RiveMCP and can be replaced by a hand-authored
Rive editor export as long as the artboard, state machine, and input names below
stay stable.

## Artboard

- Name: `HomeWorldOrbit`
- Size: `1080 x 1920`
- Background: transparent
- Fit in Flutter: `cover`
- Purpose: atmospheric and interaction animation only. The real earth texture,
  projected geography, lotus coordinate points, labels, and transfer beams are
  rendered by Flutter so the 2D earth keeps accurate land/ocean shape.

## State Machine

- Name: `HomeWorldOrbit`
- Inputs:
  - `isSending`: Boolean. `true` while a transfer beam is active.
  - `pulse`: Number, range `0..1`. Continuous soft breathing value from Flutter.
  - `rotationSpeed`: Number. Receives the current Flutter earth rotation speed.

## Layers

- `AtmosphereGlow`
  - Two centered circles, warm white and gold, using blur.
  - Idle opacity maps to `pulse` from `0.24` to `0.48`.
  - Sending opacity maps to `pulse` from `0.42` to `0.72`.

- `OrbitSweep`
  - Three elliptical strokes around the earth area.
  - Idle timeline: clockwise trim-path sweep, `8s` loop.
  - Sending timeline: faster trim-path sweep, `2.4s` loop.
  - Stroke colors: `#FFF2A8`, `#62E7FF`, `#FFFFFF`.

- `StarField`
  - 18 tiny dots distributed over the top 58% of the artboard.
  - Each dot has an opacity/scale loop with staggered offsets.
  - Keep dots subtle so they do not compete with labels.

- `LotusPulse`
  - Seven small lotus marks aligned approximately with the Flutter visible
    locations. Their exact coordinates do not need to match geography because
    Flutter draws the accurate coordinate markers.
  - Idle loop: scale `0.92..1.08`, opacity `0.55..0.9`.
  - Sending loop: add outer golden rings expanding and fading.

- `SendingEnergyRing`
  - Hidden in idle state.
  - In sending state, draw two expanding rings from the earth center every
    `1.2s`, opacity fading from `0.75` to `0`.

## Animation States

- `Idle`
  - Default.
  - Atmosphere breathing, star twinkle, slow orbit sweep.

- `Sending`
  - Active when `isSending == true`.
  - Brighter atmosphere, faster sweep, expanding energy rings.

- Transitions:
  - `Idle -> Sending`: `isSending == true`, mix `160ms`.
  - `Sending -> Idle`: `isSending == false`, mix `320ms`.

## Export Notes

- Runtime export path: `assets/rive/home_world_orbit.riv`.
- Animation, state machine, and input names are available at runtime by default.
- Keep the file transparent and avoid embedding the earth texture; Flutter owns
  earth rendering for geographic accuracy and performance.
