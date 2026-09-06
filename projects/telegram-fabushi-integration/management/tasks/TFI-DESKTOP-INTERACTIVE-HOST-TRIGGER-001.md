# TFI-DESKTOP-INTERACTIVE-HOST-TRIGGER-001 — desktop interactive Host trigger coverage

- Project: `FAB-P0001 / TFI`
- Status: `in-progress`
- Baseline: `main@89922b7907d80d0840da5f394444a4affcbe45f4`
- Branch: `fix/tfi-desktop-interactive-host-trigger-20260907`
- Source: `projects/telegram-fabushi-integration/source/2026-09-07-desktop-interactive-host-trigger-coverage.md`

## Objective

Ensure any protected-main change to the embedded Mahayana product/Host runtime that can affect login, Host startup or App-owned device registration automatically creates fresh same-SHA Windows and macOS interactive packaged evidence.

## Acceptance

- [ ] Windows interactive push paths include `third_party/mahayana/mahayana-rs/mahayana-product/**`.
- [ ] Windows interactive push paths include `third_party/mahayana/mahayana-rs/mahayana-app-host/**`.
- [ ] macOS interactive push paths include the same two embedded runtime path families.
- [ ] Both dependency-free workflow contracts assert the trigger ownership paths.
- [ ] No runtime, release selection, account, App-owned registration, semantic-tool, recording, signing, final logout or always-upload evidence behavior changes.
- [ ] Required PR GitHub Actions pass; no local build/test.
- [ ] Protected merge only; read back resulting canonical main.
- [ ] Resulting canonical push starts both Windows and macOS interactive workflows on that exact SHA.
- [ ] Each interactive run resolves/installs only a Release whose resolved target equals its exact workflow source SHA.
- [ ] Final acceptance remains PENDING until exact final canonical Electron/native/post-main/Release and both packaged interactive evidence artifacts are terminal and Global Dharma search/install/Bot/Open App/WebMCP/same-revision/auto-login/CNY1080 sandbox purchase+restore are proven with downloadable visual/trace/report/log evidence.

## Current evidence

- canonical `89922b7907d80d0840da5f394444a4affcbe45f4` protected-merged PR #2473.
- exact-main Electron run `34063125207` and native run `34063125280` started.
- exact-main run inventory contains no Windows or macOS interactive run for `89922b79...`.
- current Windows/macOS workflow push filters omit both embedded runtime path families.
- `fabushi test` connector remains account-connect HTTP 400, so external semantic control must not be fabricated; repository/CI work proceeds independently.

## Open-source-first decision

Use native GitHub Actions `paths:` ownership plus existing dependency-free Node contract tests. No third-party dependency or protocol is introduced.

## Next action

Patch the two workflow trigger lists and their two contract tests, open a single governance PR, protected-merge, then continue the delivery chain only from the resulting canonical SHA.
