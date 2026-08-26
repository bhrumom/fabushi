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
| FCM-010.1 | PR uses Mahayana fast checks; heavyweight embedded-Codex desktop matrix runs only on canonical branch/manual validation | workflow definition + PR/main Actions evidence | implemented |
| FCM-010.2 | Mahayana heavyweight Cargo state is reusable across canonical runs | rust-cache restore/save evidence | implemented |
| FCM-010.3 | `mahayana-runtime/**` is classified, not `unknown forceAll` | CI classifier definition + affected-PR evidence | implemented |
| FCM-010.4 | Next.js incremental cache restored for frontend builds | Actions cache evidence on affected run | implemented |
| FCM-010.5 | Fabushi Pay Worker Rust target restored for Worker checks | Actions cache evidence on affected run | implemented |
| FCM-010.6 | Required PR workflows pass and optimized branch merges through protected `main` | PR/check/merge evidence | pending |
| FCM-010.7 | Canonical `main` readback and post-main heavy validation evidence captured | exact merged SHA evidence | pending |

## Implementation notes

- `.github/workflows/ci_codex_sync.yml`
  - removes the heavyweight embedded-Codex workflow from the pull-request trigger;
  - preserves the Ubuntu/macOS/Windows matrix for `main`/`develop` pushes and manual verification;
  - enables Cargo incremental state and `Swatinem/rust-cache` for the Mahayana workspace;
  - enables concurrency cancellation for superseded canonical runs.
- `.github/workflows/ci.yml`
  - recognizes `mahayana-runtime/**` under the existing Electron/Mahayana architecture domain so isolated runtime edits no longer trigger the unknown-path force-all fallback;
  - persists `frontend/apps/web/.next/cache` keyed by lockfile + source inputs with lockfile fallback;
  - persists `mahayana-pay-worker/target` keyed by its Cargo metadata with a safe cold-build fallback.
- `.github/workflows/mahayana-fast-checks.yml` remains the existing targeted Mahayana pull-request validation layer. A measured cached run on PR #2085 restored about 1.2 GB of Cargo state and completed the targeted Rust validation surface in roughly three minutes, making a second full embedded-Codex clippy/test graph on every PR redundant.

## Open-source/provenance decision

- Reused GitHub's official `actions/cache` model already present in the repository.
- Reused the existing repository dependency on `Swatinem/rust-cache` rather than introducing another cache implementation.
- Reviewed `mozilla/sccache` as a mature compiler-result cache; deferred adding it to this PR because existing Rust target-cache reuse should be measured first and has lower integration risk.

## Evidence

- Optimization PR: #2087, branch `ci/pr-fast-path-cache-20260824`.
- First optimization pass, head `4c2df352e389bd4c759e803bbffa7a0ffeb2972c`:
  - canonical CI run `32682617913` succeeded;
  - classifier selected only workflow governance for this workflow/project-only diff;
  - Frontend, Worker, MCP and Electron jobs were skipped;
  - the temporary reduced embedded-Codex PR matrix started only one Ubuntu job, proving the three-platform PR fan-out was removed before the stronger final split.
- Final split, head `e352970b1c9d7ffae021e23fe3b5259c022f0d20`:
  - canonical CI run `32682758346` succeeded;
  - `CI result` succeeded;
  - Frontend, Worker, MCP and Electron jobs were skipped as unaffected;
  - no `Mahayana embedded Codex Runtime` workflow was created for the PR head, confirming the heavyweight workflow is no longer a pull-request gate.
- Existing Mahayana fast-check reference: PR #2085 run `32681469999`, job `97298788047`, demonstrates the targeted PR Rust suite and successful Cargo cache restore.

Do not mark the task passed until protected merge and canonical-main readback/post-main heavyweight validation are complete.
