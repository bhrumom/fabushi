# TFI-M11-IOS-INTERACTIVE-001 — iOS packaged interactive release-test loop

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Platform: iOS Simulator packaged test build
- Updated: 2026-09-05

## Product truth

The GitHub Actions macOS runner is only the host. The exact packaged Fabushi iOS test app must be installed and authenticated first; the launched app itself must register its account-scoped device gateway. Only then may `@fabushi test` discover and control the newly registered app. KRIS, pre-online runners, `interactive-runner`, standalone runner-owned device agents, and runner-owned device registration are not valid device sources.

## Current atomic blocker

Canonical iOS packaged E2E reached the Xcode build and failed because `mobile/ios/Fabushi/ContentView.swift` built `appAgentSurfaceFingerprint` from one monolithic 51-value heterogeneous-looking String expression list, causing Swift 6 / Xcode 16.4 type inference to time out before install/login/App registration. Failure evidence locator: artifact `9971188137` from the preceding canonical run.

## Atomic fix contract

1. Preserve all 51 fingerprint values and their exact order and final `|` join semantics.
2. Split the values into small explicitly typed `[String]` chunks and concatenate those typed chunks.
3. Add a narrow regression contract that asserts exactly 51 values, identical order, explicit `[String]` chunk typing, ordered concatenation, and absence of the original monolithic return literal.
4. Do not weaken product assertions or change App Surface semantics.
5. Keep this fix isolated from macOS/release work already merged on `main`.

## Verification gates

- [x] Narrow Actions contract exercised the explicit-typing/order invariant successfully before the product commit was published.
- [ ] Final PR head lightweight checks pass.
- [ ] Product PR merges through the repository protected-main path.
- [ ] A post-merge canonical iOS packaged run is bound to the accepted `main` SHA and publishes the comparable Simulator test build before interaction.
- [ ] Full-session recording starts before install; exact build install precedes protected-account login; the installed authenticated App registers its own gateway.
- [ ] `@fabushi test` selects only the newly registered run-scoped iOS device and successfully exercises the required six `fabushi.app.*` semantic tools.
- [ ] PASS or FAIL evidence is retained via `always()`: full video, step screenshots, device-call/gateway trace, `xcresult`, app/Simulator/build logs and reports, source/release metadata, artifact identity/digest.

## Current implementation provenance

- Implementation commit: `2256c53f9c91ae2b76e1c3ae03606a9415d46af0` (`fix(tfi): split iOS fingerprint type inference`).
- The branch is aligned without history rewrite to the current canonical-main lineage before PR creation.
- Post-main E2E run/device/artifact identifiers remain intentionally pending until protected merge completes.

## Failure policy

Any later independent product defect must be fixed in one new atomic PR, protected-merged, followed by a strictly newer comparable packaged test version and a retest of that newest version. A failed/partial/skipped E2E must remain `IN_PROGRESS`/blocked and must not be represented as release acceptance.
