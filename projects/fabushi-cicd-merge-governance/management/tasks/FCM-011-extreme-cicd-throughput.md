# FCM-011 — Extreme CI/CD throughput

- **Project:** FAB-P0003 / FCM
- **Status:** in-progress
- **Source:** `source/2026-08-27-extreme-cicd-throughput.md`
- **Owner:** Fabushi engineering automation

## Objective

Drive PR feedback, merge-queue validation, canonical-main build/test, and release delivery toward the fastest safe execution model by removing avoidable runner/setup work, front-loading deterministic failures, and reusing valid build state without reducing any required safety or release gate.

## Atomic acceptance

| ID | Deliverable | Verification | State |
|---|---|---|---|
| FCM-011.1 | Electron PR runs architecture/text guards before npm dependency install | workflow ordering + PR #2171 Actions evidence | implemented |
| FCM-011.2 | Electron canonical architecture guard has no Node setup dependency | Python JSON/version validation + PR #2171 evidence | implemented |
| FCM-011.3 | Native mobile PR avoids recursive submodules and full-history checkout | event-aware checkout definition + PR #2171 evidence | implemented |
| FCM-011.4 | Native PR fetches only the exact base commit needed for `git diff --check` | exact `BASE_SHA` shallow fetch + PR #2171 evidence | implemented |
| FCM-011.5 | Mahayana PR fails formatting before native package installation | workflow ordering + PR #2171 evidence | implemented |
| FCM-011.6 | Existing caches and post-main heavy validation remain intact | workflow diff + main/readback evidence | implemented |
| FCM-011.7 | Required PR CI passes through protected merge queue | PR checks + merge evidence | pending |
| FCM-011.8 | Canonical main post-merge workflows remain green for exact accepted SHA | main workflow evidence | pending |

## Implementation

- `.github/scripts/assert-native-electron-canonical.sh`
  - removed the Node runtime dependency from version-drift validation;
  - uses Python stdlib JSON so the guard can run before Node setup/npm install.
- `.github/workflows/electron-desktop.yml`
  - runs canonical architecture, Feature Host bridge, and Python architecture/UI contracts immediately after checkout;
  - only then configures Node, restores npm cache, installs dependencies, and runs Node/TypeScript checks;
  - all main-only Rust Host, packaging, signing, notarization, packaged E2E, and artifact upload stages are preserved.
- `.github/workflows/native-mobile.yml`
  - PR checkout uses depth 1 and disables recursive submodules;
  - main/workflow-call paths preserve full history and recursive submodules;
  - PR diff validation fetches only the exact base SHA with depth 1.
- `.github/workflows/mahayana-fast-checks.yml`
  - `cargo fmt --check` runs immediately after Rust setup and before apt native dependency installation/cache restore.

## Constraints

- Do not remove `CI result`, merge-group validation, protected-main rules, or required post-main E2E.
- Do not move signing/notarization/package integrity checks onto an unverified artifact lineage.
- Do not use stale caches without deterministic cold fallback.
- Do not claim performance improvement without Actions timing/queue evidence.

## Evidence

- Branch: `ci/fcm-011-extreme-throughput-20260827`
- PR: #2171
- Head at first acceptance run: `93e7b56ef299976c1905c653f41dddfeb6a6897f`
- PR workflows observed: canonical CI, Electron desktop quality gate, Native mobile quality gate, Mahayana fast checks, delivery governance, post-main contract, latency observability, and portfolio governance.
- Exact merge-group/main/post-main evidence remains pending; task stays `in-progress` until those gates close.
