# FCM-011 — Desktop updater channel reliability

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-011
- **Status:** in-progress
- **Started:** 2026-08-24T13:52:00+08:00
- **Updated:** 2026-08-24T14:00:00+08:00
- **Branch:** `fix/desktop-updater-idle-energy`

## Objective
Make a running Fabushi macOS client reliably discover the canonical desktop GitHub Release without requiring a process restart, while preventing Android/iOS/other repository releases from stealing GitHub's `Latest` pointer used by `electron-updater`. Repair the canonical post-main publication path so future desktop Releases publish atomically with updater assets.

## Diagnosed evidence
- Installed macOS app `1.0.2` persisted updater error: `Cannot find latest-mac.yml` under `android-v1.0.2-262331106`; GitHub `Latest` pointed at an Android delivery with no macOS metadata.
- After canonical `desktop-1.0.798` became GitHub Latest, a real process restart changed persisted `updateStatus` to `available / 1.0.798` and the UI displayed `更新 1.0.798`.
- The desktop main process only performed one automatic check four seconds after startup, so a long-running macOS process never revisited a corrected/new Release until restart/manual action.
- Post-main run `32693968757` validated exact-SHA updater assets but failed in the old draft/create/upload mutation sequence; recovery run `32694503412` proved `gh release create <tag> <assets...>` works.

## Open-source-first baseline
- `electron-userland/electron-builder` / `electron-updater` (MIT): retain its GitHub provider and generated `latest-mac.yml`; upstream troubleshooting confirms draft/missing-channel metadata causes update discovery failures.
- `electron-updater` already deduplicates concurrent `checkForUpdates()` calls, so Fabushi can safely add a throttled foreground/focus scheduler instead of inventing a new updater.
- Decision: adapt proven upstream behavior; no new updater protocol or dependency.

## Atomic work
1. Reserve repository GitHub `Latest` for canonical desktop Releases; non-desktop/store workflows publish with `--latest=false`.
2. Add delivery-governance contract coverage for Apple/Google store release latest-pointer safety.
3. Replace fragile draft + upload + patch post-main publication with atomic create-with-assets, including stale draft cleanup and exact-SHA verification.
4. Recheck updates on app/window focus after a throttle window and every five minutes only while a Fabushi window is focused; keep the initial startup check.
5. Preserve updater compatibility and run the already-available old-client discovery proof for this release; a two-release no-restart focus journey remains sampled/non-blocking unless a later updater change explicitly promotes it.

## Acceptance
- Scheduler/contract coverage proves a running packaged macOS client rechecks on focus/foreground cadence without background polling; the existing 1.0.2 client already proves canonical desktop metadata discovery after a real restart.
- Android/iOS/other non-desktop Release workflows cannot become repository Latest.
- Canonical post-main desktop publication is atomic and leaves `latest-mac.yml`, ZIP, DMG and blockmaps on the Release.
- Automatic checks are throttled and do not create background network polling.
- PR passes required CI, merge queue, canonical-main post-merge package/E2E/Release gates, and exact main readback.

## Local verification before PR
- `node --check desktop/electron/main.cjs` — pass.
- Changed GitHub Actions YAML parsed successfully with PyYAML.
- `node --test desktop/electron/host-process.test.cjs` — 5/5 pass.
- `python3 .github/scripts/assert-fabushi-desktop-architecture.py` — pass.
- `bash .github/scripts/assert-electron-feature-host-bridge.sh` — pass.
- Release ownership source checks: Apple / Google Play / native-electron / Global Dharma / important release paths all contain `--latest=false`; canonical post-main retains `--latest`.

## PR CI finding
- PR #2092 rollback drill initially failed because `.github/workflows/gbf-rollback-drill.yml` selected the first stable Release across every platform. A mobile/non-canonical Release can therefore be treated as the desktop rollback image.
- The drill now selects only canonical `desktop-x.y.z` stable Releases and requires `latest-mac.yml`, a DMG, a macOS ZIP and checksums before accepting the rollback target.
- The refreshed drill then exposed a producer defect in `desktop-1.0.798`: Windows/Linux channel metadata referenced non-ASCII/default builder names that did not equal the GitHub-published asset names, and `SHA256SUMS.txt` also contained a self-entry for an empty checksum file.
- Electron Builder now emits deterministic ASCII artifact names for Windows/Linux at source; post-main publication validates every `url:` in all `latest*.yml` files against a collected asset before release and builds `SHA256SUMS.txt` in `$RUNNER_TEMP` before moving it into the asset directory.
- The rollback drill verifies legacy 1.0.798 by content digest rather than stale filename, preserving full byte-integrity proof while future releases use exact canonical filenames.

## Current evidence / next gate
Implementation pending refreshed PR CI, protected merge, exact-main packaged delivery and Release verification.

## 2026-08-24 updater interaction continuation

The user validated `1.0.798` and reported two remaining UX regressions: the update control exposed no download progress and the first click could stop at `ready`, requiring a second `安装更新` click. The installed ChatGPT app on the same Mac bundles Sparkle and has automatic checking/updating enabled; Sparkle's public API explicitly models download, extraction, ready-to-install and relaunch states. Fabushi keeps `electron-updater` but adopts the same state-machine quality:

- `download-progress.percent` is rendered as a visible progress rail plus percentage text;
- one click attaches to the real `update-downloaded` event before download begins, then transitions to staging and schedules `quitAndInstall`;
- `autoInstallOnAppQuit=true` is a fallback if the process exits normally after download;
- the renderer stays busy through downloading/staging instead of re-enabling a misleading second click;
- release updater E2E fails if a downloading state has no progress UI or if the old app does not close automatically after the single click.

This task now treats the old-client updater journey as required because FCM-011 directly changes updater behavior.
