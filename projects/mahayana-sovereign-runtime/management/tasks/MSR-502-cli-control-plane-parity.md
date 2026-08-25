# MSR-502 — Mahayana CLI control-plane parity

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-502
- **Status:** in-progress
- **Started:** 2026-08-25T09:00:00-07:00
- **Updated:** 2026-08-25T09:00:00-07:00
- **Completed:** null

## Objective

Make the Mahayana CLI a first-class product control plane for bots and Mini Apps, using Mahayana-owned runtime/Host contracts while preserving Codex and Grok Build only as provenance-aware compatibility and design inputs.

## Source requirements

- `projects/mahayana-sovereign-runtime/source/2026-08-25-msr-502-cli-control-plane-parity.md`
- MSR-R04, MSR-R07, MSR-R08

## In scope

1. Full bot lifecycle from CLI: list, create, update, clone, delete, hide/show, select/chat.
2. Mini App discovery/install/open/chat and BotFather-style create/draft/submit operations from CLI.
3. Mahayana-owned bot conversation identifiers for all newly emitted state.
4. CLI parser, routing, product-client, Host-state, and regression tests.
5. Protected PR merge and canonical-main verification.
6. Exact-main packaged desktop/mobile E2E and release evidence before final completion.

## Out of scope

- Blindly copying either upstream source tree or exposing vendor-owned public product types.
- Claiming store/GitHub Release publication before signed package and simulated-user E2E evidence exists.
- Removing read compatibility for already persisted `codex:agent:*` identifiers in this atomic task.

## Open-source-first decision

Reviewed `xai-org/grok-build` and `openai/codex` as Apache-2.0 upstreams. Reuse orchestration, resilience, local-agent, sandbox, MCP, skills, and session design patterns through Mahayana-owned boundaries. Telegram/Grok Bot integration remains the source for bot-centric messaging and Mini App/BotFather lifecycle. No vendor product identity is promoted into the public Mahayana API.

## Acceptance criteria

1. `mahayana bot --help` exposes lifecycle and chat/select operations.
2. Bot mutations dispatch existing `FeatureCommand` variants and persist through the shared Feature Host.
3. `mahayana miniapp --help` exposes registry/search/added/install/open/chat/generate/draft/submit operations.
4. Mini App marketplace/account mutations use `MahayanaProductClient`; local install/open use the shared Host/runtime path.
5. New/default bot conversations use `mahayana-ai:agent:*`; legacy persisted IDs remain accepted.
6. Targeted CLI/product/Host/protocol tests and formatting pass.
7. Required GitHub checks pass on the exact PR head; PR merges into `main`; canonical-main readback matches.
8. Desktop, Android and iOS publication is recorded only after exact-main package + simulated-user E2E + release evidence succeeds.

## Verification plan

- `cargo fmt --all -- --check`
- `cargo test -p mahayana-cli`
- `cargo test -p mahayana-product`
- `cargo test -p mahayana-feature-host`
- `cargo test -p mahayana-host-protocol`
- Repository project-governance validation
- Required PR CI checks
- Post-main desktop/native package and E2E workflows

## Branch / commit / PR

- Branch: `feat/msr-502-cli-control-plane-parity-20260825`
- Commit: source intake `32702abf21ccf679f3d1a9866a72de04c1efc340`; implementation pending
- PR: pending

## Implementation summary

Source intake and gap analysis complete. Code implementation is in progress.

## Evidence

- Source intake file on task branch.
- Live main and current CLI/Host/product contracts inspected through GitHub.
- CI/build/release evidence pending.

## Blockers / risks

- Local DevSpace and project VPS connectors returned HTTP 502 during this execution round. Code changes therefore must be produced on a reviewable branch and verified by GitHub-hosted CI; no local-pass claim will be made.
- Release signing, notarization, TestFlight/store authorization and publication remain dependent on repository secrets and successful exact-main workflows.

## Next action

Apply the typed CLI control-plane implementation, run branch CI, fix failures, and open the protected-main PR.
