# GBF-509 direct motion-parity round — 2026-09-18

- Task: `GBF-509`
- Status: `IN_PROGRESS`
- User task: `Fabushi:d41a2721-9885-4b89-a7e6-9d379a20bf23`
- Starting canonical main: `e26dda430230f36ead799f81115aa7dc9fa9bf7b`
- Acceptance branch: `codex/gbf-509-reference-motion-parity-20260918`
- Fixed reference: `bhrum/grok-icon-study@647e9bd7c60290c42a738fad586589b3f36a4680`
- Frozen thresholds source commit: `a154fe90542fb92a30de6726412c5b09bc7743e8`
- Initial frozen timeline/config commit: `e2ec6ca0e325296ed8fa4afb28b98a0e000fd320`
- Pre-capture coverage correction: `1c70ca34b3e72f8d5a362003d9067c684676d83e` (adds independent deterministic hop; thresholds unchanged; no capture had run)

## Finding

The prior GBF-509 release evidence proved architecture, source provenance, merge lineage and packaged Electron execution, but did not contain the user's required direct reference-vs-Fabushi synchronized visual/motion measurements. The historical closeout remains part of the audit trail, but GBF-509 is reopened for this missing acceptance dimension.

## Round scope

Only the missing visual/motion parity is in scope. The single production path remains `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime`. No second avatar runtime is permitted.

## Current gate

The v1 thresholds and deterministic timeline are frozen before capture. Next: add packaged macOS capture/measurement instrumentation and an explicitly user-authorized GitHub Actions parity workflow, then run it on the PR exact head. If any v1 threshold fails, tune only the existing runtime's spring/timing/gaze/blink/squash/micro-action parameters and rerun without relaxing v1.
