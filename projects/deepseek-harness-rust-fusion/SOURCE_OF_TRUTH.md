# Source of Truth

## Authoritative engineering state
1. `bhrumom/fabushi` GitHub `main` for implementation facts.
2. `projects/deepseek-harness-rust-fusion/` for this workstream's durable requirements, WBS, ADRs, acceptance and evidence indexes.
3. Accepted ADRs/current specifications in this project.
4. Live GitHub PR/CI/release facts.
5. The related `projects/mahayana-sovereign-runtime/` project for product-wide sovereign-runtime boundaries.
6. Upstream DeepSeek Harness source at the explicitly pinned revision for behavioral reference.
7. Chat/external mirrors only as intake unless persisted here.

## Original requirement
On 2026-08-22 the user requested that `https://github.com/deepseek-ai/deepseek-harness` be fused into Fabushi using Rust, and requested a project folder for that plan.

## Pinned upstream baseline
- Repository: `deepseek-ai/deepseek-harness`
- Branch observed: `master`
- Version observed: `0.1.1-rc.2`
- Commit: `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e`
- Commit date: 2026-08-21
- License: MIT for the upstream first-party project; third-party notices still require separate audit.
- Upstream status: developer preview; compatibility-breaking changes are explicitly expected.

## Existing Fabushi implementation baseline
- `third_party/mahayana/mahayana-rs/mahayana-harness*`
- `third_party/mahayana/mahayana-rs/mahayana-feature-host`
- `third_party/mahayana/mahayana-rs/mahayana-host*`
- `third_party/mahayana/mahayana-rs/mahayana-tool-host`
- `third_party/mahayana/mahayana-rs/mahayana-plugin-runtime`
- `.github/workflows/mahayana-fast-checks.yml`
- `docs/mahayana-sovereign-kernel.md`

## Conflict rule
Live code/CI facts override stale project claims about implementation state. The latest persisted user requirement controls scope. Upstream behavior is a reference, not Fabushi's public ABI. Discrepancies are appended to status/changelog rather than silently rewritten.

## Revision advancement rule
Do not silently change the acceptance baseline from `b150a551...`. A later upstream sync requires a dated source update, new gap audit, changelog entry and explicit task/evidence round.
