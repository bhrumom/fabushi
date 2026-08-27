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
| FCM-011.1 | Electron PR runs architecture/text guards before npm dependency install | workflow ordering + failing/success PR evidence | planned |
| FCM-011.2 | Electron canonical architecture guard has no Node setup dependency | script validation + PR evidence | planned |
| FCM-011.3 | Native mobile PR avoids recursive submodules and full-history checkout | workflow definition + PR checkout evidence | planned |
| FCM-011.4 | Native PR fetches only the exact base commit needed for `git diff --check` | workflow definition + PR evidence | planned |
| FCM-011.5 | Mahayana PR fails formatting before native package installation | workflow ordering + PR evidence | planned |
| FCM-011.6 | Existing caches and post-main heavy validation remain intact | workflow diff + main/readback evidence | planned |
| FCM-011.7 | Required PR CI passes through protected merge queue | PR checks + merge evidence | pending |
| FCM-011.8 | Canonical main post-merge workflows remain green for exact accepted SHA | main workflow evidence | pending |

## Constraints

- Do not remove `CI result`, merge-group validation, protected-main rules, or required post-main E2E.
- Do not move signing/notarization/package integrity checks onto an unverified artifact lineage.
- Do not use stale caches without deterministic cold fallback.
- Do not claim performance improvement without Actions timing/queue evidence.

## Evidence

To be appended with branch commit, PR, workflow run IDs, merge-group run, exact accepted main SHA, and post-main validation runs.
