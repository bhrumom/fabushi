# TFI-MACOS-INTERACTIVE-001 — restore Native mobile quality gate / 1.2.31

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Base protected main: `ad9ddc38a99656d0ca09fd196d7ccb162e2a74dd`
- Discovery PR: `#2384`
- Native mobile catch-all run: `33999996263` (`failure`, zero instantiated jobs)
- Paused workflow: `.github/workflows/native-mobile.yml`
- Exact pre-pause source commit: `586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Exact pre-pause workflow blob: `371125ec6caeab447d6d8891210b8e24714b1686`

## Independent failure

The restored Electron/security sequence advanced far enough for PR #2384's version metadata to trigger `.github/workflows/native-mobile-catchall.yml`. That catch-all delegates to `./.github/workflows/native-mobile.yml`, but the delegated workflow was still the 2026-09-05 Mac-test pause stub: it exposed only `workflow_dispatch` and a `paused` job, so GitHub could not instantiate it as the reusable workflow expected by the catch-all and the run failed before creating jobs.

This is a separate governance failure from #2384's packaged-release source-contract drift. Commit `d2135a22c75a37b0b8e7da5883f5cadd464bd9fb` introduced the pause; its parent `586a0952…` contains the complete native-mobile gate, including PR/push/manual/reusable triggers, Android PR fast path, post-main Android/iOS work, and aggregate native-mobile result.

## Atomic repair

This PR restores `.github/workflows/native-mobile.yml` byte-for-byte to pre-pause blob `371125ec6caeab447d6d8891210b8e24714b1686` and stages strictly newer comparable macOS test version `1.2.31`. Canonical desktop/native-mobile/iOS marketing semantic versions and existing CI/release guards move together; Android version code and iOS build number remain `29`.

No native assertion, branch-protection rule, product behavior, account/session handling, App-owned gateway ownership, Computer Use safety policy, or release-source gate is weakened. PR #2384 remains the only PR for its existing release-contract failure and will absorb this protected main, advance again, and rerun the restored gates.

Any `v1.2.31` package produced before #2384 is green is intermediate governance evidence only and must not enter App-owned interactive acceptance.
