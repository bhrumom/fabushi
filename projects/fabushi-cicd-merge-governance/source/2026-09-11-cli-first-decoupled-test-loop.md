# 2026-09-11 CLI-first decoupled test and repair loop

Project: FAB-P0003 / FCM. Workstream: FCM-FAST-20260911.
Source: explicit user request in ChatGPT, reaffirmed by "continue completing all".
Reference article: https://mp.weixin.qq.com/s/DEg20nFKfrd2urMc3BjntA

## Requested outcome

Implement a rapid full-platform automated development and testing system. Mahayana CLI/shared runtime owns product logic; Electron, web/extension, iOS and Android are presentation and platform adapters. Separate functional coverage from UI coverage. Test shared production logic without launching a GUI. Reuse remote semantic UI commands and test real web-renderer presentation headlessly without packaging the whole App each iteration. Feed objective failures into bounded AI repair iterations with minimal developer intervention. Put executable instructions in AGENTS.md and project runbooks. Use the system against current product surfaces, reconcile open PRs through protected integration, and publish a verified strictly newer test version.

## Limits that must remain explicit

- A browser rendering test does not validate SwiftUI/Android native UI, native permissions, packaging, installation or signing.
- Changed compiled Rust/native code needs compilation. Compatible immutable build outputs may be reused; do not claim universal zero-compilation.
- Missing coverage, skipped suites, missing devices, unavailable credentials and absent evidence are not passes.
- Application builds and heavy tests run in GitHub-hosted Actions, not the user's computer or this working container.
- Preserve required review/checks/merge queue and exact-main packaged acceptance before release. Superseded or conflicting historical PRs must be reconciled, not blindly merged.
- No real purchases, exported credentials, permission bypass, assertion weakening or unbounded repair loops.

## Verified starting point

Canonical main and existing work branch were read back at e2d4eda0c449e461771b855aaeee416062512f09. The previous branch creation succeeded, but the previously attempted requirement file did not exist on readback; no prior implementation is claimed.

The reference article could not be opened by the available web reader; exact article contents and parity remain unverified. Public container networking also failed DNS resolution. Work is based on the user's explicit requirements plus readable primary upstream and repository sources, not on invented article details.

Existing reusable surfaces include the mahayana.test-driver.v1 JSONL protocol and desktop Playwright/Vite tooling. Their exact implementation and evidence must be inspected before use.

## Acceptance

- FCM-FAST-A01: executable fail-closed test selection/results, identifying exact revision, layer, status and reproduction command.
- FCM-FAST-A02: production Mahayana/domain tests independent of browser/UI tests; fixtures never represented as production acceptance.
- FCM-FAST-A03: headless real-renderer presentation tests and a separately visible native/package acceptance matrix.
- FCM-FAST-A04: bounded repair handoff retaining original failure and regression evidence; no silent weakening or secret exposure.
- FCM-FAST-A05: protected integration, canonical-main readback and strictly newer test release after required gates.
- FCM-FAST-A06: executable AGENTS instructions, runbook and synchronized task/WBS/acceptance/status/changelog/evidence.

Status: in-progress. Article parity, implementation, CI, full-platform coverage, protected merge and release are not complete at intake.
