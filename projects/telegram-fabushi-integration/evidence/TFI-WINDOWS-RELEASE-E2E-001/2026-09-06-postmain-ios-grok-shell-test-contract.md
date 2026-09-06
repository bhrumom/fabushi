# Windows release post-main blocker — iOS authenticated Grok shell UI-test contract

- Windows candidate source: `9a82893c75340188c549786cbbf987b57a2e6480` (`1.2.40`).
- Exact-source Electron run: `34020086944`; Windows/Linux/macOS package jobs and packaged user journeys succeeded. Windows package artifact: `9985275455`; Windows diagnostics artifact: `9985270183`.
- Exact-source Native mobile run: `34020086941`; Android succeeded, Native iOS job `101450938184` failed in step `SwiftUI unit and simulated user UI tests`.
- Both failing cases retried once and failed twice at `FabushiUITests.swift:137`: `testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable` and `testMiniAppOpensAndClosesDedicatedWebMcpSurface`.
- The shared `launchAuthenticatedApp()` helper waited for legacy `app-shell` after authentication. Product routing now intentionally renders `GrokMobileShell.home` after authentication and exposes the legacy workbench only through the profile/avatar entry. The Grok semantic surface already calls that entry `grok-mobile-legacy`, but the corresponding SwiftUI button lacked the same XCTest accessibility identifier.
- `9a82893c...` through live `main@f1d2a69b4d365e1755befbd4f75515318b06ecdd` contains no iOS product-code change in this routing path; only the iOS marketing-version mirror changed. Therefore the 1.2.40 failure is a stale UI-test contract, not an installer or Windows package failure.

## Atomic correction

1. Add `accessibilityIdentifier("grok-mobile-legacy")` to the existing Grok-home button that already opens the legacy workbench; no navigation or login behavior changes.
2. Update only the iOS UI-test helper to accept the authenticated Grok home as the real post-login surface, invoke that stable legacy entry, then retain all existing `app-shell`, marketplace, remote-computer and MiniApp assertions.
3. Validate only in GitHub Actions. No local iOS build, simulator or UI test is permitted for this repair.
