# TFI-M6-MAINSAFE-001 post-merge blocker raw evidence — 2026-09-05

Status: `ARCHITECTURE EVIDENCE / ACCEPTED-MAIN FAILURE VERIFIED`

## 1. Canonical/product merge truth

- accepted canonical main: `63e49b87d1ca5ad64d988e73769bf4a4ed796a19` (live branch readback, protected).
- product PR #2345: merged, final product head `9c46c1d8f030be390995cc78f321aac0d96b7f44`, merge commit/current accepted main `63e49b87...`, merged at `2026-09-05T02:29:10Z` through protected merge queue.
- merge-group run `33939126976`: canonical-version job `101232897597` SUCCESS; required `CI result` job `101233054947` SUCCESS on the accepted group SHA.

This closes the prior exact-head/version bootstrap lineage as accepted provenance. The post-merge failure is downstream.

## 2. Exact-main delivery truth

- Electron packaged run `33939200878`: SUCCESS.
- Native run `33939200888`: FAILURE.
- live Native run job list identifies Android job `101233115022` as SUCCESS.
- previously reported Android job `101233118496` cannot be resolved by the GitHub job-log endpoint (404); it is not used as verified evidence.
- iOS job `101233115134`: FAILURE.

### iOS failing step

`SwiftUI unit and simulated user UI tests` starts `2026-09-05T02:35:14Z` and ends failed at `02:43:39Z`. XcodeGen/build/simulator-selection prerequisite steps succeeded. `Upload iOS result bundle` subsequently succeeds.

### Raw failure text / source correlation

Raw job log obtained from GitHub job `101233115134` and the accepted-main source establish:

- waits `15.0s` for `mobile-login-browser`;
- then waits `20.0s` for `app-shell`;
- `FabushiUITests.swift:137: error: ... XCTAssertTrue failed`;
- failing current identifiers: `testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable` and `testMiniAppOpensAndClosesDedicatedWebMcpSurface`, each retried once;
- summary: `Executed 5 tests, with 4 failures (0 unexpected) in 314.628 (314.634) seconds`;
- later runner diagnostics include `Test runner exited before starting test execution` / inability to attach a runner message port on a later retry phase;
- final `Process completed with exit code 65`.

Accepted-main source line 137 is `XCTAssertTrue(app.otherElements["app-shell"].waitForExistence(timeout: 20))`. The helper treats `mobile-login-browser` as optional, so the proven functional boundary is failure to reach `app-shell`; this record does not invent a deeper product root cause.

### iOS artifact

- artifact id/name: `9961442374 / ios-native-xcresult`
- size: `123,993,171` bytes
- SHA-256: `7450fe8888c275d76d3416dcaf0e70273b2181cfb1fe11b4435bcdf1570b9dc2`
- bound run/head: `33939200888 / main@63e49b87...`
- expiry: `2026-09-19T02:43:45Z`

Read-only extraction of this GitHub artifact agrees with the raw job log/test identifiers and line 137. Current 14-day expiry is also direct evidence for `EVIDENCE-CONTRACT-001`.

## 3. Delivery-topology gap — separate fact

All three stable task files already exist on Architecture PR #2340 and are reused:

- `management/tasks/TFI-M6-MAINSAFE-001-IOS-FIXTURE-001.md`
- `management/tasks/TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001.md`
- `management/tasks/TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001.md`

Each exact path returns 404 on accepted `main@63e49b87...`. This means the Architecture task records are not yet delivered to canonical main. It is **not** the cause of the iOS test failure and must be tracked separately.

## 4. Open-source-first evidence research

Repository-native path is retained; no parallel system is introduced:

| Source | License / authority | Reuse decision | Rejected alternative |
|---|---|---|---|
| `actions/upload-artifact` | GitHub official, MIT | existing always-path artifact upload + retention controls | no parallel artifact service |
| Microsoft Playwright | Apache-2.0 | existing trace/video/screenshot/HTML report primitives | no second E2E framework |
| `swiftlang/swift-corelibs-xctest` | Apache-2.0 | mature XCTest behavior reference; existing XCTest/XCUITest remains platform path | no new iOS test runner/auth-mock library |
| repository Feature Host / launch environment seams | repository-native | deterministic fixture input should reuse existing DI seam | no separate auth fixture service |

No upstream source code is copied and no new third-party dependency/license obligation is introduced by the architecture plan.

## 5. Test-release records-only provenance

- branch: `records/tfi-m6-mainsafe-001-test-release-20260905` (unprotected)
- head commit: `6d45a60df5c9d7f7dc841a46806cc75fe8d103d7`
- actual GitHub commit message: `docs(tfi): log MAINSAFE protected merge and test-release block`
- changed path: only `projects/telegram-fabushi-integration/management/07-变更日志.md`
- GitHub `commits/{sha}/pulls` association query: empty; no associated PR was found.

A previously supplied message string `records(test-release): log MAINSAFE protected merge and test-release block` does not match the live commit message and is retained only as an input discrepancy, not repository truth.

## 6. Architecture PR / old PR provenance

- #2340 remained OPEN / UNMERGED before this write; live pre-write head was `9da26347e6de37a6576198b0f09d36928cbb1b0a`, 37 changed files, all under `projects/telegram-fabushi-integration/**`.
- a previously reported #2340 SHA `328bcf0b2fa10548da61d090622bee8adde40929` is not resolvable by the current GitHub commit endpoint (`No commit found for SHA`); no ancestry claim is made from it.
- #2341 `2241c856fb3da498ac99ade89007fe01dd335183`: historical version-only blocked provenance.
- #2342 `570b874318bfe42406c6f46f51798baed8c89e48`: historical guard-only blocked provenance.
- #2343 `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`: historical bootstrap candidate/review-failed provenance.
- #2344 `b60b8e2483333db21ca6cea068b7a1be9c0f4851`: historical independent review provenance.
- #2345 `9c46c1d8f030be390995cc78f321aac0d96b7f44`: accepted product PR merged via protected queue to `63e49b87...`.

No historical PR is closed, rebased, retargeted, force-pushed or merged by this Architecture round.
