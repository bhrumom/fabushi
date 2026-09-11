# ADR — CLI-first fast feedback without conflating evidence

Project: FAB-P0003 / FCM. Task: FCM-FAST-20260911. Status: proposed/implemented on task branch; not canonical acceptance.

## Inspected sources and reuse

- Existing `.github/workflows/mahayana-fast-checks.yml`: reuse the actual Cargo package names, production Host boundary test, Linux dependencies and Rust cache pattern. The product client's package is `mahayana-platform-client`, not its dependency alias `mahayana-product`.
- Existing `.github/workflows/mahayana-ios-test-driver-contract.yml` and `mahayana-cli/src/bin/mahayana-test-driver.rs`: reuse the Debug-only real product JSONL protocol. Do not ship the test driver in release binaries.
- Existing `desktop/src/main.tsx`, `messaging-shell-v2.tsx`, `app-agent-surface.ts`, shared `dom-agent-surface.ts`, and packaged `app-agent-surface.spec.ts`: reuse the real renderer and generation-safe semantic API. Ordinary browser transport is an existing in-memory UI fixture; label it presentation-only.
- Playwright official dev-server documentation: https://playwright.dev/docs/test-webserver — supports running a development renderer under headless browser tests without packaging Electron. Reuse the repository-pinned Playwright/Vite versions and ordinary test/webServer API; do not introduce a new component-testing framework or assume newer APIs are compatible.
- Playwright primary license: https://github.com/microsoft/playwright/blob/main/LICENSE — Apache-2.0. No upstream source copied; use the dependency already in the repository.
- GitHub official merge-queue documentation: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue — include merge_group and preserve queue-owned final merge.

## Decision

A small Python standard-library controller adapts existing Cargo and Playwright commands. It is a test control plane, not a second product runtime. Separate contract, core and UI jobs run on exact source SHAs. Core covers named shared production packages and a real Debug CLI lifecycle. UI runs the actual Vite renderer with fixture transport and cannot satisfy backend or native acceptance. Required native/package/release workflows remain authoritative and are not removed or weakened.

No new test endpoint is exposed publicly. Headless tests invoke the already-installed DOM semantic surface in an isolated browser. Packaged and remote transport/auth/device-ownership correctness remain separate tests.

All selected suites must execute with nonzero test proof; missing/empty/unknown selection, setup failure, timeout, truncated evidence, dirty tracked source or mismatched SHA cannot pass. Logs are bounded and common secret patterns redacted; credential-named environment variables are not inherited by fast suites. Reports distinguish selected-suite success from incomplete full-product acceptance.

A repair request is structured evidence, not proof an AI repair executed. Automatic executor integration and cross-run attempt persistence remain separate acceptance tasks; current requests explicitly say `automatic_fix_executed: false`. No permission/gate/assertion relaxation is allowed.

## Rejected shortcuts

- Duplicating product behavior in a mock and claiming functional acceptance.
- Treating browser viewport emulation as SwiftUI/Android/package validation.
- Rebuilding/signing every App for a renderer-only inner loop.
- Replacing established Cargo/Playwright/semantic infrastructure with a new testing engine.
- Blind merging of historical PR stacks, automatic real purchases, or promoting untested artifacts.

## Known limits

The linked WeChat article could not be read. No claim of article parity is made. This first registry is a named subset, not proof that every product feature is covered. Exact-main native/package acceptance, web-Wasm/extension-specific coverage, complete autonomous repair integration and measured cold/warm latency remain pending.
