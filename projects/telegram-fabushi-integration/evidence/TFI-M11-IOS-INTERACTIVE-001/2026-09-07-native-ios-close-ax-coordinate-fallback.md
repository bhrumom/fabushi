# Native iOS close-control AX coordinate fallback — 2026-09-07

- Project/task: `FAB-P0001 / TFI` · `TFI-M11-IOS-INTERACTIVE-001`
- Triggering canonical main: `43ce998fd5fbcae032c179a8814de9ec08d03f4c`
- Native mobile run: `34055531700`
- Native Android job: success; Native iOS first-attempt job failed in `SwiftUI unit and simulated user UI tests`.
- iOS result artifact: `9995961959` (`ios-native-xcresult`), archive endpoint `https://api.github.com/repos/bhrumom/fabushi/actions/artifacts/9995961959/zip`.

## Observed failure

`testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable` reached `RemoteComputerSurface` and found the `remote-computer-close` / `返回` control. XCUITest reported a real frame `{{12.0, 82.3}, {34.0, 20.3}}`, but three normal `tap()` attempts failed because XCTest tried `AXScrollToVisible` and the simulator returned `kAXErrorCannotComplete`. The existing product view already uses `.accessibilityElement(children: .contain)` and keeps `remote-computer-close` independently identified, so repeating the older containment product fix would be incorrect.

The first-attempt `.xcresult` is retained as the artifact above. Its result-store attachment data is preserved even though the Linux inspection environment cannot faithfully render Xcode result-store screenshots. The repaired test itself now attaches a fresh `XCUIScreen.main.screenshot()` whenever the coordinate fallback is required, so the next GitHub Actions `.xcresult` will retain the visible state at the exact fallback point.

## Minimal repair

`FabushiUITests.tapSurfaceClose` keeps normal semantic identifier/label lookup and normal `tap()` whenever the element is hittable. If XCTest reports the already-existing element as not hittable but it has a non-empty real frame, the test:

1. saves a `.keepAlways` screenshot attachment;
2. taps the center coordinate of that exact `XCUIElement` frame using `coordinate(withNormalizedOffset:)`;
3. leaves the existing `waitForNonExistence` post-close assertion unchanged.

No hard-coded device coordinate, product navigation change, remote-computer network change, auth change, WebKit change, or assertion weakening is introduced.

## Acceptance

- [ ] PR checks pass on GitHub Actions; no local Xcode build/test.
- [ ] Protected merge produces a new canonical main SHA.
- [ ] New canonical-main Native mobile run has Native iOS and Native Android success.
- [ ] iOS result artifact contains the repaired run `.xcresult`; if fallback is exercised, its screenshot attachment is retained.
- [ ] Latest-canonical Android packaged journey independently retains complete video, meaningful screenshots, trace/report/logcat; missing items remain `PENDING`.
