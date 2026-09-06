# TFI-MACOS-RECOVERY-RELEASE-COMPAT-001 — macOS recovery Release compatibility

- Project: `FAB-P0001 / TFI`
- Status: `in-progress`
- Baseline: `main@2bfa9898d453a91119f7dd9a072322970423cd6b`
- Branch: `fix/tfi-macos-recovery-release-compat-20260907`
- Source: `projects/telegram-fabushi-integration/source/2026-09-07-macos-recovery-release-compat.md`

## Objective

Make the macOS App-owned interactive workflow consume the exact-main provenance-scoped recovery Release produced by canonical post-main delivery without weakening exact-SHA fail-closed behavior.

## Root cause

`desktop-1.2.53-2bfa9898d453` is the verified immutable Release for `2bfa9898...`, but the current macOS resolver accepts only prereleases and the install step derives the application version from the Release tag. A stable provenance-scoped recovery tag therefore cannot be selected or version-validated.

## Acceptance

- [ ] Release resolver accepts non-draft stable/prerelease candidates only when the strict macOS ZIP asset exists and resolved target SHA equals exact `GITHUB_SHA`.
- [ ] `prerelease=true` is not a selection prerequisite.
- [ ] Expected app SemVer is parsed from `fabushi-X.Y.Z-macos-arm64.zip`; the recovery tag is never treated as bundle SemVer.
- [ ] Existing 20-minute / 15-second bounded wait and exact-SHA fail-closed assertions remain.
- [ ] Digest, codesign, Gatekeeper, recording-before-resolution/install, bounded account session, App-owned registration, six semantic tools, final logout, Playwright, and always-upload evidence remain unchanged.
- [ ] Dependency-free macOS workflow contract covers both repaired invariants.
- [ ] Required PR checks pass.
- [ ] PR merges through protected main / merge queue.
- [ ] Canonical main is read back after merge.
- [ ] New canonical-main macOS interactive run installs its same-SHA Release and reaches terminal evidence.
- [ ] Broader final delivery remains PENDING until exact final canonical SHA has Electron/Native/post-main/Release, Windows+macOS interactive, and Global Dharma full visual/trace/report/log evidence.

## Current evidence

- `main@2bfa9898d453a91119f7dd9a072322970423cd6b` verified live.
- post-main run `34061585236` / publish job `101562962764` success.
- current-SHA Release: `desktop-1.2.53-2bfa9898d453`, release id `383724937`, `target_commitish=2bfa9898...`, `draft=false`, `prerelease=false`, `immutable=true`.
- macOS interactive run `34060996837` / job `101562624534` is blocked in `Wait for exact-main published macOS test release` by the prerelease-only filter.
- Windows interactive run `34060996833` successfully completed exact-SHA Release resolution, proving the published recovery Release itself exists and is resolvable.
- `fabushi test` connector currently returns account-connect HTTP 400 before device discovery, so the live Windows external semantic journey cannot be truthfully driven from this chat until that connection recovers.

## Open-source-first decision

GitHub CLI (`cli/cli`, MIT) models `prerelease` and `target_commitish` independently. We retain exact resolved `target_commitish` as the provenance authority and do not introduce a new dependency or copy upstream code.

## Next action

Patch only the macOS workflow and its ownership contract, run required PR checks, protected-merge, then restart the exact-main delivery loop from the resulting canonical main.
