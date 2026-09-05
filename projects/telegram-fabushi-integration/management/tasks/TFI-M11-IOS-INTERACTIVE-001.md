# TFI-M11-IOS-INTERACTIVE-001 — iOS packaged interactive release-test loop

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Platform: iOS Simulator packaged test build
- Updated: 2026-09-05

## Product truth

The GitHub Actions macOS runner is only the host. The exact packaged Fabushi iOS test app must be installed and authenticated first; the launched app itself must register its account-scoped device gateway. Only then may `@fabushi test` discover and control the newly registered app. KRIS, pre-online runners, `interactive-runner`, standalone runner-owned device agents, and runner-owned device registration are not valid device sources.

Release acceptance requires the full declared iOS semantic journey matrix to be exercised against that newly registered packaged App-owned device. Completion of the six stable `fabushi.app.*` tool names is a prerequisite/smoke gate, not by itself full feature-matrix acceptance.

## Closed compile blocker

The earlier canonical iOS packaged E2E failed in `mobile/ios/Fabushi/ContentView.swift` because `appAgentSurfaceFingerprint` used one monolithic 51-value String expression list and Swift 6 / Xcode 16.4 timed out during type inference before install/login/App registration. Failure evidence is retained as artifact `9971188137`.

PR #2376 split the fingerprint into three explicitly typed `[String]` chunks while preserving all 51 values, exact order, and final `|` join semantics. The narrow regression contract locks those invariants and prevents restoration of the monolithic literal.

## Canonical run 14 — compile/package path verified, release acceptance still open

- Product PR: `#2376` — `fix(tfi): split iOS fingerprint type inference`.
- Protected merge SHA tested by the run: `50818ecdc6c222f2e0d0de6000b580d714888413`.
- Canonical post-main workflow run: `33973551821`, attempt `1`, GitHub conclusion `success`.
- Run-scoped App-owned device: `gha-33973551821-1-interactive`.
- Comparable Simulator test artifact: `9971856295` — `fabushi-ios-simulator-test-50818ecdc6c222f2e0d0de6000b580d714888413`.
- Comparable artifact digest: `sha256:45528c7f1d0fc54a697d92e3dbe28e81cc3998cab6e6a35c2110331650fdc062`.
- Complete always() evidence artifact: `9971876450` — `fabushi-ios-interactive-evidence-33973551821-1`.
- Evidence artifact digest: `sha256:740fb4e2c6e7ce0cfc4cfc181d45adcdb9cb0e9ee31284605381bc052f47afe3`.

Run 14 proved all of the following without a local heavy build/test:

- Xcode 16.4 `build-for-testing` passed the former Swift type-inference failure point.
- Fast native contract tests passed and `FabushiContracts.xcresult` entered the always() evidence path.
- Full-session recording began after Simulator boot and before build/install/login.
- The exact comparable Simulator build was uploaded before interaction and then installed exactly once.
- Protected-account login occurred only after install; only the bounded refresh-token-free app session was injected.
- The installed authenticated iOS App registered its own account-scoped gateway.
- External control selected only `gha-33973551821-1-interactive`, whose metadata bound it to run `33973551821`, attempt `1`, source SHA `50818ecdc6c222f2e0d0de6000b580d714888413`, and kind `github-actions-ios-app`.
- No KRIS, pre-existing/interactive runner device, standalone runner-owned Fabushi device agent, or runner-owned device registration was used.
- `@fabushi test` successfully exercised all six stable tools: `fabushi.app.status`, `fabushi.app.snapshot`, `fabushi.app.find`, `fabushi.app.action`, `fabushi.app.wait`, and `fabushi.app.assert`.
- External navigation reached the legacy `home` semantic surface and successfully invoked `home-sync`.

## Run-14 acceptance defect

The workflow's live-control loop treated the first successful completion of all six semantic tool names as terminal success and immediately exited. The unconditional collection/upload/Simulator-deletion steps then ran, so the newly registered device became offline before the full declared iOS feature matrix could be exercised.

