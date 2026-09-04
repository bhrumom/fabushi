# TFI-M6-MAINSAFE-001-IOS-FIXTURE-001 — exact-main iOS deterministic auth/bootstrap fixture

- Project: `FAB-P0001 / TFI`
- Status: `FROZEN / NOT_STARTED`
- Architecture baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Failure run/job/artifact: `33920502967 / 101177474816 / 9955210308`
- Parent boundary: `TFI-M6-MAINSAFE-001`; completed `OWNERSHIP-001` is not reopened. `MAINSAFE-002/003` remain stopped.

## Root-cause classification

This is a **current-main iOS deterministic fixture/bootstrap capability failure**, not stale DerivedData, wrong checkout, or artifact/report cross-wire.

Evidence chain:

1. run event=`push`, ref/head=`main@dbf22b467d35c8af2a074896c355a41993c8c191`; checkout log resolves `HEAD` to the same SHA.
2. `actions/cache/restore@v4` requested `/Users/runner/work/_temp/FabushiDerivedData` with exact key `ios-derived-v6-e76c8d311dea253ae97ca76b548e2c58444edf21fd74b9ef2affbed12a933574-dbf22b467d35c8af2a074896c355a41993c8c191` and the matching prefix, then logged **Cache not found for input keys**. No DerivedData was restored.
3. xcodebuild used that fresh DerivedData path and SwiftCompile explicitly compiled `/Users/runner/work/fabushi/fabushi/mobile/ios/FabushiUITests/FabushiUITests.swift` from the fresh checkout.
4. canonical blob `a7e071217f480ddf4b5e6b2b05e6a94382f945af` defines exactly three UI-test identifiers: `testCompleteFeatureHostUserJourneyInAppProcess`, `testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable`, `testMiniAppOpensAndClosesDedicatedWebMcpSurface`. The xcresult/result log uses the same identifiers and contains XCUITest failure screenshots/recordings. `testAccountSettingsAndMessagingFlow()` is absent from the exact-main blob and current repository search.
5. the two failing tests both fail before their intended Marketplace/MiniApp journey: after onboarding skip, `mobile-login-browser` does not appear within 15 seconds and `app-shell` does not appear within the following 20 seconds. Both retry attempts reproduce the same bootstrap failure. The same run's Feature Host smoke test passes, so there is no evidence to blame Community/Messaging ownership semantics or MiniApp routing.

The `5 tests / 4 failures` XCTest summary counts retry iterations; it is not five distinct test methods. Any #2339 statement naming `testAccountSettingsAndMessagingFlow()` or `Messaging unavailable` for this exact run is superseded by the raw job/xcresult chain above.

## Future execution allowlist

Only these paths may be changed initially:

- `mobile/ios/Fabushi/FabushiApp.swift`
- `mobile/ios/Fabushi/MarketplaceModel.swift`
- `mobile/ios/Fabushi/ContentView.swift`
- `mobile/ios/Fabushi/MahayanaHost.swift`
- `mobile/ios/FabushiUITests/FabushiUITests.swift` — fixture/bootstrap instrumentation only; existing semantic assertions/test journeys must not be weakened, deleted, skipped, or converted to unconditional pass.

If the minimal fix requires any Rust product/core file, Android/Desktop file, workflow, Cargo/dependency, version file, or broader test rewrite, **STOP** and return to architecture for a new atomic task; do not expand scope in execution.

## Prohibited

- no product-route changes justified only by the stale #2339 test name;
- no relaxed timeout/assertion, skipped test, expected-string rewrite, or retry inflation to hide failure;
- no workflow/cache key change in this task;
- no `app-version.json`, `mobile/ios/project.yml`, Android, desktop, Cargo/dependency, or release change;
- no local build/test; verification is GitHub Actions only.

## Acceptance

1. PR diff is within the allowlist and preserves the three canonical UI journeys.
2. Current-head GitHub Actions proves the deterministic test host reaches the authenticated `app-shell` without external browser/account/network dependency.
3. Native iOS job passes all exact current test identifiers without timeout/assertion weakening; xcresult is retained for review.
4. Independent code review passes the exact execution head.
5. Product PR enters protected `main` merge queue; canonical main is read back after merge.
6. Only after canonical readback may a new test-release session run exact-main packaged/native E2E. A newly exposed semantic product failure stops the release and returns to architecture rather than weakening tests.
