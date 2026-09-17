# dca0 post-main blocker — iOS legacy back chrome intercepts child close controls

- Project: `FAB-P0001 / TFI`
- Task: `TFI-WINDOWS-RELEASE-E2E-001`
- Canonical source under diagnosis: `dca0fea5f93567df3928b9a3ee14855ed0da2c67`
- Exact-main Electron quality gate: `34056507280` — success on Linux, macOS, and Windows.
- Native mobile run: `34056507262`.
- Failing Native iOS job: `101549283506`.
- Failed step: `SwiftUI unit and simulated user UI tests`.
- Exact iOS result bundle artifact: `9996206512` (`ios-native-xcresult`, source SHA `dca0fea5f93567df3928b9a3ee14855ed0da2c67`).
- Post-main delivery remains fail-closed: Release must not publish until Native iOS and all required exact-main delivery gates succeed.

## Reproduced failure from the exact dca0 xcresult

`FabushiUITests.FabushiUITests/testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable` failed on both its initial execution and retry at `mobile/ios/FabushiUITests/FabushiUITests.swift:145` (`XCTAssertTrue`). The preceding remote-computer close control existed but XCTest recorded it as not hittable, retained the `remote-computer-close-not-hittable` screenshot, and used the existing coordinate fallback. After the tap, `remote-computer-surface` disappeared, but the retained UI hierarchy was `grok-mobile-home`, not the legacy `app-shell`; therefore the subsequent `profile-avatar` assertion could never succeed.

The product cause is the authenticated `GrokMobileShell` legacy branch: an outer `grok-mobile-back` button is placed as a top-leading `ZStack` overlay on top of the entire legacy `ContentView`. Child destinations such as `RemoteComputerSurface` place their own close control in the same top-leading region. When XCTest must use the exact child element frame as a coordinate fallback, the outer overlay receives that tap and sets `legacyOpen = false`, escaping to `grok-mobile-home` instead of executing the child close action.

This is not a timeout relaxation candidate and the XCTest assertion is intentionally unchanged.

## Atomic repair

Replace the legacy `ZStack` overlay with non-overlapping layout chrome: a top `HStack` containing the existing `grok-mobile-back` control and the legacy `ContentView` as the next sibling in `VStack(spacing: 0)`. The outer back control remains user-reachable, but occupies real layout space and cannot cover the remote-computer, Marketplace, or MiniApp child top bar controls.

No account, login, Marketplace, WebMCP, payment, entitlement, Bot, or remote-computer domain behavior changes.

## Open-source-first startup gate

A public SwiftUI layout scan included `L-K-M/BootCaptain#19`, which documents the same general lesson: overlay/safe-area chrome that does not reserve real layout space can cover scrollable child content; the repair uses sibling layout so the chrome occupies real space. Fabushi imports no code or dependency from that repository. This change uses only standard SwiftUI primitives already present in Fabushi, so there is no third-party license payload to add.

## Parallel Android interactive result

The dca0 Android interactive run `34057093531` completed with failure after the released APK installed, the bounded CI account authenticated, the app launched, and the new App-owned device window opened. The run then timed out waiting for the external `@fabushi test` controller to complete the six-tool feature matrix and final logout. Its always-upload artifact is `9996646866` (`android-interactive-app-e2e-34057093531-1`). This is a separate orchestration/evidence timeout, not evidence that the iOS overlay repair fixes Android; it remains independently pending for the next accepted main.

## Verification gate

- Local build/test: **not run**, per user instruction.
- PR validation: GitHub Actions only.
- Completion remains **PENDING** until the repair merges normally into protected `main`, canonical `main` is read back, Native iOS succeeds on that exact SHA, a fresh exact-main Electron packaged E2E succeeds, post-main bind/Release succeeds, and the fresh Linux/macOS/Windows screenshot/video/trace/report/log bundles are present.
