# 81 — TFI-M6-MAINSAFE-001 VERSION-GUARD 阻塞重规划变更日志 — 2026-09-05

This file records architecture/governance actions only. No product/test/workflow/Cargo/dependency/version configuration was changed by this architecture session.

## Read and verification log

1. Re-read canonical GitHub `main` and confirmed exact SHA remains `dbf22b467d35c8af2a074896c355a41993c8c191`.
2. Re-read root `AGENTS.md`, `projects/PORTFOLIO.json`, TFI `SOURCE_OF_TRUTH.md`, `PROJECT.yaml`, `README.md`, M6 WBS/milestone/acceptance/risk/dependency/status/changelog/issues records and relevant ADR/governance precedent.
3. Re-read records-only architecture PR #2340 and reused its existing architecture branch rather than creating a duplicate PR.
4. Re-read product PR #2341, its exact changed-files, final head `2241c856fb3da498ac99ade89007fe01dd335183`, execution records and blocker comment `5547296411`.
5. Re-read final-head workflow runs: CI `33926840519`, Native mobile `33926840551`, Project portfolio governance `33926840613`, Developer Fiat Commerce `33926840526`, Explicit automerge `33926840543`; all succeeded for the work they actually ran.
6. Read raw CI `Canonical architecture guardrails` job `101198143445`; verified it checks retired Flutter/Tauri/Capacitor workflow commands only and does not execute `.github/scripts/assert-native-electron-canonical.sh`.
7. Read Native mobile final-head jobs; verified PR fast path runs diff/rustfmt/manifest checks while heavyweight Android/iOS build, XcodeGen, simulator/UI-test and artifact steps are skipped.
8. Re-read `.github/scripts/assert-native-electron-canonical.sh`, `ci.yml`, `electron-desktop.yml`, `native-mobile.yml`, version/release workflow call sites, `app-version.json`, `mobile/ios/project.yml`, and ruleset `15857448`.
9. Confirmed ruleset requires only `CI result`, while current `CI result` dependency graph has no canonical version-contract child job.

## Root-cause decision

Classified the blocker as **CI/GOVERNANCE REQUIRED-GATE TOPOLOGY GAP**, not a proven defect in #2341's one-line product/config patch.

Rejected evidence substitutions:

- the similarly named `Canonical architecture guardrails` job;
- Native mobile PR fast-path SUCCESS with heavy steps skipped;
- a manually dispatched diagnostic workflow;
- an Electron status not wired into protected required `CI result`;
- historical or different-head workflow success.

## Replanning writes

- Added root-cause evidence `VERSION-GUARD-BLOCKER-DIAGNOSIS-2026-09-05.md`.
- Added `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` with `.github/workflows/ci.yml`-only future implementation allowlist.
- Added `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002`, blocked until the CI task is reviewed, protected-merged and read back from canonical main.
- Updated historical `VERSION-CONTRACT-001` to BLOCKED / UNREVIEWED and recorded #2341 disposition.
- Updated M6 WBS, post-main acceptance matrix, milestone, risk register, dependency/blocker register and issues/actions.
- Added dated status/acceptance record `80-...VERSION-GUARD-阻塞重规划状态与验收.md` and this changelog.

## Open-source-first / official references

- GitHub Actions official documentation: adopted pull-request path-selection, required-check and merge-queue semantics; no code copied.
- GitHub manual workflow documentation: retained `workflow_dispatch` as a diagnostic mechanism, rejected it as durable automatic required-PR-gate replacement.
- `actions/github-script`: GitHub-maintained, MIT; repository already uses it for impact classification, no new dependency and no code copied.
- Fabushi FCM ADR-0005: reused first-party fail-fast principle—cheap deterministic PR checks, aggregate `CI result`, unknown-path fail-safe, heavy package/device work post-main.

No new TFI product ADR was created because product/version authority is unchanged; this round restores enforcement topology for an existing canonical script. FCM ADR-0005 remains the applicable CI-governance precedent.

## Explicit non-actions

- did not modify #2341 product branch;
- did not close/merge/rebase/retarget/force-push #2341;
- did not modify `.github/**` implementation files;
- did not start code review, test release, stable release, IOS-FIXTURE, EVIDENCE-CONTRACT, EVIDENCE-JOURNEY, MAINSAFE-002 or MAINSAFE-003;
- did not reopen completed OWNERSHIP-001;
- did not run local build/test.
