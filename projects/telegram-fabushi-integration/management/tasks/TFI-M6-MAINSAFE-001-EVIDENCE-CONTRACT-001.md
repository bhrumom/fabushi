# TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001 — packaged/native evidence contract

- Project: `FAB-P0001 / TFI`
- Status: `FROZEN / READY_FOR_EXECUTION_HANDOFF`
- Requirement ID: `M6-PM-EVC-R01`
- Acceptance ID: `M6-PM-EVC-A01`
- Accepted product baseline: `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`
- Parent boundary: `TFI-M6-MAINSAFE-001`; no application/product semantics are part of this task.

## M6-PM-EVC-R01 — requirement

Make packaged Electron and Native Android/iOS acceptance evidence deterministic and non-substitutable: pass and fail paths must upload the evidence produced by the run, identities must bind evidence to exact source/run/job/platform/journey, and acceptance artifacts should be retained for 90 days wherever repository/org/platform limits permit.

## Accepted-main evidence gap

- Electron packaged run `33939200878` succeeds and the repository already uses Playwright trace/video/HTML-report primitives plus an `always()` diagnostics upload with 90-day retention.
- Native run `33939200888` fails only on iOS; Android job is successful. The accepted-main workflow uploads Native reports/xcresult with `if: always()` but explicitly uses `retention-days: 14`.
- iOS artifact `9961442374` (`ios-native-xcresult`) is therefore scheduled to expire `2026-09-19T02:43:45Z`, demonstrating a real retention-contract gap even though failure evidence itself was preserved.
- current evidence identity is not uniformly bound to exact main SHA + run + job + platform + journey/test ID inside a manifest and artifact namespace.

This task file already existed on #2340 and is reused. Its exact path is still 404 on accepted `main@63e49b87...`; that is a records-delivery topology gap, not the evidence-runtime defect itself.

## Inputs / dependencies

- implementation starts from freshly re-read canonical main (currently `63e49b87...`);
- Architecture contract is the latest #2340 head;
- repository-native Electron Playwright and Native GitHub Actions evidence pipeline is authoritative;
- implementation may execute in parallel with `IOS-FIXTURE-001`;
- `EVIDENCE-JOURNEY-001` may author its journey in parallel, but its acceptance cannot close before this contract has passed protected-main + canonical-readback.

## Exact implementation allowlist

Evidence plumbing only:

- `.github/workflows/electron-desktop.yml`
- `.github/workflows/native-mobile.yml`
- `desktop/playwright.config.ts`
- one narrowly scoped evidence-only helper/manifest file under `.github/scripts/` or `desktop/e2e/` only if required for deterministic metadata/naming; it may not implement product semantics.
- task-specific records under `projects/telegram-fabushi-integration/**`.

## Forbidden files / actions

- all application/product source, Rust core, iOS/Android product source;
- semantic test assertion rewrites or product journey weakening;
- Cargo/dependency/lockfile changes or introducing a parallel evidence service/test framework;
- version/release-number logic, `app-version.json`, `mobile/ios/project.yml`;
- unrelated workflows, rulesets/branch-protection, root governance files;
- evidence copied from another run/SHA/platform/journey as substitute.

Any need outside the allowlist fails closed to Architecture.

## Required evidence contract

1. **Always-path upload:** where the runner reached execution, screenshot/video/trace/HTML-or-native-report/runtime logs/xcresult that were produced are uploaded on both success and failure using `if: always()` or equivalent failure-safe behavior.
2. **Screenshots:** dedicated acceptance journeys capture labelled screenshots at meaningful acceptance boundaries on success; failure screenshots remain required.
3. **Complete video + trace/report:** packaged owned journey preserves complete video, Playwright trace and HTML/report output. Native preserves Android reports/logs and iOS xcresult/raw logs when produced.
4. **Identity manifest:** each acceptance artifact contains a manifest with exact source SHA, packaged app identity/version where applicable, platform/OS, workflow name, run id/run number, job id/name, stable journey/test ID, UTC timestamp, artifact format/version and final result. Artifact names should carry as much of the same namespace as GitHub permits.
5. **No substitution:** evidence whose SHA/run/job/platform/journey identity does not match the acceptance record cannot satisfy the gate.
6. **Retention:** target `90` days. If repository/org/platform maximum prevents 90, execution must record the verified limit and explicit exception in task evidence; it may not silently claim 90. A configured 14-day value when 90 is allowed is noncompliant.
7. **Fail closed:** missing required evidence/manifest identity fails the acceptance even if a functional test is green.

## Open-source-first decision

Reuse repository-native mature components: `actions/upload-artifact` (official GitHub, MIT) for artifact upload/retention; Microsoft Playwright (Apache-2.0) for trace/video/screenshot/HTML-report; Swift XCTest reference (`swiftlang/swift-corelibs-xctest`, Apache-2.0) plus platform XCTest/XCUITest for native result bundles. No upstream implementation code is copied and no new third-party dependency/service is introduced.

## M6-PM-EVC-A01 — acceptance / gates

1. Final execution diff is allowlist-only and current-head CI/config validation passes.
2. A controlled passing packaged journey produces the complete evidence family + identity manifest.
3. A controlled failing journey still publishes the available failure evidence with the same identity contract.
4. Android/iOS success/failure paths preserve reports/logs/xcresult and use 90-day retention where permitted; any lower enforced maximum is explicitly evidenced.
5. Independent Code Review approves the exact final head and verifies no product semantics or assertion weakening entered this task.
6. Protected `merge_group` required gates pass; then canonical main is re-read and proves the reviewed evidence contract landed.
7. Only the new accepted SHA may be used by later test release. Manual/rerun/historical/different-SHA artifacts are not substitutes.
8. Any missing always-path artifact, identity manifest, exact-SHA binding, retention truth, or scope violation fails closed.
