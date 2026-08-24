# FCM-010 — PR CI hot-path latency optimization

- **Project:** FAB-P0003 / FCM
- **Status:** in-progress
- **Source:** `source/2026-08-24-pr-ci-latency-regression.md`
- **Owner:** Fabushi engineering automation

## Objective

Reduce ordinary pull-request feedback latency without weakening canonical-main or release validation. Eliminate avoidable cross-platform duplicate Rust compilation, restore safe incremental build state, and stop isolated Mahayana runtime changes from forcing unrelated canonical CI domains.

## Atomic acceptance

| ID | Deliverable | Verification | State |
|---|---|---|---|
| FCM-010.1 | Mahayana PR validation uses one representative Linux runner; main keeps three desktop OSes | workflow definition + PR/main Actions evidence | implemented |
| FCM-010.2 | Mahayana Cargo state restored across runs | Actions cache restore/save evidence | implemented |
| FCM-010.3 | `mahayana-runtime/**` is classified, not `unknown forceAll` | CI classifier summary on PR | implemented |
| FCM-010.4 | Next.js incremental cache restored for frontend builds | Actions cache evidence on affected run | implemented |
| FCM-010.5 | Fabushi Pay Worker Rust target restored for Worker checks | Actions cache evidence on affected run | implemented |
| FCM-010.6 | Required PR workflows pass and optimized branch merges through protected `main` | PR/check/merge evidence | pending |
| FCM-010.7 | Canonical `main` readback and post-main delivery/governance evidence captured | exact merged SHA evidence | pending |

## Implementation notes

- `.github/workflows/ci_codex_sync.yml`
  - adds per-PR concurrency cancellation;
  - uses Ubuntu-only matrix on pull requests and preserves Ubuntu/macOS/Windows on canonical push;
  - enables Cargo incremental state and `Swatinem/rust-cache` for the Mahayana workspace.
- `.github/workflows/ci.yml`
  - recognizes `mahayana-runtime/**` under the existing Electron/Mahayana architecture domain so isolated runtime edits no longer trigger the unknown-path force-all fallback;
  - persists `frontend/apps/web/.next/cache` keyed by lockfile + source inputs with lockfile fallback;
  - persists `mahayana-pay-worker/target` keyed by its Cargo metadata with a safe cold-build fallback.

## Open-source/provenance decision

- Reused GitHub's official `actions/cache` model already present in the repository.
- Reused the existing repository dependency on `Swatinem/rust-cache` rather than introducing another cache implementation.
- Reviewed `mozilla/sccache` as a mature compiler-result cache; deferred adding it to this PR because existing Rust target-cache reuse should be measured first and has lower integration risk.

## Evidence

Pending PR and Actions run IDs. Do not mark passed until protected merge and canonical-main readback complete.
