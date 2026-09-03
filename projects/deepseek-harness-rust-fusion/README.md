# DeepSeek Harness Rust Fusion

## Objective
Use the public `deepseek-ai/deepseek-harness` project as a capability and behavior reference, then converge its valuable agent-harness functionality into Fabushi's existing Mahayana Rust runtime without embedding Node.js, Cordis, Python, or a second product runtime.

This is a related workstream of `projects/mahayana-sovereign-runtime/`, focused specifically on DeepSeek Harness capability parity and productization.

## Current verified state
- Upstream baseline reviewed for project intake: `deepseek-ai/deepseek-harness` `0.1.1-rc.2`, commit `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e` (2026-08-21).
- Upstream identifies itself as MIT licensed and developer preview with compatibility-breaking changes expected.
- Fabushi already contains Rust-native `mahayana-harness`, `mahayana-harness-services`, `mahayana-harness-advanced`, `mahayana-harness-adapters`, `mahayana-harness-agent`, and `mahayana-harness-protocol` crates.
- `mahayana-fast-checks.yml` already tests those Harness crates in GitHub Actions.
- Existing `mahayana-harness/README.md` contains a broad DeepSeek Harness capability map with both implemented and pending areas. This project must close and prove those gaps rather than create a duplicate runtime.

## Current stage
`M0 — source audit and gap baseline`

Next gate: inventory the pinned upstream capability surface and reconcile it against the existing Mahayana Harness crates, producing a requirement-to-code-to-test gap matrix.

## In scope
Rust-native parity for the pinned upstream capability surface: composable services/plugins, profiles/bundles/overlays, session/event model, agent loop, tools/policy, model adapters/streaming, persistence/query, shell/PTY/filesystem/LSP/code runtime, sandbox, MCP/web/attachments, subagents/teams/jobs/goals/workflows, settings/credentials/identity, SDK/JSON ABI/ACP/headless, scheduling/feedback, and cross-surface product integration where relevant.

## Non-goals
- Vendoring the TypeScript application as Fabushi's runtime.
- Adding Node.js/Cordis as a required Mahayana product dependency.
- Replacing Mahayana-owned public protocol, IDs, policy, conversation model, or lifecycle with DeepSeek product contracts.
- Claiming parity against a moving `master`; acceptance is pinned to the recorded revision until a new audit round deliberately advances it.

## Primary acceptance definition
The project is complete only when every required capability at the pinned upstream baseline is classified, mapped to a Mahayana-owned Rust contract, implemented or explicitly rejected with rationale, objectively verified in GitHub Actions, exposed through the canonical Mahayana Host/FeatureHost surfaces where applicable, and license/provenance/security gates pass.

## Navigation
- Source intake and pinned upstream: `source/`
- Product/engineering specs: `docs/`
- Capability baseline: `docs/08-DeepSeek-Harness能力映射.md`
- Roadmap/WBS/status: `management/`
- ADRs: `decisions/`
- Evidence indexes: `evidence/`
- Operational procedures: `runbooks/`
