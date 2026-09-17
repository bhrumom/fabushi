# TFI-M3-SETTINGS-LOGOUT-001 Evidence

## Baseline

- Project: `FAB-P0001 / TFI`
- User request: 2026-09-07 Settings → General screenshot; place “退出登录” in the visible account area and release a new version.
- Canonical main at start: `c12711073221f2137c99351648c10cc2aa9ee8fb`.
- Starting version: `1.2.55`.
- Branch: `fix/tfi-settings-logout-top-20260907`.

## Open-source-first decision

Telegram Desktop surfaces Log Out as a stable Settings action in `Telegram/SourceFiles/settings/sections/settings_main.cpp`. Fabushi reuses only that product-pattern insight. No upstream code/assets are copied; the existing Fabushi logout handler and selectors remain authoritative.

## Implementation evidence

- `desktop/src/messaging-shell-v2.tsx`: move the existing `settings-logout` row directly below the account profile card and before Theme.
- `desktop/e2e/messenger.spec.ts`: assert the visible logout control is vertically above Theme; preserve existing end-to-end logout/cache-clearing test.
- Version policy: `1.2.55 → 1.2.56` in the existing synchronized desktop/mobile/release-control files.

## Delivery evidence

- Local lightweight validation: `PASS` — `git diff --check`, canonical architecture guard, and desktop architecture guard.
- PR/current-head CI: `PENDING`.
- Merge SHA / canonical-main readback: `PENDING`.
- exact-main workflow runs: `PENDING`.
- Release/tag/assets: `PENDING`.
