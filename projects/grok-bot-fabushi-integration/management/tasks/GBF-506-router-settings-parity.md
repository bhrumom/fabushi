# GBF-506 — Router, usage and sandbox settings parity

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-506`
- Status: `IMPLEMENTED`
- Started: `2026-08-24 17:57 +08:00`
- Updated: `2026-08-24 20:07 +08:00`
- Completed: —
- Branch: `codex/gbf-provider-router`
- Commit / PR: unified PR head / [#2106](https://github.com/bhrumom/fabushi/pull/2106)

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

Added the centered `#191919/#2b2b2b/#292929` modal, exact four-item left navigation, Router forms/status/usage/sandbox panels, Usage & Billing, real update track/check/install controls, and General controls for theme, timezone, local execution ceiling, auto-review, security key and Messenger preferences. Added responsive collapse, focus trap, return-to-previous-surface/backdrop/close/Escape behavior, explicit errors and packaged screenshot attachment. Code-head Host journey `32725104003`, frontend CI `32725104017` and Electron contract `32725103923` passed. A baseline BotMark spring instability discovered by E2E was fixed with bounded integration and true reduced-motion semantics. Exact-main packaged visual acceptance remains pending.

## Next action

Complete the final unified-head checks, merge, and verify exact-main Windows/macOS/Linux package/E2E/Release evidence before completion.
