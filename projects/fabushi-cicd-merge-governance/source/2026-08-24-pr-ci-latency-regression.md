# 2026-08-24 PR CI latency regression optimization

## User request

The user asked to start optimizing the current CI after identifying the largest latency sources in recent pull-request runs.

## Observed regression

Recent PR evidence showed three avoidable costs:

1. A small `third_party/mahayana/**` Rust change was classified as an unknown non-document path by `.github/workflows/ci.yml`, which forced unrelated Frontend, Worker, MCP, workflow guardrail, and Electron checks.
2. `Mahayana embedded Codex Runtime` ran the same heavyweight Cargo clippy surface on Ubuntu, macOS, and Windows for every relevant PR, with no restored Cargo target cache; one macOS clippy attempt spent several minutes compiling before reaching a simple lint failure.
3. Frontend `next build` and Worker Rust/WASM paths showed cold-build behavior even when reusable dependency/build state could be restored safely.

## Required outcome

- Pull requests run the smallest safe affected validation surface.
- Cross-platform heavyweight validation remains available after merge / canonical validation rather than blocking every ordinary PR when one representative platform is sufficient for source-level Rust lint/test feedback.
- Rust/Cargo, Worker WASM, and Next.js incremental build state is restored with content/version-aware cache keys and safe cold-build fallback.
- CI classification explicitly understands Mahayana runtime/source paths instead of treating them as unknown and forcing unrelated domains.
- Required aggregate CI remains fail-safe: genuinely unknown non-document changes still force broad validation.
- Record warm/cold evidence from GitHub Actions before closing the task.

## Open-source-first research

Reviewed before implementation:

- `actions/cache` — official GitHub-maintained MIT-licensed action for dependency/build-output caching; chosen as the default primitive because it avoids a custom cache protocol and is already used in Fabushi CI.
- `Swatinem/rust-cache` — mature Rust/Cargo smart-cache action; useful reference for Cargo cache boundaries and keying, but not required if the repository can satisfy the same correctness properties with the official cache action.
- `mozilla/sccache` — mature Apache-2.0 compiler-result cache; retained as a proven option for deeper Rust/C/C++ compile reuse, especially in post-main heavy builds. For this PR fast-path optimization, prefer the lower-risk official cache primitive first and add compiler-wrapper complexity only where measurements justify it.

## Acceptance evidence required

- changed-path classifier selects only Mahayana-specific fast checks for an isolated Mahayana runtime change;
- ordinary unrelated frontend/worker jobs do not start for that isolated change;
- Rust cache restore/save is visible in Actions logs and cold fallback remains valid;
- Next.js cache restore/save is visible when frontend inputs are affected;
- Worker Rust/WASM cache restore/save is visible when worker inputs are affected;
- required PR CI passes, then the optimization PR merges to `main` and canonical readback confirms the merged workflow definitions.
