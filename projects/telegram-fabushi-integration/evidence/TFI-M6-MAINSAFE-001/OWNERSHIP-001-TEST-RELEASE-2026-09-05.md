# OWNERSHIP-001 exact-main test-release evidence — 2026-09-05

Accepted canonical main:

`dbf22b467d35c8af2a074896c355a41993c8c191`

## Merge evidence

- Product PR: https://github.com/bhrumom/fabushi/pull/2336
- Review handoff comment: https://github.com/bhrumom/fabushi/pull/2336#issuecomment-5546493085
- Explicit automerge run: https://github.com/bhrumom/fabushi/actions/runs/33920248647
  - job `101176673378` — authorize/enqueue reviewed green PR
- Merge-group canonical CI: https://github.com/bhrumom/fabushi/actions/runs/33920323994
  - required job `101177336627` / `CI result` — SUCCESS
- Merge-queue fallback: https://github.com/bhrumom/fabushi/actions/runs/33920289602
  - required job `101176799668` / `CI result` — SUCCESS
- #2336 merged at `2026-09-04T21:18:43Z`
- canonical main read-back after merge: `dbf22b467d35c8af2a074896c355a41993c8c191`

## Exact-main workflow evidence

### Electron desktop quality gate

Run: https://github.com/bhrumom/fabushi/actions/runs/33920502884

Run head: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
Final conclusion: **FAILURE**

Jobs:

- Linux: `101177474099` — **FAILURE**
  - checked out exact accepted main
  - failed in `Enforce canonical architecture guard` before package/E2E
  - exact log error: `iOS build number drift: canonical=29 project=28`
  - accepted-main source cross-check:
    - `app-version.json`: iOS build `29`
    - `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28`
  - upload-diagnostics step ran with 90-day intent, but Action reported `No files were found`
  - package/installable/video/trace/screenshots/HTML report: **NOT REACHED / ABSENT**

- macOS: `101177474366` — **SUCCESS**
  - package canonical Electron application: PASS
  - packaged build canonical SHA/contents verification: PASS
  - notarize/staple: PASS
  - packaged Playwright user journey: PASS
  - diagnostics artifact `9955150412`, `fabushi-electron-mac-e2e-diagnostics`, 5,863,088 bytes, expires 2026-12-03, SHA-256 digest `1c0cfb484b90837cc176c629d39583bbf91a63a4fafb0c74ed91a4e73c0af782`
  - installable artifact `9955167307`, `fabushi-electron-mac`, 700,534,407 bytes, expires 2026-12-03, SHA-256 digest `6c1d9861e38f38fea57d848d2b30d975f9552b1e28be2e240ff8476a2812d023`
  - downloaded diagnostics contained:
    - `test-results/grok-reference-prototype-c8c04-iles-and-browser-navigation/video.webm`
    - Playwright traces such as `trace.zip`
    - Playwright screenshots such as `test-finished-1.png`
    - product logs under `grok-parity-evidence/runtime/`
  - evidence limitation: the observed full video is a Grok visual-evidence journey, not one explicit ownership-specific journey; generic config screenshots only on failure.

- Windows: `101177474512` — **SUCCESS**
  - package canonical Electron application: PASS
  - packaged Playwright user journey: PASS
  - diagnostics artifact `9955134590`, `fabushi-electron-win-e2e-diagnostics`, 5,329,531 bytes, expires 2026-12-03, digest `c517cde32aa5986710f123e252d8d641d383d3f735dda8f6a7dbcce84a8dcba1`
  - installable artifact `9955145560`, `fabushi-electron-win`, 287,189,055 bytes, expires 2026-12-03, digest `9e89aecc5b81905512e7a368cfd49ad917766674f8275eb67f0d1a53facb8535`
  - downloaded diagnostics contained the same evidence families: full `.webm` video for Grok visual evidence, Playwright `trace.zip`, screenshots, and runtime logs.

Aggregate job:

- `101180854619` / Electron desktop result — **FAILURE** because Linux failed.

### Messaging Product Gate

Run: https://github.com/bhrumom/fabushi/actions/runs/33920502888
Final conclusion: **SUCCESS**

- Electron Messenger contract job `101177474102` — SUCCESS
- Rust self-hosted product job `101177474454` — SUCCESS
- confirms exact-main messaging contract/test/clippy/Feature Host bridge health at source/product gate level
- no artifact was published by this workflow

This is supporting evidence only; it cannot substitute for packaged acceptance.

### Native mobile quality gate

Run: https://github.com/bhrumom/fabushi/actions/runs/33920502967
Final conclusion: **FAILURE**

- Android `101177474424` — **SUCCESS**
  - shared Rust format/lint/test: PASS
  - Android debug package: PASS
  - Pixel 7 emulator Compose simulated-user tests: PASS
  - artifact `9955288722`, `android-native-reports`, 40,745,703 bytes, digest `ed071830633010e4b6a8d1238247e91cd166cd90acb94cdbdce94a6ebc1899ac`
  - retention: expires 2026-09-18 (14 days)
  - artifact contents include `outputs/apk/debug/app-debug.apk`, HTML unit/androidTest/lint reports, XML/PB test results, and per-test logcat files.

- iOS `101177474816` — **FAILURE**
  - Rust static library, XcodeGen/project generation and simulator setup: PASS
  - `SwiftUI unit and simulated user UI tests`: FAILURE
  - failing test: `testAccountSettingsAndMessagingFlow()`
  - failure: expected `Messenger`, observed `Messaging unavailable`
  - source assertion location from xcodebuild log: `mobile/ios/FabushiUITests/FabushiUITests.swift:97`
  - 5 tests executed, 1 failure
  - artifact `9955210308`, `ios-native-xcresult`, 120,792,341 bytes, digest `db673bd9376c8a70426eed00ab1602ea19ae6d903b9c2ca955abc2687c63d635`
  - retention: expires 2026-09-18 (14 days)

- aggregate `101181766179` / Native mobile result — **FAILURE**

## Required journey coverage judgment

Observed successful evidence:

- macOS/Windows packaged Electron journey execution
- exact-main Messaging Product Gate
- Android package + emulator simulated-user tests

Missing/failed required acceptance:

- Linux package never built due canonical iOS version guard
- iOS simulated-user messaging journey fails before acceptance
- no single packaged ownership-specific journey was found that proves send + subscribe/unsubscribe + community join approval + unread projection together
- required per-step screenshots are not an explicit always-captured contract in current generic Playwright config
- artifact child filenames do not encode exact SHA/platform/run/job/journey/timestamp
- native evidence retention is 14 days, not target 90 days

## Test-version delivery

- Test tag: **NOT CREATED**
- Test/pre-release: **NOT CREATED**
- Release assets: **NOT CREATED**
- Stable release: **NOT CREATED**

Reason: required exact-main packaged/native/evidence gates failed or were incomplete.

## Final evidence classification

**TEST-FAILED / PACKAGED-BLOCKED / NATIVE-IOS-FAILED / EVIDENCE-INCOMPLETE**

This record is not a video-review pass. No handoff to code-review video evidence review is authorized until a later exact-main rerun satisfies all required packaged/E2E/evidence gates.