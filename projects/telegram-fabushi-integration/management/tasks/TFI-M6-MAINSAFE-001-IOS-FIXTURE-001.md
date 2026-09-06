# TFI-M6-MAINSAFE-001-IOS-FIXTURE-001 — exact-main iOS deterministic auth/bootstrap fixture

- Project: `FAB-P0001 / TFI`
- Status: `FROZEN / READY_FOR_EXECUTION_HANDOFF`
- Requirement ID: `M6-PM-IOSF-R01`
- Acceptance ID: `M6-PM-IOSF-A01`
- Accepted product baseline: `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`
- Accepted product PR: `#2345`, product head `9c46c1d8f030be390995cc78f321aac0d96b7f44`, merged through protected merge queue at `2026-09-05T02:29:10Z`
- Failure run/job/artifact: Native run `33939200888` / iOS job `101233115134` / `ios-native-xcresult` artifact `9961442374`
- Parent boundary: `TFI-M6-MAINSAFE-001`; completed ownership/version work is not reopened.

## M6-PM-IOSF-R01 — requirement

Provide a deterministic, app-local iOS test auth/bootstrap input for the existing Native iOS job so the canonical UI-test helper can reach the authenticated `app-shell` without depending on an external browser, real account, ambient network login state, or nondeterministic prior process state. The input must use the repository's existing test-host / launch-environment dependency-injection pattern and must not weaken the semantic UI journeys.

## Accepted-main raw failure boundary

For `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`, Native run `33939200888` reaches XcodeGen/build/simulator selection successfully, then step `SwiftUI unit and simulated user UI tests` fails. Raw job log and xcresult agree:

- `testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable` and `testMiniAppOpensAndClosesDedicatedWebMcpSurface` each fail and retry once;
- each attempt waits 15 seconds for `mobile-login-browser`, then 20 seconds for `app-shell`;
- the decisive assertion is `FabushiUITests.swift:137` — `XCTAssertTrue(app.otherElements["app-shell"].waitForExistence(timeout: 20))`;
- summary: `Executed 5 tests, with 4 failures (0 unexpected)`; the four failures are retry iterations, not four distinct methods;
- the job later records runner/bootstrap diagnostics including `Test runner exited before starting test execution` on a later retry phase and exits with code 65.

`mobile-login-browser` absence is not itself the failing assertion because the helper treats it as optional. The proven boundary is that `app-shell` never becomes reachable under the existing deterministic test launch. This record does not claim a deeper product root cause beyond that observed fixture/bootstrap boundary.

Artifact `9961442374` is bound by GitHub metadata to run `33939200888`, branch `main`, SHA `63e49b87...`, size `123,993,171` bytes, SHA-256 `7450fe8888c275d76d3416dcaf0e70273b2181cfb1fe11b4435bcdf1570b9dc2`; current expiry is `2026-09-19T02:43:45Z`.

## Delivery-topology distinction

This task file already existed in Architecture PR #2340 and is reused. Its exact path is still 404 on accepted `main@63e49b87...`. That 404 is a records-delivery topology gap and is independent of the real accepted-main iOS test failure above.

## Inputs / dependencies

- implementation branch starts from freshly re-read canonical `main@63e49b87...` unless main has advanced, in which case execution must record the new main and stop if assumptions changed;
- task contract is read from the latest head of Architecture records-only PR #2340;
- exact accepted-main failure evidence: run `33939200888`, job `101233115134`, artifact `9961442374`;
- existing Native workflow/test-host behavior is an input, not an allowlisted edit in this task.

This implementation task is independent of `EVIDENCE-CONTRACT-001` and may execute in parallel with it. Test-release closure still requires all three post-merge tasks.

## Exact implementation allowlist

Only the smallest necessary subset of these existing iOS paths may change:

- `mobile/ios/Fabushi/FabushiApp.swift`
- `mobile/ios/Fabushi/MarketplaceModel.swift`
- `mobile/ios/Fabushi/ContentView.swift`
- `mobile/ios/Fabushi/MahayanaHost.swift`
- `mobile/ios/FabushiUITests/FabushiUITests.swift` — fixture/bootstrap instrumentation only; existing semantic journeys/assertions must remain unweakened.
- task-specific records under `projects/telegram-fabushi-integration/**`.

## Forbidden files / actions

- all `.github/workflows/**` and workflow behavior;
- `app-version.json`, `mobile/ios/project.yml`, Android version/config, release/version logic;
- Rust product/core, Android, Desktop/Electron application source;
- Cargo/dependency/lockfile changes;
- broader test rewrites, skipped tests, relaxed assertions, timeout inflation, retry inflation, expected-string rewrites, unconditional-pass seams;
- root `AGENTS.md`, `projects/PORTFOLIO.json`, unrelated project records;
- local build/test; heavy verification is GitHub Actions only.

Any need outside this allowlist is `SCOPE-EXPANSION-REQUIRED`: stop and return to Architecture.

## Open-source-first decision

Reuse the repository's existing SwiftUI/XCTest/XCUITest launch-environment and Feature Host dependency-injection seams. Mature upstream reference is Swift XCTest (`swiftlang/swift-corelibs-xctest`, Apache-2.0); Apple XCTest/XCUITest remains the platform execution API. No new auth mocking framework, dependency, test runner, or parallel fixture service is introduced; therefore there is no new dependency-license impact.

## M6-PM-IOSF-A01 — acceptance / gates

1. Final execution diff is wholly inside the allowlist and records the exact canonical baseline and exact PR head.
2. Current-head Native iOS evidence proves the test host deterministically reaches `app-shell` without external browser/account/network login dependency and without assertion/timeout/retry weakening.
3. All canonical iOS UI identifiers pass; raw job log plus xcresult are attached with run/job/test identifiers.
4. Independent Code Review audits the exact final execution head, allowlist, fixture isolation, and non-weakening rule; no Architecture self-approval substitutes.
5. Only after review may the product PR enter protected merge queue. Its `merge_group` required gates must execute and succeed; skipped/neutral/manual/history/different-SHA evidence is not accepted.
6. After merge, canonical main is re-read and must contain the reviewed change at a new accepted SHA.
7. Test Release remains blocked until `M6-PM-IOSF-A01`, `M6-PM-EVC-A01`, and `M6-PM-EVJ-A01` have all passed protected-main + canonical-readback gates.
8. Any new semantic product failure, missing artifact identity, scope expansion, or changed canonical assumption fails closed back to Architecture; do not repair it inside this task.
