# FCM-004 — Release gate alignment

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-004
- **Status:** completed
- **Started:** 2026-08-22
- **Completed:** 2026-08-22

## Objective

Prevent Apple/Google store delivery from starting expensive build/sign/upload work from an unprotected or platform-unverified source commit.

## Implemented

- `.github/scripts/require-release-source-gates.sh` validates exact source SHA against protected `main` history.
- macOS requires successful `CI result` + `Electron desktop result` for that SHA.
- iOS/Android require successful `CI result` + `Native mobile result`.
- Apple `both` requires all three.
- Apple and Google workflows call the gate before platform build/sign/upload stages.
- Delivery remains explicit `workflow_dispatch`; immutable GitHub Release targeting remains unchanged.

## Acceptance evidence

- PR #1999 head `9878d7a50e96dd38679ace5c53ad4b594f322c53`
- Delivery governance contract `32564046827` — success
- Canonical CI `32564046924` — success
- Project portfolio governance `32564046818` — success
- Merge queue branch observed: `gh-readonly-queue/main/pr-1999-d8b502726dc14f0a7963f67f58e44ebfb9887b01`
- PR #1999 merged as `3a39dfef0ef30f1e6ae2d53602fa862bf28ddae6`
- Post-merge canonical gate script blob: `7701fa190d25f551f873e2e201df6a063d674e89`
- Post-merge Apple workflow blob: `062e2b32ec682fa7a5c9b076d3e8a394f3e4dd91`
- Post-merge Google workflow blob: `d817a961824568269428d49845761bfcc57b4c29`

## Important scope note

This task accepts the release **governance gate**, not a new App Store/Play Store upload. Actual publishing remains a manual release operation requiring signing/store credentials and a deliberately selected release source.

## Blockers

None for the governance implementation.

## Next action

None. Future store-delivery regressions reopen a new FCM task.
