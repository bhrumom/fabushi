# TFI-M6-MAINSAFE-001 post-main failure diagnosis — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Canonical baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Source test-release records: PR #2339 (`d8dfb0638a01c88ca30ca7ee759f897d3cc68d86`), open/unmerged
- Scope: architecture evidence and atomic-task freeze only; no application/test/workflow/Cargo/version implementation in this PR.

## 1. Native iOS exact-main evidence chain

Target: run `33920502967`, job `101177474816`, xcresult artifact `9955210308`.

### Run / checkout identity

- Workflow event: `push`.
- Branch/ref: canonical `main`.
- Run head: `dbf22b467d35c8af2a074896c355a41993c8c191`.
- `actions/checkout@v5` starts from a cleaned GitHub-hosted runner workspace and checks out the same exact commit; the original job log's final repository HEAD resolves to `dbf22b467d35c8af2a074896c355a41993c8c191`.
- There is no merge-PR synthetic checkout involved in this main-push job.

### DerivedData cache

Workflow requested incremental iOS DerivedData at:

`/Users/runner/work/_temp/FabushiDerivedData`

Exact restore key:

`ios-derived-v6-e76c8d311dea253ae97ca76b548e2c58444edf21fd74b9ef2affbed12a933574-dbf22b467d35c8af2a074896c355a41993c8c191`

with the corresponding `ios-derived-v6-e76c...-` restore prefix.

The original `actions/cache/restore@v4` log says **Cache not found for input keys**. Therefore no exact or fallback DerivedData cache was restored. The later save step cannot explain the tests already executed in this job.

Conclusion: stale restored DerivedData/cache is rejected as root cause for this run.

### Compiled XCTest source/input

The XcodeGen/project-generation steps pass. xcodebuild writes/uses the fresh runner temp DerivedData path and SwiftCompile explicitly compiles:

`/Users/runner/work/fabushi/fabushi/mobile/ios/FabushiUITests/FabushiUITests.swift`

Canonical main blob for that source is:

`a7e071217f480ddf4b5e6b2b05e6a94382f945af`

It defines these three UI test methods:

1. `testCompleteFeatureHostUserJourneyInAppProcess`
2. `testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable`
3. `testMiniAppOpensAndClosesDedicatedWebMcpSurface`

`testAccountSettingsAndMessagingFlow()` does **not** exist in this exact-main file and repository search finds no current occurrence.

### xcresult identity / attachments

Artifact `9955210308` is named `ios-native-xcresult`; GitHub artifact metadata binds it to workflow run `33920502967`, `head_branch=main`, `head_sha=dbf22b467d35c8af2a074896c355a41993c8c191`.

Read-only extraction of the result bundle shows the same three canonical test identifiers above, retry summaries, XCUITest activities and failure screenshot/screen-recording attachment references. The result bundle therefore matches the compiled canonical UI-test source; it is not evidence of a foreign old test bundle.

The XCTest summary reports `Executed 5 tests, with 4 failures`. That count includes retry executions; it does not imply five distinct source test methods. The raw log's named failures are current canonical methods, including `testMiniAppOpensAndClosesDedicatedWebMcpSurface` at exact-main source line 137.

Conclusion: wrong artifact/report cross-wire and old-test execution are rejected as root cause.

### Actual failure boundary

The canonical helper `launchAuthenticatedApp()` launches with `FABUSHI_FEATURE_HOST_TEST=1`, optionally skips onboarding, then expects either the deterministic login entry to become available and ultimately the authenticated `app-shell`.

Across the failing current test attempts, the raw XCUITest trace shows:

- onboarding skip is found/tapped when present;
- `mobile-login-browser` does not appear within the 15-second bootstrap window;
- `app-shell` also does not appear within the subsequent 20-second window;
- retries reproduce the same bootstrap boundary failure.

`FabushiApp.swift` maps `FABUSHI_FEATURE_HOST_TEST=1` to the test Mahayana Host. `MarketplaceModel.initializeApp()` resolves `feature.auth.status`; `ContentView` then gates onboarding -> auth loading -> login vs authenticated shell. The same job's Feature Host smoke phase passes, so the evidence does not justify blaming Community ownership, Marketplace routing, or the later MiniApp assertions.

### iOS root-cause decision

**CURRENT-MAIN DETERMINISTIC IOS AUTH/BOOTSTRAP FIXTURE/CAPABILITY FAILURE.**

