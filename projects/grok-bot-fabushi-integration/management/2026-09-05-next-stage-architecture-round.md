# 2026-09-05 architecture round — GBF

- Revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Baseline: `main@586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Round status: `PLANNED`

## WBS delta

| Task | Goal | Depends on | Wave | Status |
|---|---|---|---|---|
| GBF-412 | add Mahayana Bot-session fence to exact-target device calls | merged GBF-409/410/411, MSR-204 | 2 | PLANNED |
| GBF-413 | project canonical multi-Bot group execution into Grok-like multi-result UX | GBF-412, TFI M5-BOTGROUP-001, MSR-206 | 3 | PLANNED |

## Acceptance delta

- GBF-NX-A01: every Bot device mutation names one device and validates account + device/control session/generation + Bot Mahayana session/generation + grant + nonce/expiry; stale/replay/wildcard target fails closed.
- GBF-NX-A02: group UX shows participant/step/result identity and exact tool target without creating a second runtime/state store.

## Dependency/blocker delta

- GBF-412 waits for MSR-204 canonical BotRuntimeBinding/ToolExecutionContext.
- GBF-413 waits for canonical TFI group events and MSR orchestration events.

## Record correction notes

- GBF-409 task prose says #2201 is pending; GitHub shows #2201 merged.
- GBF-411 task prose references #2205 as pending; #2205 is merged. Keep any unproven post-main/live/release gates open rather than reverting implementation status.

## Changelog

Added two additive tasks and architecture delta. No device/runtime/product code changed.
