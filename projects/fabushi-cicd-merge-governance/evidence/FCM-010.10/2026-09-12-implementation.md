# FCM-010.10 implementation evidence — 2026-09-12

Project: `FAB-P0003 / FCM`
Task: `FCM-010.10`
Intake: `[Fabushi:dc7a68a4-8194-41dd-bc00-aa6074cf0323]`

## Accepted implementation

- PR: `#2522` — `[automerge-force] ci: self-drive packaged App Agent smoke`
- PR head: `6a74053d81b0cc249d113236132b819ab2f7912d`
- Protected merge time: `2026-09-11T16:39:44Z`
- Canonical implementation SHA: `f87dd9c9aa8fd30b8ec710d370f1c6ffdd3dd094`
- Canonical `main` readback after merge matched that SHA exactly.

## PR validation

- Required `CI result`: run `34623115965` — `success`.
  - `app-agent-ci-smoke.test.js`: 3 passed / 0 failed.
    - semantic bridge is driven without coordinates;
    - semantic assertion failures fail closed;
    - sensitive values exposed by a snapshot are rejected.
  - `macos-interactive-app-e2e-contract.test.js`: 9 passed / 0 failed.
    - includes the required order: App-owned registration -> Action-owned semantic smoke -> external full journey.
  - iOS interactive contract: 3 passed / 0 failed.
  - Mahayana CLI-first fast-gate contract: 1 passed / 0 failed.
- Delivery governance contract: run `34623115936` — `success`.
- Project portfolio governance: run `34623115997` — `success`.
- GBF security closure: run `34623115994` — `success`.
- CI latency observability: run `34623116018` — `success`.
- Electron desktop quality gate PR run `34623115952`:
  - Electron Linux job completed `success`;
  - reusable native Host cache restored successfully;
  - native Host Rust toolchain/dependency/build steps were skipped on the cache hit;
  - real Linux Rust Host user simulation completed `success`.

## Canonical delivery state

After merge, canonical `main@f87dd9c9aa8fd30b8ec710d370f1c6ffdd3dd094` automatically started the main Electron delivery workflow (run `34623280296`). The Action-owned App smoke itself is intentionally located in `.github/workflows/macos-interactive-app-e2e.yml`, which executes only for a published desktop release or explicit workflow dispatch. At the time this evidence was recorded, no `macOS interactive app device E2E` run for this exact SHA had appeared yet.

Therefore the implementation is accepted into main, but real installed-package acceptance remains pending. Do not treat unit/contract tests or the merge as substitute evidence for the packaged smoke.

## Remaining acceptance

FCM-010.10.8 remains pending until all of the following are true on one canonical exact-source run:

1. a published desktop release resolves to exact source `f87dd9c9aa8fd30b8ec710d370f1c6ffdd3dd094` (or a later canonical SHA containing this implementation);
2. `macOS interactive app device E2E` installs that exact signed release and the App registers its own semantic surface;
3. `Run Action-owned packaged App Agent semantic smoke` succeeds;
4. the uploaded evidence contains `action-owned-app-agent-smoke.json` with `schema=fabushi.app-agent-ci-smoke.v1`, `ok=true`, and semantic `action` + `assert` operations;
5. the existing external full journey, packaged Playwright surface and truthful evidence gate remain successful.

Only after that evidence exists should the task become `passed` and any reduction of the 1500-second external full-journey hold be considered.
