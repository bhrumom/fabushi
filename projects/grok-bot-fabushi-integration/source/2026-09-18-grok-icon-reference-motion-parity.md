# GBF-509 direct reference motion-parity acceptance

- User task: `Fabushi:d41a2721-9885-4b89-a7e6-9d379a20bf23`
- Acceptance round opened: 2026-09-18
- Fabushi starting canonical main: `e26dda430230f36ead799f81115aa7dc9fa9bf7b`
- Fixed reference repository: `bhrum/grok-icon-study`
- Fixed reference commit: `647e9bd7c60290c42a738fad586589b3f36a4680`
- Reference surface: `replica/`
- Production runtime under test: `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime`
- Frozen test contract: `desktop/e2e/fixtures/avatar-motion-parity.v1.json`

## Why this round exists

The 2026-09-15 GBF-509 closeout proved the Fabushi-owned spring runtime was merged, packaged and released, but it did not include a synchronized direct reference-vs-Fabushi motion capture with pre-declared numerical thresholds. The prior `RELEASED` conclusion therefore does not close the user's original “same effect” objective.

## Frozen capture contract

The reference commit above is immutable for this round. The runner may check it out only as a test reference. No reference geometry, eye polygons, branding, extracted package code or reconstructed renderer may be copied into the Fabushi product or package.

Every parity run uses 640x480 CSS px, a 64px avatar, `prefers-reduced-motion: no-preference`, 30 Hz sampling, deterministic reference seed 50918, the exact v1 timelines, and a packaged macOS Electron executable built from the exact tested Fabushi SHA.

The selected timelines cover idle, curious, pointer gaze, blink cadence, deterministic curious nod, deterministic wink, bounce/hop, spin, burst, and idle -> curious -> listening -> idle state transitions.

## Pre-declared v1 thresholds

These thresholds are frozen before the first direct capture. A later commit may tune the existing Fabushi runtime, but v1 values must not be relaxed after seeing results. If a threshold is invalid, v1 fails and a separately justified v2 contract is required.

Body channels:
- body-Y action peak relative error <= 35%;
- body-Y dominant period relative error <= 30%;
- body-Y settling error <= max(300 ms, 35%);
- ambient/state roll MAE <= 5 degrees;
- action roll peak relative error <= 35%;
- squash MAE <= 0.04 scale units;
- squash peak absolute error <= 0.08 scale units.

Eyes and gaze:
- normalized left-eye openness MAE <= 0.18;
- normalized right-eye openness MAE <= 0.18;
- blink event-count delta <= 1 in the fixed cadence window;
- median inter-blink interval relative error <= 25%;
- blink closure-duration error <= 120 ms;
- wink peak L/R openness-asymmetry error <= 0.20;
- gaze-X peak relative error <= 25%;
- gaze-Y peak relative error <= 25%;
- gaze settling-time error <= 180 ms.

Actions and transitions:
- spin total-rotation peak relative error <= 8%;
- spin settling error <= max(180 ms, 25%);
- bounce first-peak timing error <= 180 ms;
- bounce first-peak amplitude relative error <= 35%;
- bounce rebound/period relative error <= 30%;
- bounce settling error <= 300 ms;
- burst normalized motion-envelope peak-time error <= 180 ms;
- burst normalized envelope duration/settling relative error <= 35%;
- state-transition end-state normalized error <= 0.15 for body-Y/roll/squash/gaze/eyes;
- state-transition settling error <= 250 ms.

Visual evidence:
- paired frame sequences are mandatory for every scenario;
- selected key frames must include side-by-side and 50%-opacity overlays;
- both reference and packaged Fabushi sessions must retain video;
- numerical JSON/CSV, trace/logs, exact source/reference SHAs and artifact SHA-256 digest must be retained;
- temporal-difference motion-energy correlation for each action scenario must be >= 0.75 after first-frame subtraction and per-side normalization. Static geometry is deliberately excluded from the score because proprietary geometry is not allowed in production.

## Allowed remediation

If v1 fails, remediation is limited to the existing `FabushiAvatarRuntime`: spring frequency/damping, blink cadence, squash response, gaze response, and existing micro/action timing or impulse constants. No second avatar runtime, reference geometry, brand asset, or copied reconstructed renderer is allowed.

## Completion rule

GBF-509 and the original user objective may return to complete only after the frozen v1 thresholds pass on the PR exact head, protected merge completes, the same capture passes again on the then-current exact canonical `main`, runtime lineage is re-read, and GBF-509 evidence/acceptance/status are updated with run IDs, exact SHAs and artifact digests.

## Pre-capture coverage correction

Before any reference-vs-Fabushi capture was executed, coverage review found that the initial v1 timeline described hop together with bounce but did not carry an independent deterministic micro-hop scenario. Commit `1c70ca34b3e72f8d5a362003d9067c684676d83e` added `curious-hop` using identity `gbf509-curious-3` and reference event time 1902 ms. This happened before the first observed parity result; no threshold value above changed and no runtime tuning preceded the correction. From the first capture onward, both the thresholds and v1 scenario set are immutable for this round.
