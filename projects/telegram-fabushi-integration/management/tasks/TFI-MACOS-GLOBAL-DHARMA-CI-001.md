# TFI-MACOS-GLOBAL-DHARMA-CI-001

- Project: `FAB-P0001 / TFI`
- Stage: `M8 Mini Apps + M9 Payment / macOS acceptance`
- Status: `IN_PROGRESS`
- Owner: macOS engineering loop
- Discovery baseline: protected `main@a19e17b5b15ecff5f4a408d58f8e72edae33fd47`
- Branch: `fix/tfi-macos-global-dharma-ci-fallback-20260907`
- Evidence index: `../../evidence/TFI-MACOS-GLOBAL-DHARMA-CI-001/README.md`

## Source requirement

For macOS, continue the same Global Dharma user goal without making live `@fabushi test` / device-plugin control a hard prerequisite. A repeatable CI simulated-user journey must prove Marketplace search/install of `全球法布施`, Bot projection, natural-language WebMCP execution, Telegram-like `打开应用` Web UI, shared Bot/Web UI revision, bounded Fabushi account login, CNY 1080 lifetime local-prayer-wheel purchase/restore, server entitlement, restart durability, logout cleanup, screenshots, video, trace, logs, report, exact commit/PR/merge/run/Release evidence. Heavy build/test stays in GitHub Actions.

## Discovery facts

1. Canonical `main` is `a19e17b5b15ecff5f4a408d58f8e72edae33fd47` (`#2475`).
2. Exact-main Electron desktop quality gate `34065675136` passed; the canonical workflow already runs packaged macOS E2E.
3. Exact-main Global Dharma Web Service Contract `34067404186` passed, including the service-side commerce/entitlement contract.
4. Release `desktop-1.2.53-a19e17b5b15e` is bound to the same exact source SHA.
5. macOS interactive run `34067125800` successfully downloaded/installed the exact release, authenticated the protected Fabushi test account, launched the App, and reached App-owned registration. It then entered step `Hold for @fabushi test complete macOS journey`, which can wait 1500 seconds for external plugin notes/device-call trace before the Playwright evidence step.
6. Existing `desktop/e2e/miniapp-bot-parity.spec.ts` already covers the requested Global Dharma packaged user journey, including two explicit screencast segments and named screenshots `01` through `12`.
7. Desktop entitlement reads cross the authenticated Host boundary through `platform.request('GET', /v1/plugins/.../entitlements/...)`; test payment mode avoids real money but must not bypass entitlement verification.

## Real gap

There is no macOS-specific, fail-closed CI gate that runs only the existing Global Dharma packaged journey against the exact published macOS Release while remaining independent of the external device plugin. The current interactive workflow therefore makes an optional evidence channel look like a release acceptance prerequisite.

## Open-source-first check

- Searched public GitHub for GitHub Actions / Playwright patterns that keep external E2E channels non-blocking while retaining a CI-native required path.
- Found examples that use non-blocking optional E2E (`continue-on-error`) for supplemental environments.
- No external code is copied. The selected implementation reuses Fabushi's existing exact-SHA release resolver, `actions/setup-node` npm cache, Playwright config, packaged executable injection, and existing Global Dharma spec.

## Atomic implementation

- Add `.github/workflows/macos-global-dharma-packaged-e2e.yml`.
- PR path: run a dependency-free workflow contract only.
- Canonical-main path: start whole-session recording, reuse npm cache, wait for the published macOS asset bound to the exact `GITHUB_SHA`, install/verify that asset, run only `e2e/miniapp-bot-parity.spec.ts`, upload `playwright-report`, `test-results`, release metadata and whole-session recording, then fail closed unless the expected screenshots/videos/trace/report are present.
- The new required CI path must contain no `@fabushi test`, `ci_session_*`, App-owned device, or remote-control prerequisite.
- Keep the existing interactive/device workflow available as supplemental evidence; do not delete real-device capability.

## Acceptance

- [ ] PR contract check proves the new workflow is plugin-independent, exact-SHA-bound, and invokes only the Global Dharma packaged spec.
- [ ] Required PR checks are green and PR merges through protected `main`.
- [ ] Canonical `main` is re-read at the merge SHA.
- [ ] A strictly newer desktop test Release is published from that SHA.
- [ ] The new macOS packaged workflow runs against that exact Release and passes.
- [ ] Evidence contains `01`-`12` screenshots, `global-dharma-user-journey.webm`, `global-dharma-user-journey-restart-logout.webm`, Playwright `trace.zip`, Playwright HTML report, whole-session macOS recording, release digest/metadata, and run report.
- [ ] Journey proves search/install -> Bot -> natural language WebMCP -> open-app same revision -> bounded Fabushi session -> CNY 1080 lifetime purchase -> restore -> entitlement allowed -> Bot starts entitled local prayer wheel -> restart recovery -> logout cleanup.
- [ ] Exact-main Global Dharma Web Service Contract is success for the same source SHA (or a newer exact-main service contract run is recorded).

## Current blocker

None for implementation. Existing interactive run `34067125800` remains supplemental and may time out if no plugin takes control; that outcome must not be used to block this CI-native task.

## Next action

Implement the workflow + contract, open one atomic PR, use the narrow PR contract for fast feedback, protect-merge, then verify the newest exact-main Release and macOS packaged evidence before closing this task.

## Execution update — 2026-09-07 macOS fast loop

- Acceptance-path PR: `#2477`, final head `be7d3c775343ed26b7794317c9709e787f697a89`.
- First focused contract run `34068461161`, job `101581303378`: FAILED only because the new asset-pattern contract over-escaped the workflow regex; the macOS packaged job was skipped, so no heavy runner was wasted.
- Minimal contract-only repair commit: `be7d3c775343ed26b7794317c9709e787f697a89`.
- Second focused contract run `34068511467`, job `101581446787`: plugin-independence/exact-release/evidence contract PASS.
- Protected merge: `#2477` -> `main@694218dc9a427670fec610e458223646d2d4c461`; canonical main was re-read after merge.
- Next governed macOS test SemVer: `1.2.54`, strictly newer than `1.2.53`; Android `versionCode=29` and iOS `CURRENT_PROJECT_VERSION=29` remain unchanged because this is a shared SemVer-only retest round.
- 1.2.54 release PR/run/tag/asset plus release-triggered macOS Global Dharma packaged journey/video/screenshots/trace/report are `PENDING` until actually generated.
