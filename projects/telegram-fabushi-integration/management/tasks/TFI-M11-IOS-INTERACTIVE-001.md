# TFI-M11-IOS-INTERACTIVE-001 — iOS packaged interactive release-test loop

- Project: `FAB-P0001 / TFI`
- Status: `PASS`
- Platform: iOS Simulator packaged test build
- Updated: 2026-09-05

## Product truth

The GitHub Actions macOS runner is only the host. The exact packaged Fabushi iOS test app must be installed and authenticated first; the launched app itself must register its account-scoped device gateway. Only then may `@fabushi test` discover and control the newly registered app. KRIS, pre-online runners, `interactive-runner`, standalone runner-owned device agents, and runner-owned device registration are not valid device sources.

## Closed atomic blocker

The preceding canonical iOS packaged E2E failed in `mobile/ios/Fabushi/ContentView.swift` because `appAgentSurfaceFingerprint` used one monolithic 51-value String expression list and Swift 6 / Xcode 16.4 timed out during type inference before install/login/App registration. Failure evidence is retained as artifact `9971188137`.

PR #2376 split the fingerprint into three explicitly typed `[String]` chunks while preserving all 51 values, exact order, and final `|` join semantics. The narrow regression contract locks those invariants and prevents restoration of the monolithic literal.

## Accepted canonical provenance

- Product PR: `#2376` — `fix(tfi): split iOS fingerprint type inference`.
- Protected merge SHA / canonical tested `main`: `50818ecdc6c222f2e0d0de6000b580d714888413`.
- Canonical post-main workflow run: `33973551821`, attempt `1`, conclusion `success`.
- Run-scoped App-owned device: `gha-33973551821-1-interactive`.
- Comparable Simulator test artifact: `9971856295` — `fabushi-ios-simulator-test-50818ecdc6c222f2e0d0de6000b580d714888413`.
- Comparable artifact digest: `sha256:45528c7f1d0fc54a697d92e3dbe28e81cc3998cab6e6a35c2110331650fdc062`.
- Packaged app archive digest from `SHA256SUMS.txt`: `sha256:1ab7a5d092210e175e83bea87905d278f711aa76018adc65225b361d94e6ca00`.
- Packaged app identity: bundle `com.ombhrum.fabushi`, `CFBundleShortVersionString=1.2.22`, `CFBundleVersion=29`.
- Complete PASS evidence artifact: `9971876450` — `fabushi-ios-interactive-evidence-33973551821-1`.
- Evidence artifact digest: `sha256:740fb4e2c6e7ce0cfc4cfc181d45adcdb9cb0e9ee31284605381bc052f47afe3`.

## Verification gates

- [x] Narrow Actions contract exercised the explicit-typing/order invariant successfully before the product commit was published.
- [x] Final PR head lightweight checks passed.
- [x] Product PR merged through the repository protected-main merge queue.
- [x] Canonical post-merge iOS packaged run was bound to accepted `main@50818ecdc6c222f2e0d0de6000b580d714888413` and published the comparable Simulator test artifact before interaction.
- [x] Xcode 16.4 `build-for-testing` passed, proving the original Swift 6 fingerprint type-inference blocker is closed in a real product build.
- [x] Fast native contract tests passed with `FabushiContracts.xcresult` retained in evidence.
- [x] Full-session recording started immediately after Simulator boot and before install; exact build install preceded protected-account login.
- [x] The installed authenticated iOS App registered its own gateway; no runner-side Fabushi device agent was started.
- [x] `@fabushi test` selected only `gha-33973551821-1-interactive`; older iOS sessions were offline and not used.
- [x] App trace contains successful `call-completed` records for all six required semantic tools: `fabushi.app.status`, `fabushi.app.snapshot`, `fabushi.app.find`, `fabushi.app.action`, `fabushi.app.wait`, and `fabushi.app.assert`.
- [x] `report.json` records `controlStatus: passed` and all six tools in `completedTools`; the final semantic-control evidence gate passed.
- [x] PASS evidence retains the full session video, step screenshots, gateway/device-call trace, `xcresult`, Xcode/app/Simulator logs and reports, source identity, exact test-build archive, and artifact digests.

## Evidence interpretation

The accepted App trace records App-owned registration at 2026-09-05T15:17:59Z, followed by successful external semantic tool completions from 15:18:22Z through 15:18:50Z. The workflow then collected evidence, uploaded it via the unconditional evidence path, deleted the isolated Simulator, and passed the final external semantic-control enforcement step. The run-scoped device correctly became offline after Simulator teardown.

## Failure policy

Any later independent product defect must be fixed in one new atomic PR, protected-merged, followed by a strictly newer comparable packaged test version and a retest of that newest version. A failed/partial/skipped E2E must remain `IN_PROGRESS`/blocked and must not be represented as release acceptance.
