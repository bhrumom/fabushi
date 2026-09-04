# TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001 — packaged/native evidence contract

- Project: `FAB-P0001 / TFI`
- Status: `FROZEN / NOT_STARTED`
- Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Parent boundary: `TFI-M6-MAINSAFE-001`; completed `OWNERSHIP-001` is not reopened. `MAINSAFE-002/003` remain stopped.

## Why this task exists

Current exact-main evidence is useful but does not satisfy the requested acceptance contract:

- Electron Playwright config records trace=`on`, video=`on`, but screenshots=`only-on-failure`.
- Electron main-push diagnostics are uploaded with `if: always()` and 90-day retention, which is the correct direction.
- Current Electron delivery manifest records version, exact SHA, run id/run number, and platform, but does not encode job, journey, or timestamp.
- Native Android and iOS report/xcresult artifacts are retained for 14 days, not the 90-day target.
- Existing artifact child names are not a deterministic exact-SHA/platform/run/job/journey/timestamp evidence namespace.
- A failed required step must still publish whatever report/log/trace/screenshot/video/xcresult evidence was produced; a missing artifact may not silently turn a failed journey into an unverifiable failure.

## Future execution allowlist

Evidence plumbing only:

- `.github/workflows/electron-desktop.yml`
- `.github/workflows/native-mobile.yml`
- `desktop/playwright.config.ts`
- a narrowly-scoped new evidence helper/manifest script under `.github/scripts/` or `desktop/e2e/` only if required to generate deterministic metadata/names; it may not implement product semantics.

No application/product source is allowed. If product behavior, Rust/Cargo/dependency, release versioning, or semantic test assertions are required, STOP and return to architecture.

## Required contract

1. **Always upload on pass/fail** for packaged/native journey diagnostics where a runner reached execution, with explicit step names and `if: always()`/equivalent failure-safe behavior.
2. **Meaningful-step screenshots**: successful journeys capture labelled screenshots at acceptance boundaries, not only on failure. Failure screenshots remain required.
3. **Complete video** for the dedicated packaged journey, plus Playwright trace and HTML/report output where applicable.
4. **Runtime/native logs**: Electron runtime/Host logs and native Android/iOS test logs/xcresult are preserved when produced.
5. **Manifest and naming** include exact source SHA, platform, workflow run id, job identity, journey id, UTC timestamp, and artifact format/version. Manifest data must be inside the artifact as well as useful in the artifact name where GitHub permits.
6. **Retention target 90 days** for acceptance evidence, subject to repository/org maximum; if the platform cap is lower, the job must fail or record the verified cap rather than silently claim 90 days.
7. **No evidence substitution**: reports/artifacts from another run, SHA, platform, or journey cannot satisfy the gate.

## Acceptance

- current-head workflow/config checks pass;
- a controlled passing packaged journey publishes the full evidence family and manifest;
- a controlled failing journey still publishes failure evidence with the same identity contract;
- native Android/iOS evidence uses the target retention and exact identity manifest/naming;
- independent code review passes exact head;
- protected main merge queue only, followed by canonical main readback;
- a fresh exact-main test-release session validates the contract from the new accepted SHA.

## Open-source-first references

- GitHub Actions cache / `actions/cache`: official implementation, MIT. Adopt key/match semantics and cache-vs-artifact separation; do not copy implementation code.
- GitHub `actions/upload-artifact`: official implementation, MIT. Adopt documented artifact/retention behavior; do not copy implementation code.
- Playwright: official Microsoft project, Apache-2.0. Adopt trace/video/screenshot/test-step attachment concepts; implement repository-specific evidence naming rather than copying upstream code.
- Apple XCTest/XCUI: use Apple XCTest activities/attachments as the iOS evidence model; Swift open-source XCTest is Apache-2.0 with runtime-library exception. Adopt concepts only; no upstream code copied.
