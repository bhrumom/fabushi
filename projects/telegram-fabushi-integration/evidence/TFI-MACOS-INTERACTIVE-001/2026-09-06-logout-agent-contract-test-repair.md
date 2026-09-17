# TFI-MACOS-INTERACTIVE-001 — logout semantic contract test repair

- Baseline: protected `main@8ab72817432dd7166404dda4a16dddee7bcbbb8e` after PR #2392.
- #2392 merge-group gates: CI `34013091922` success; merge-queue fallback `34013092341` success.
- Late PR-head failure: Electron desktop quality gate `34013056021`, Linux job `101432061956`, first `app-agent-surface.spec.ts` test exceeded the 45 second timeout after #2392 expanded that low-level test with a full settings navigation journey.
- Product repair remains valid: `settings-logout` keeps `data-agent-id="settings-logout"`.

## Atomic correction

Restore `app-agent-surface.spec.ts` to its bounded generation/rebase contract and move the new logout-id regression assertion into the pre-existing account-settings E2E, which already navigates to account settings, verifies the logout control, performs logout, verifies cache/session teardown, and logs back in. This preserves production behavior and the interactive truth gate while removing duplicate long navigation from a low-level bridge test.

All build/test verification remains GitHub Actions only. No local build, package, Electron, native, or E2E execution is permitted. After protected merge and exact-main green verification, the next macOS test release must be strictly newer than the excluded 1.2.34 candidate and the full App-owned interactive journey must be rerun.
