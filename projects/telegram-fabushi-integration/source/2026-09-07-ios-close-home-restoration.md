# iOS remote-computer close must restore Home — 2026-09-07

- Project/task: `FAB-P0001 / TFI` · `TFI-M11-IOS-INTERACTIVE-001`
- Triggering canonical main: `dca0fea5f93567df3928b9a3ee14855ed0da2c67`
- Native mobile run: `34056507262` — `failure`
- Exact iOS result artifact: `9996206512` (`ios-native-xcresult`)
- Android interactive follow-up: `34057093531` — independent dca evidence; it does not qualify a later canonical main.

## Observed failure

The dca Native iOS SwiftUI UI suite fails both iterations of `testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable`. The test successfully observes `remote-computer-surface`, invokes the close helper, and then observes that surface's accessibility marker disappear. It immediately enters `openMarketplace`, but `profile-avatar` never reappears within the 10-second bound; the assertion fails at `mobile/ios/FabushiUITests/FabushiUITests.swift:145` in both iterations.

The same exact `.xcresult` records `testMiniAppOpensAndClosesDedicatedWebMcpSurface` passing, so this blocker is not the controlled Mini App WebMCP facade or the dedicated Mini App close flow.

## Boundary

PR #2461 added a test-only coordinate fallback for SwiftUI's `AXScrollToVisible` flake. Its identifier lookup uses `app.descendants(matching: .any)[identifier]`. A generic `any` match can represent an accessibility proxy rather than the concrete SwiftUI Button. Therefore a coordinate action can make the queried surface marker disappear without proving that the real `onClose` action restored `destination = .home`.

Product semantics remain unchanged: `RemoteComputerSurface` closes by setting `destination = .home`; its root is already an accessibility container and the `返回` Button already has `remote-computer-close`.

## Atomic repair contract

1. Resolve an identifier-based close control as a real `XCUIElementTypeButton` (`app.buttons[identifier]`), retaining the visible `返回` Button fallback.
2. Keep the normal hittable semantic tap first. If the real Button exists with a valid frame but is not hittable, retain the existing screenshot and element-frame center-coordinate fallback.
3. For the remote-computer journey, require both `remote-computer-surface` disappearance and Home restoration (`app-shell` plus `profile-avatar`) before opening Marketplace.
4. Do not weaken stale-generation, auth, WebKit, Marketplace, Mini App, or post-close assertions. Do not change product navigation merely to satisfy the test.
5. Build and SwiftUI/UI validation run only on GitHub Actions. No local Xcode build/test.

## Acceptance

- [ ] Atomic PR required checks are green.
- [ ] Protected merge creates a strictly newer canonical `main`.
- [ ] New exact-main Native mobile gate has iOS and Android green.
- [ ] New iOS `.xcresult` is uploaded; if the coordinate fallback is exercised, its screenshot attachment is retained.
- [ ] New exact-main Electron/Web Mini App journey proves Marketplace search/install, Bot presence, natural-language WebMCP, open Web UI, shared durable revision, bounded Fabushi account projection, and test-mode CNY 1080 purchase/restore.
- [ ] Complete Web/Mini App video, meaningful step screenshots, trace, report, and logs are uploaded under the same exact canonical SHA. Any missing item remains `PENDING`.
