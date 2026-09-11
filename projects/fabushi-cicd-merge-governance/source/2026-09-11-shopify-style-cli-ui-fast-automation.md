# 2026-09-11 — Shopify-style CLI/UI decoupled fast automation

## User requirement

Continue pushing Fabushi automated testing toward the fast-feedback model referenced by the user at:

- https://mp.weixin.qq.com/s/DEg20nFKfrd2urMc3BjntA

The requested outcome is a Shopify-like development loop on GitHub Actions: make ordinary iteration fast, keep product logic testable without launching full platform UIs, preserve a thin independent UI journey layer, and reserve expensive packaged/device validation for canonical main/release acceptance.

This source extends the existing FCM fast-feedback program; it does not create a second CI project.

## Verified repository baseline

At intake, canonical `main` is `d8bb64f44a7d97b38d8ac10d2193c8b1cb95f0f4`.

Existing reusable assets already present on `main`:

- `docs/fast-feature-testing.md` requires business logic to live in Mahayana Rust Core and treats React Host as an interaction surface.
- `.github/workflows/host-fast-e2e.yml` provides a separate UI journey lane with sparse checkout, dependency cache, cancellation of superseded runs, and a 45-second Playwright journey budget.
- `.github/workflows/mahayana-fast-checks.yml` provides a Rust/Core pull-request gate with a reusable Cargo cache, but currently runs almost its entire package surface for any `third_party/mahayana/mahayana-rs/**` change.
- `mahayana-test-driver-protocol` is a presentation-neutral debug-only control plane whose backend contract explicitly requires product operations to call the same Mahayana core/product services as normal application surfaces rather than synthesizing automation success.
- `mahayana-cli` already ships a debug-only `mahayana-test-driver` binary backed by `MahayanaProductClient`, including real marketplace/plugin/MiniApp product operations, but the normal developer CLI has no `mahayana test` entry point.

## Shopify / upstream research

Implementation is based on upstream principles rather than copying proprietary infrastructure:

1. Shopify Engineering, “Keeping Developers Happy with a Fast CI” (2021): measure latency, avoid work that does not need to run, map changes to affected tests, parallelize where it reduces wall clock, and focus optimization on the slowest/highest-frequency work. Shopify reported increasing builds that avoided a full test selection and reducing p95 CI substantially.
2. `Shopify/cli` (MIT) was reviewed as the current public CLI family; the useful pattern here is keeping CI commands first-class and scriptable, not copying implementation code.
3. GitHub `actions/cache` (MIT) and the repository's existing `Swatinem/rust-cache` integration are retained. No new third-party CI dependency is introduced in this slice.
4. `Swatinem/rust-cache` is already present in Fabushi. Its current documentation states that cache identity incorporates toolchain and Cargo metadata; the existing integration is reused rather than adding another cache layer.

Decision: implement the affected-test selector in repository-owned Python, preserve conservative full-suite fallback for shared/unknown Mahayana changes, and expose the existing real product test-driver through a debug-only `mahayana test` command. This keeps provenance simple and avoids adding a new action/runtime dependency.

## Required architecture

### Plane A — Mahayana Core / CLI

- `mahayana test` must be a debug/test-driver-only command.
- It must execute through the existing `ProductBackend` / `MahayanaProductClient` test-driver path, not a fake CLI-only model.
- A default local smoke suite must require no UI, credentials, emulator, simulator, or installer.
- An explicit online mode may call public product-core marketplace search without launching UI.
- Release builds must continue to exclude/forbid the test-driver surface.

### Plane B — UI

- `Host fast E2E` stays independently runnable and deterministic.
- UI tests validate interaction/contract wiring and must not become the primary place for business rules.
- Packaged/native/device journeys remain canonical-main/release evidence, not ordinary PR hot-path work.

### GitHub Actions selection

- Pull requests select the smallest safe Mahayana Rust test groups from changed paths.
- Shared workspace inputs, native messaging, workflow/selector changes, or unknown Mahayana crate paths fail safe to the full fast suite.
- Canonical `main` and manual dispatch continue to run the full fast suite.
- The selector itself has deterministic unit tests and records selected groups/reason in the Actions summary.
- Existing Cargo cache, source-boundary check, formatting gate, and cold-build correctness remain intact.

## Acceptance

The task is not complete merely because files exist on a branch. Required closure evidence:

1. selector unit tests and CLI/test-driver tests pass on the pull request;
2. `mahayana test` local smoke and online Product Core probe run successfully in GitHub Actions;
3. an affected leaf-crate change demonstrates a reduced PR test surface, while a shared/unknown-path fixture demonstrates full fallback;
4. required repository checks pass and the change merges through the repository's protected merge process;
5. exact merged `main` SHA is read back and the canonical main fast checks run with the full suite;
6. because CI/workflow delivery behavior changes, downstream canonical delivery evidence must remain green or the task remains open with the objective blocker recorded.
