# 87 — 2026-09-05 M6 MAINSAFE VERSION-BOOTSTRAP execution changelog

## TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001

### Added / changed

- Created a fresh replacement branch from canonical `main@dbf22b467d35c8af2a074896c355a41993c8c191`.
- Created replacement PR #2343; this is new lineage and does not reuse #2340/#2341/#2342.
- Product/bootstrap commit: `496ddefc0866f2d0568d0c3d618cfcede2e6c98c`.
- `.github/workflows/ci.yml`: adopted the repository-proven #2342 canonical-version child topology, executing the unchanged `.github/scripts/assert-native-electron-canonical.sh`; `CI result` now directly needs that child and rejects anything except exact `success`.
- `mobile/ios/project.yml`: changed only `CURRENT_PROJECT_VERSION` from `28` to `29` to match authoritative `app-version.json.iosBuildNumber=29`.
- Added/retained only task-specific TFI records required to preserve the frozen bootstrap contract, architecture provenance, execution evidence and acceptance state.

### Not changed

No changes to `app-version.json`, canonical version script, ruleset/branch protection, other workflows, Android, Electron, application/test source, Cargo/dependencies, release logic, iOS fixture/evidence journey tasks, OWNERSHIP, MAINSAFE-002/003.

### Verification discipline

- No local build/test/rustfmt/clippy/E2E.
- Lightweight verification only: GitHub source/diff/state readback and historical provenance inspection.
- Heavy acceptance: final exact-head GitHub Actions only.
- Historical #2342 run `33928934236` is retained only as topology/failure provenance and is not current acceptance evidence.

### Historical disposition

- #2341@`2241c856fb3da498ac99ade89007fe01dd335183`: OPEN / UNMERGED / historical version-only provenance; blocker comment `5547296411`.
- #2342@`570b874318bfe42406c6f46f51798baed8c89e48`: OPEN / UNMERGED / historical guard-only provenance; blocker comment `5547556953`.
- Architecture handoff `5547662428` authorizes #2343-style atomic bootstrap.
- This execution deliberately does not close either historical PR; future superseded closure remains an explicit separate disposition action, never a merge shortcut.

### Current state

`IMPLEMENTED / FINAL-EXACT-HEAD-ACTIONS-PENDING` at the time of this record commit. Exact run/job IDs and terminal gate conclusions can only exist after the record commit creates the final candidate head; those live facts are written to the PR execution handoff comment after Actions completes.
