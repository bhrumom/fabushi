# GBF-506 — Router, usage and sandbox settings parity

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-506`
- Status: `RELEASED`
- Started: `2026-08-24 17:57 +08:00`
- Updated: `2026-08-24 21:56 +08:00`
- Completed: `2026-08-24 21:56 +08:00`
- Branch: `codex/gbf-provider-router`
- Commit / PR: unified head `4d8d3a6a...` / [#2106](https://github.com/bhrumom/fabushi/pull/2106) / main `f81588d3...`

## Objective and scope

Reproduce the observable 0.18 Router settings experience inside the single Fabushi renderer: centered dark modal, exact General/Router/Usage & Billing/Updates navigation, Provider readiness, credentials, usage and Host/Docker selection. Existing functional Fabushi preferences are consolidated into General.

## Acceptance and verification

- Modal geometry/material/navigation and close/escape behavior match the pinned screenshot at supported desktop sizes.
- Provider and sandbox choices persist and restart the Host generation without losing transcript state.
- Secret fields never echo stored values; readiness/error states are explicit.
- Packaged Playwright verifies all categories and retains a Router screenshot, full video, trace and report for the exact main SHA.

## Open-source survey and decision

The pinned screenshot and observable labels/layout were used as a clean-room visual specification. No renderer bundle, CSS or icons were copied because upstream source rights are not granted. Fabushi-owned React/CSS and existing BotMark/settings controls implement the behavior.

## Implementation and evidence

Added the centered `#191919/#2b2b2b/#292929` modal, exact four-item left navigation, Router forms/status/usage/sandbox panels, Usage & Billing, real update track/check/install controls, and General controls for theme, timezone, local execution ceiling, auto-review, security key and Messenger preferences. Added responsive collapse, focus trap, return-to-previous-surface/backdrop/close/Escape behavior, explicit errors and packaged screenshot attachment. A baseline BotMark spring instability discovered by E2E was fixed with bounded integration and true reduced-motion semantics. Canonical seven-gate `32731980249`, main Electron `32733627050`, native mobile `32733627056` and delivery `32734915241` passed; `desktop-1.0.867` contains the exact-main Windows/macOS/Linux packages and updater assets.

## Next action

None for GBF-506. Broader final visual parity remains tracked by GBF-805.
