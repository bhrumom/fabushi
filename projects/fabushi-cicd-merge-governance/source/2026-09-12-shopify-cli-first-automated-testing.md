# 2026-09-12 — Shopify-style CLI-first automated testing

Project: `FAB-P0003 / FCM`
Task: `FCM-010.9`
Intake: `[Fabushi:dc7a68a4-8194-41dd-bc00-aa6074cf0323]`

## User requirement

Continue improving Fabushi automated testing following the supplied WeChat article, aiming for Shopify-like fast automated test/iteration loops with GitHub Actions. Preserve the architectural direction that product/business logic lives in Mahayana CLI/runtime while desktop/mobile presentation layers are thin UI projections. Core behavior and UI verification must be decoupled so most changes can be proven without booting a simulator or packaged UI, while real UI journeys remain independently testable.

Supplied article: `https://mp.weixin.qq.com/s/DEg20nFKfrd2urMc3BjntA`.

## Upstream / open-source-first research

The WeChat page is not reliably fetchable from CI/research tooling, so the implementation is grounded in the corresponding public Shopify engineering principles rather than inferred private page text.

1. Shopify Engineering, **Native is now the future of mobile at Shopify** (2026-09-10): `https://shopify.engineering/back-to-native`
   - Business logic should be completely decoupled from UI and runnable headlessly on desktop.
   - Agents receive that logic through a CLI so iteration happens without simulators.
   - When a simulator is necessary, the CLI can connect remotely and drive commands without relying on layout/accessibility-tree inspection.
2. Shopify Engineering, **Keeping Developers Happy with a Fast CI** (2021-02-24): `https://shopify.engineering/faster-shopify-ci`
   - Measure CI latency before/while optimizing it.
   - The fastest work is work CI can safely avoid; select affected tests and reuse dependency/build state.
   - Concentrate optimization effort on the slowest portion of the suite.

## Current Fabushi architecture readback

- `.github/workflows/ci.yml` is already a lightweight required contract gate with a 3-minute job timeout.
- `.github/workflows/mahayana-fast-checks.yml` already uses path selection, sparse checkout, concurrency cancellation, Cargo incremental compilation and `Swatinem/rust-cache`.
- The Mahayana workspace already contains `mahayana-cli` and `mahayana-test-driver-protocol`, but the fast workflow previously tested many downstream/runtime crates without directly making these two CLI/test-driver surfaces first-class gates.
- Packaged desktop/mobile workflows already expose stable semantic App tools. macOS currently still includes an external-control hold of up to 1500 seconds after App-owned registration, so comprehensive UI acceptance remains much slower than headless/core validation.

## Decision

Adopt a two-layer feedback model without weakening release evidence:

1. **PR/core fast layer:** direct Mahayana CLI + deterministic test-driver protocol tests run first, backed by path filtering, sparse checkout and warm Cargo state. A lightweight required-CI contract prevents accidental removal of this layer.
2. **UI/package layer:** keep semantic App-agent and packaged E2E validation independent. Do not move business assertions back into Playwright/accessibility/coordinate tests merely to increase UI coverage.
3. **Next optimization:** make packaged App semantic journeys self-driving from GitHub Actions through the existing private loopback App Agent bridge, while preserving exact-main package identity, login/security boundaries, screenshots/video/trace/log evidence and the existing full-journey acceptance contract.

## Non-goals for this atomic change

- Do not remove or downgrade exact-main packaged E2E or release gates.
- Do not make a cache hit count as correctness evidence.
- Do not replace semantic controls with coordinate/screenshot automation.
- Do not claim the 1500-second external-control hold is solved until a self-driving Action journey is implemented and proven on canonical main.
