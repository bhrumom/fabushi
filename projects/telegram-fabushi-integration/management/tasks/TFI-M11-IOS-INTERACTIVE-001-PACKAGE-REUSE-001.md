# TFI-M11-IOS-INTERACTIVE-001-PACKAGE-REUSE-001 — existing iOS Simulator package reuse gate

- Project: `FAB-P0001 / TFI`
- Parent task: `TFI-M11-IOS-INTERACTIVE-001`
- Status: `TESTING`
- Branch: `fix/tfi-ios-reuse-package-e2e-20260906`
- Canonical base: `6872793daf727c118510e818e3cd689c09101594`
- Updated: 2026-09-06

## Objective

Permit the already-published, source-compatible iOS Simulator package from an exact prior GitHub Actions run to be reinstalled on a fresh runner-provided Simulator without rebuilding Rust/Xcode, while retaining the existing security boundary and the full evidence order:

`recording -> exact package -> install -> protected test-account login -> App-owned device registration -> @fabushi test simulated-user control -> always() evidence`.

This is an acceptance-harness task only. It does not claim that the product's dual authenticated UI or latest-UI feature gaps are fixed.

## Triggering live fact

Canonical main `6872793daf727c118510e818e3cd689c09101594` already has a compatible Simulator package from run `34030851007` / job `101479942005`:

- package artifact `9989009924`, `fabushi-ios-simulator-test-6872793daf727c118510e818e3cd689c09101594`;
- package digest `sha256:c423346e94a19406edff79e58a065de15155d562dffb01276777032261ec49e0`;
- always-upload evidence artifact `9989170643`, digest `sha256:955f6717391739d8bb5fcd64469ac661c1d94774cd5b7997a5ea1e2b933f34a2`;
- prior App-owned device `gha-34030851007-1-interactive`, now offline after isolated-Simulator teardown.

The origin run installed, authenticated, and registered the App successfully. It failed only because external semantic-control evidence did not complete before the bounded hold ended. The current `ios-interactive-app-e2e.yml` has `workflow_dispatch` but no artifact-origin input and therefore rebuilds Rust/Xcode on every manual dispatch, contrary to the repository warm-build/reuse rule when an exact compatible package already exists.

## Open-source-first decision

- Product navigation reference: `TelegramMessenger/Telegram-iOS`; learned only the single navigation-authority pattern. No source was copied because GitHub repository metadata did not expose a machine-readable license value in this audit and its README explicitly requires license compliance.
- CI artifact reuse: GitHub official `actions/download-artifact`; its action contract supports `github-token` + `run-id` for another workflow run and it is MIT licensed. Adopted directly as `actions/download-artifact@v8.0.1`; no custom artifact transport is introduced.

## Implementation

- `.github/workflows/ios-interactive-package-reuse-e2e.yml`
  - requires exact numeric `origin_run_id` and lowercase 40-character `package_source_sha`;
  - verifies origin run `head_sha` and repository;
  - resolves exactly one non-expired artifact named `fabushi-ios-simulator-test-<sha>`;
  - compares package source SHA to workflow SHA and fails if `mobile/ios/**`, `third_party/mahayana/mahayana-rs/**`, or `native/mahayana-messaging/**` changed;
  - starts Simulator recording before package download/extraction/install;
  - uses official cross-run artifact download with digest mismatch = error;
  - verifies package `SHA256SUMS.txt`, archive identity, and `CFBundleIdentifier=com.ombhrum.fabushi`;
  - performs exactly one install before protected test-account login;
  - launches with `SIMCTL_CHILD_GITHUB_SHA` bound to the **package source SHA**, not the workflow-only SHA;
  - preserves App-owned account-scoped registration and a bounded 600-second external-control window;
  - keeps video, screenshots, gateway trace, app/system logs, provenance JSON, and report on an `always()` path with 90-day retention;
  - performs no `cargo build`, `xcodebuild`, or `xcodegen`.
- `chatgpt-vps-control/tests/ios-interactive-package-reuse-e2e-contract.test.js` locks the above provenance/order/no-rebuild/no-runner-gateway contract.
- UI/function audit: `evidence/TFI-M11-IOS-INTERACTIVE-001/2026-09-06-unified-ui-gap-audit.md`.

## Acceptance

- [x] Existing matching package and origin run are proven from live GitHub.
- [x] App-owned prior device provenance is proven from live device inventory.
- [x] Open-source-first candidate/reuse/license decision recorded.
- [x] Package-reuse workflow and narrow regression contract implemented on the governed branch.
- [ ] Pull request current-head checks pass.
- [ ] Protected merge completes and canonical main is read back.
- [ ] Manual exact-main package-reuse run is dispatched with origin run `34030851007` + package SHA `6872793daf727c118510e818e3cd689c09101594` if product-compatibility comparison still passes.
- [ ] New App-owned iOS device becomes online and is controlled only through `@fabushi test`.
- [ ] Full-session video, step screenshots, gateway trace/report/log and precise PASS/FAIL evidence artifact are uploaded and linked.

## Failure policy

Fail closed on origin mismatch, missing/expired/multiple artifact, checksum mismatch, bundle mismatch, any package-affecting source delta, unavailable compatible Simulator, App-owned registration failure, or missing external semantic-control evidence. Do not fall back to an unbounded new build merely because package reuse fails; report the precise missing resource or source incompatibility and continue independent product/CI work.