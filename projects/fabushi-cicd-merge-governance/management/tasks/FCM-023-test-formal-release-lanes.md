# FCM-023 — Fast test release / formal release lane split

- **Project:** FAB-P0003 / FCM
- **Status:** in-progress
- **Source:** `source/2026-09-03-fcm-023-test-formal-release-lanes.md`
- **Owner:** Fabushi engineering automation

## Objective

Remove long application-driving E2E from automatic CI/CD, split release entry points by platform, and provide explicit fast `test` versus strict `formal` release modes. Current delivery target is a macOS test build only.

## Atomic acceptance

| ID | Deliverable | Verification | State |
|---|---|---|---|
| FCM-023.1 | Stop automatic Electron packaged/real-App Playwright | workflow triggers/conditions show no automatic long E2E | implemented |
| FCM-023.2 | Stop automatic native device/simulator E2E | mobile workflow triggers/conditions show UI E2E is explicit-only | implemented |
| FCM-023.3 | Disable automatic GBF seven-gate fan-out | `gbf-release-candidate.yml` is manual-only | implemented |
| FCM-023.4 | Add separate macOS/Windows/Linux/Android/iOS release workflows | five visible manual workflow files | implemented |
| FCM-023.5 | Distinguish test/formal modes | each platform workflow exposes `release_kind`; long E2E only on formal | implemented |
| FCM-023.6 | Produce current macOS test build only | latest branch SHA produces Mac-only artifact; other platform workflows not dispatched | pending |
| FCM-023.7 | Install/launch test build on target Mac for product review | target Mac launch evidence | pending |

## Constraints

- Heavy builds/tests remain GitHub-hosted; do not build the application locally.
- Test artifacts must be clearly non-formal and must not silently become stable/latest production releases.
- Formal release still requires platform E2E and platform trust gates.
- Do not use failing/inaccurate app-driving E2E as an automatic merge/release blocker until recalibrated against a real test build.

## Implementation evidence

- Automatic Electron quality gate is reduced to deterministic architecture/main-process/TypeScript/renderer checks; no Playwright, Host build, packaging, or multi-platform matrix.
- `GBF release candidate regression`, Host E2E, macOS release E2E, Apple auto-store fan-out, and old post-main release chain are manual-only/disabled.
- Desktop releases use one reusable single-platform builder plus `Release macOS`, `Release Windows`, and `Release Linux`.
- `Release Android` and `Release iOS` are manual-only. Their formal modes fail closed until real-build E2E calibration is restored.
- YAML parse, `git diff --check`, `.github/scripts/assert-gbf-release-readiness.py`, `.github/scripts/assert-native-electron-canonical.sh`, and the FCM-023 policy smoke checks passed locally; application builds remain GitHub Actions only. The legacy unreferenced `check-publish-cd-release.sh` still has an unrelated stale account-registration text assertion and is not used as acceptance evidence for this task.