Not stale DerivedData/cache. Not wrong checkout. Not artifact/report cross-wire. It is a current-main native iOS fixture/bootstrap acceptance failure occurring before the intended product journeys. Freeze `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001`; do not create a product routing task and do not weaken UI assertions.

### Correction to #2339

PR #2339 records currently state that exact-main iOS failed `testAccountSettingsAndMessagingFlow()` with `Messaging unavailable`, `5 tests / 1 failure`. Those statements are superseded by the original Actions log + exact-main source + downloaded xcresult evidence in this record. The correct exact-main result is the three canonical source test identifiers with retry executions and `5 tests / 4 failures`, rooted at deterministic auth/bootstrap reachability.

## 2. Version-contract diagnosis

- `app-version.json`: `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`.
- PR #2318 intentionally changed the canonical Android/iOS store counters from 28 to 29 in that one canonical file and merged as `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- exact-main `mobile/ios/project.yml` still has `CURRENT_PROJECT_VERSION: 28`.
- `.github/scripts/assert-native-electron-canonical.sh` explicitly requires project `CURRENT_PROJECT_VERSION == app-version.json.iosBuildNumber`.
- release workflow reads iOS build number from `app-version.json`, confirming `project.yml` is the stale mirror rather than a second canonical version source.

Decision: freeze `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` with a strict one-file/one-value allowlist: only `mobile/ios/project.yml` `28 -> 29`.

## 3. Evidence-contract diagnosis

Current exact-main evidence plumbing:

- `desktop/playwright.config.ts`: trace `on`, video `on`, screenshot `only-on-failure`, CI HTML report.
- `electron-desktop.yml`: packaged diagnostics upload uses `if: always()` and 90-day retention; paths include Playwright report/results.
- current Electron delivery manifest contains version, exact SHA, run id/run number, platform; it lacks job identity, journey id, and UTC timestamp.
- native mobile Android report and iOS xcresult uploads are both configured for 14-day retention.
- current artifact internals/names do not provide the requested exact-SHA/platform/run/job/journey/timestamp evidence namespace.

Decision: freeze `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` for pass/fail always-upload, meaningful-step screenshots, complete video, trace/report/runtime/native logs, exact identity manifest/naming, and target 90-day evidence retention.

## 4. OWNERSHIP packaged journey diagnosis

The existing desktop E2E suite has broad Messenger/Grok/MiniApp journeys, but repository search and the exact-main test-release artifacts do not identify one dedicated packaged journey proving the whole completed OWNERSHIP-001 boundary: send + subscribe/unsubscribe + Community join approval + unread projection under preserved ownership identities.

Decision: freeze `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001`. It must be a proof task only. If the unweakened journey reveals a semantic product defect, execution stops and returns to architecture; assertions may not be relaxed.

## 5. Open-source-first review

| Source | License / authority | Adopt | Reject / do not copy |
|---|---|---|---|
| Apple XCTest / XCUI activities & attachments | Apple official XCTest documentation | named substeps, screenshots/attachments as test evidence | no Apple implementation code copied |
| swift-corelibs-xctest | Apache-2.0 + runtime-library exception | mature open XCTest behavior reference only | no source copy needed |
| GitHub Actions cache / `actions/cache` | GitHub official; MIT | exact/partial cache matching semantics; cache is rebuildable optimization | do not treat cache as test provenance; no code copied |
| GitHub Actions artifacts / `actions/upload-artifact` | GitHub official; MIT | artifacts for post-job evidence, explicit retention | do not use artifact storage as a cache substitute; no code copied |
| Playwright | Microsoft official; Apache-2.0 | native trace/video/screenshot/test-step/report primitives | no copied upstream implementation; repository-specific evidence contract is authored locally |

The design follows official/mature behavior and licenses but copies no external code.

## 6. Frozen atomic tasks and dependency graph

- `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001` — independent current-main iOS fixture/bootstrap repair.
- `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` — independent single-file iOS build-number mirror repair.
- `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` — evidence plumbing contract.
- `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` — depends on EVIDENCE-CONTRACT-001 and completed canonical OWNERSHIP-001 semantics.

Post-main packaged/test-release acceptance depends on all applicable frozen tasks being independently implemented, independently reviewed, merged via protected main, and read back from a new canonical SHA.

Execution, code review, test release, and stable release remain paused until architecture records are handed off. `MAINSAFE-002/003` remain explicitly not started.
