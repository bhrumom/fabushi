# Application Automation Testing Standard

Fabushi uses a layered test strategy modeled after mature large-scale mobile/desktop teams: fast deterministic tests at the bottom, a small number of semantic E2E tests at the top, and physical-device coverage for risks that simulators cannot represent.

## Quality pyramid

### 1. Shared Rust host

Required on every relevant pull request:

- `cargo fmt --check`
- `cargo clippy -- -D warnings`
- unit/contract tests for `mahayana-app-host`, plugin runtime, and JavaScript runtime
- architecture contract that prevents shell-specific business logic from becoming the canonical implementation

### 2. Desktop Electron

PR/main matrix: macOS, Windows, Linux.

- TypeScript typecheck and renderer production build.
- Static syntax checks for privileged Electron code.
- Playwright Electron E2E using semantic locators (`getByTestId`, role/name).
- Security assertions verify renderer cannot access Node globals and preload exposes only the approved API.
- Traces, screenshots, videos, and packaged artifacts are retained on failure.
- Installer packaging runs on all three desktop OSes.

### 3. Android native

PR/main:

- JVM unit tests.
- Android Lint.
- release/debug package compilation as appropriate.
- Compose UI tests on an emulator using `testTag`/Semantics.

Main/release or explicit run:

- Firebase Test Lab physical-device instrumentation.
- App APK and test APK retained as evidence.

Rules:

- No coordinate-based UI selectors.
- No unconditional sleeps; use Compose idling/synchronization.
- Disable animations in automation environments.
- Test permission denied/cancelled states when native adapters are added.

### 4. iOS native

PR/main:

- XCTest unit target.
- XCUITest UI target on current simulator runtime.
- Xcode result bundle retained on failure.
- Every testable control gets a stable `accessibilityIdentifier` independent of localized display text.

Release:

- Device Rust static library is rebuilt from source.
- Native Xcode archive/export is signed from CI-only secrets.

Rules:

- No screen-coordinate selectors.
- Avoid test-only production behavior; use launch arguments/environment only for deterministic backend fixtures when needed.
- Prefer accessibility identifiers, then roles/labels when identifiers are not appropriate.

## CI tiers

| Tier | Trigger | Purpose |
|---|---|---|
| Fast contract | every relevant PR | formatting, lint, host unit/contracts, architecture guard |
| Desktop matrix | relevant PR/main | Electron renderer/security/E2E/installer on macOS/Windows/Linux |
| Native simulator | relevant PR/main | Android Compose + iOS SwiftUI automated UI tests |
| Physical device | main / explicit | Android instrumentation on real hardware |
| Production package | validated CD | signed APK/AAB/IPA and store upload |
| Scheduled smoke | twice weekly | detect toolchain/OS/runtime drift even without code changes |

## Flakiness policy

A retry is never considered proof that a failed test is healthy. CI may retry once to collect diagnostic evidence, but teams must track and remove flaky tests. Repeated flakes should be quarantined only with an owner, issue, and expiration date; release-critical paths stay blocking.

## Test data and external services

- Unit/component tests should not require live production services.
- E2E tests should use controlled test accounts/environment contracts.
- Production secrets must never be available to pull requests from forks.
- Physical-device and store publication jobs use workload identity or repository secrets with the narrowest practical permissions.

## Evidence retained on failures

- Playwright trace/screenshot/video.
- Android Gradle reports, APKs, instrumentation results.
- iOS `.xcresult` bundle.
- Signed release artifacts plus `SHA256SUMS.txt`.

## Merge gate

A change is not release-ready until all applicable canonical-shell and shared-host gates pass. Retired WebView/legacy shell tests cannot substitute for Electron, Compose, or SwiftUI evidence.