PR #2377 (`docs(tfi): record canonical iOS interactive pass`) subsequently changed this task to `PASS` using the six-tool smoke result. That docs-only conclusion is narrower than the requested release acceptance and is corrected here: run 14 remains valuable compile/package/App-registration evidence, but it is **not** full-matrix release acceptance.

## Current atomic defect — keep the App-owned device live for the full matrix

Branch: `fix/tfi-ios-full-matrix-hold-20260905`, based on live canonical `main@5415e34a492462ca98c69c5593e442b863076f0b` after PR #2377.

Atomic contract:

1. Keep all six existing semantic-tool prerequisite checks unchanged.
2. Do not terminate the live-control step immediately when those six tools first pass.
3. Mark that prerequisite passed once, but retain the same installed/authenticated/App-owned device for a bounded 600-second external matrix window.
4. At the end of the bounded hold, pass only if the six-tool prerequisite was actually observed; otherwise fail closed as before.
5. Add a narrow regression contract that locks the 600-second hold and forbids restoring the early `exit 0` on first six-tool completion.
6. Do not weaken product assertions, alter App Surface semantics, introduce runner-owned registration, or use a local heavy build/test.
7. After protected merge, only a strictly newer canonical main SHA and its newly published comparable Simulator test artifact may be used for the next full-matrix retest.

## Declared iOS feature-matrix acceptance

The newest packaged App-owned device must be exercised through live semantic IDs/generations across the declared native journey surfaces and real business bindings, including where data/state makes the action reachable:

- Grok authenticated home and transition into the full messaging workspace.
- Home refresh/sync, search, profile menu, compose menu, and Mahayana agent entry.
- Home, chat, agent-chat, profile-menu, compose-menu, forward-message, poll-compose, contact-share, location-share, and media-viewer semantic surfaces.
- Conversation pin, mute, unread, and archive state actions.
- Chat draft/send and message reply, forward, react, edit, pin, and delete actions.
- File, location, contact, and poll attachment/composer paths, including poll voting when a test poll is available.
- Mahayana draft/send/stop path where reachable.
- Compose participant selection and create path where test-account data permits it.
- Mobile logout only after all earlier authenticated journeys are complete.
- Calls/payments/settings must remain truthfully represented as unavailable rather than fabricated if they are still not native.
- All semantic mutations must use the exact current generation; stale-generation behavior remains fail closed.

## Verification gates

- [x] Fingerprint explicit-typing/order regression contract passed before PR #2376 merge.
- [x] PR #2376 passed required checks and protected merge.
- [x] Run 14 proved the former Xcode compile blocker closed on a real canonical packaged build.
- [x] Run 14 proved recording-before-install, exact package publication/install, protected login, App-owned gateway registration, six semantic tools, xcresult, and always() evidence retention.
- [x] Run 14 full-matrix incompleteness was detected from the live external test before accepting the repository's docs-only PASS record.
- [ ] Full-matrix live-hold defect PR passes its narrow regression/required checks.
- [ ] Full-matrix live-hold defect PR merges through the protected-main path.
- [ ] A strictly newer canonical main SHA publishes a strictly newer comparable Simulator artifact before interaction.
- [ ] The newly installed/authenticated App registers a new run-scoped iOS device and only that device is selected by `@fabushi test`.
- [ ] The full declared iOS feature matrix completes during the bounded live window without weakened assertions.
- [ ] PASS or FAIL evidence retains full video, step screenshots, gateway/device-call trace, `xcresult`, app/Simulator/build logs and reports, exact source/release metadata, artifact IDs, and digests via `always()`.

## Failure policy

Any later independent product or acceptance-harness defect follows the same loop: one new atomic PR, protected merge, a strictly newer comparable packaged test version, then retest only that newest version. A failed, partial, skipped, or smoke-only E2E remains `IN_PROGRESS`/blocked and must not be represented as release acceptance.
