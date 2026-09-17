# FCM-010.9 canonical evidence — 2026-09-12

Project: `FAB-P0003 / FCM`
Task: `FCM-010.9`
Intake: `[Fabushi:dc7a68a4-8194-41dd-bc00-aa6074cf0323]`

## Accepted implementation

- PR: `#2520` — `[automerge-force] ci: make Mahayana CLI the first-class fast test gate`
- PR head: `2d462e2a2da26c02fc424d71a357f477858fd096`
- Protected merge time: `2026-09-11T16:26:35Z`
- Accepted / canonical implementation SHA: `54299a9d7c59fe753cceaeb0063d0cbd10fd3a9e`
- Canonical `main` readback after merge matched the accepted SHA exactly.

## PR validation

- Required `CI result`: run `34621763910` — `success`.
  - Included `chatgpt-vps-control/tests/mahayana-cli-fast-gate-contract.test.js`.
- `Mahayana fast checks`: run `34621763777`, job `103337200805` — `success`.
  - `Test Mahayana CLI as the product logic entry point` — `success`.
  - `Test deterministic CLI test-driver protocol` — `success`.
  - All pre-existing compatibility, auth/secrets, platform client, kernel, orchestration/workspace, model/native engine, MCP/native Agent, MiniApp bridge, Harness, direct Host, feature Host, production adapter and FFI steps also completed successfully.
- `Electron desktop quality gate`: run `34621763798` — `success`.
  - Existing native Host cache was hit; unnecessary native Host rebuild work was skipped.
- `CI latency observability`: run `34621763690` — `success`.
  - Artifact: `fcm-ci-latency-34621763690`.
  - Artifact id: `5732718810`.
  - Digest: `sha256:56424854968c28dbb1f61dcfb7dc5dd11f932d55df3009915014e25cf77c4657`.
  - Retention: 30 days.

## Exact-main validation

The merge pushed the exact accepted implementation SHA to canonical `main` and automatically ran the same Mahayana fast workflow again.

- `Mahayana fast checks`: run `34622011854` — `completed / success`.
- Event: `push`.
- Head branch: `main`.
- Head SHA: `54299a9d7c59fe753cceaeb0063d0cbd10fd3a9e`.
- Started: `2026-09-11T16:26:37Z`.
- Completed: `2026-09-11T16:30:18Z`.
- Direct `mahayana-cli` gate — `success`.
- Direct `mahayana-test-driver-protocol` gate — `success`.
- Every subsequent step in the same Rust protocol/Host/bridge job — `success`.

This establishes that the CLI-first test surface is not only present in a PR definition: it is merged into protected `main` and proven on the exact accepted source.

## Result

`FCM-010.9` is accepted as **passed**. Ordinary Mahayana product-logic changes now have a first-class CLI/test-driver correctness surface before broader runtime suites, while the workflow keeps affected-path selection, sparse checkout, superseded-run cancellation, Cargo incremental compilation and shared rust-cache behavior. The lightweight required CI contract prevents accidental removal of this architecture or accidental expansion to `cargo test --workspace`.

## Remaining system-level gap

This atomic task does **not** claim complete Shopify-style parity. The packaged macOS interactive workflow still contains an external-control hold of up to 1500 seconds while waiting for an external `@fabushi test` controller to finish the full semantic journey. The installed App already exposes the private loopback App Agent bridge; the next optimization is to add a GitHub-Action-owned semantic smoke/journey runner on that bridge so the Action can drive deterministic UI checks immediately, while preserving the full external journey as an independent acceptance/evidence path until equivalence is proven.
