# 2026-09-05 — M6 MAINSAFE VERSION exact-head checkout 架构诊断与执行交接

- Project: `FAB-P0001 / TFI`
- Architecture state: `DIAGNOSED / REPLANNED`
- Canonical baseline readback: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- New task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement / Acceptance: `M6-PM-VEHC-R01` / `M6-PM-VEHC-A01`
- Task path: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001.md`
- ADR: `projects/telegram-fabushi-integration/decisions/ADR-0014-event-aware-exact-head-checkout-gate.md`
- Diagnosis: `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md`

## Binding diagnosis

Product PR #2343 remains OPEN / UNMERGED. Its base is `dbf22b467d35c8af2a074896c355a41993c8c191` and final product head is `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`.

The automatic PR-head-labelled CI run `33930830358` has a SUCCESS `Canonical version contract` job `101208897330` and SUCCESS required aggregate `CI result` `101209082820`. Those statuses do not meet the frozen exact-head acceptance because the canonical-child raw log proves:

- checkout ref: `refs/remotes/pull/2343/merge`;
- actual worktree HEAD: `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`;
- checkout log identifies it as `Merge bf62cd... into dbf22b...`;
- only after this synthetic merge checkout did `bash .github/scripts/assert-native-electron-canonical.sh` run.

Independent review #2344 / head `b60b8e2483333db21ca6cea068b7a1be9c0f4851` / handoff comment `5547912758` returned `REVIEW-FAIL-VERSION-BOOTSTRAP-001`. This is binding. #2343 is not authorized for protected MERGE, test release or stable release. Other green checks do not waive the checkout mismatch.

## Execution entry — only next task

The execution group may act only on `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`, and only after re-reading live GitHub facts.

It must create a **NEW product PR** from freshly re-read canonical main. Do not reuse/rebase/retarget/force-push #2343. The new PR number and final head do not exist yet and must be recorded by Execution after creation.

If the fresh canonical baseline differs materially from `dbf22b...`, or the version/control-plane facts below changed, stop as `BASELINE-MOVED / ARCHITECTURE-RETURN` rather than mechanically applying this plan.

## Exact implementation/config allowlist

1. `.github/workflows/ci.yml`
   - retain existing canonical-version child and sparse read-only checkout inputs;
   - make checkout event-aware and explicit: `pull_request` -> exact `github.event.pull_request.head.sha` (or equivalent event PR-head SHA); `merge_group` -> current merge-group SHA (`github.sha` / equivalent event group head SHA); existing push/manual behavior uses current event SHA unless fresh facts require an equivalent narrower expression;
   - run exactly the unchanged `bash .github/scripts/assert-native-electron-canonical.sh` after checkout;
   - retain `canonical-version-contract` in required `ci-result.needs` and reject every child result except exact `success`;
   - preserve existing `pull_request`, `merge_group`, `push`, `workflow_dispatch`, classifier semantics, permissions, required status name `CI result`, and all unrelated CI domains.
2. `mobile/ios/project.yml`
   - exactly one semantic change: `CURRENT_PROJECT_VERSION: 28 -> 29`, if live main still has the recorded 29/28 drift.
3. task-specific records under `projects/telegram-fabushi-integration/**` only.

Anything else is outside the allowlist.

## Explicit forbidden files/surfaces

- `.github/scripts/assert-native-electron-canonical.sh`;
- every `.github/workflows/**` file except `.github/workflows/ci.yml`;
- rulesets / branch protection / required-status configuration;
- `app-version.json`;
- Android version/config files;
- desktop/mobile package version sources;
- application source, test source, fixtures, generated product artifacts;
- all `Cargo.toml`, `Cargo.lock`, dependencies and workspace membership;
- release workflows, tags, publish/version logic;
- root `AGENTS.md`, `projects/PORTFOLIO.json`, unrelated projects/records.

Forbidden process operations: close/merge/rebase/retarget/force-push #2341/#2342/#2343/#2344; bypass/direct merge; Architecture implementation; reviewer implementation; test release; stable release.

## Baseline/version preconditions

Re-read immediately before execution:

- canonical main exact SHA;
- `app-version.json.version == 1.2.22`;
- `app-version.json.iosBuildNumber == 29`;
- `mobile/ios/project.yml MARKETING_VERSION == 1.2.22`;
- `mobile/ios/project.yml CURRENT_PROJECT_VERSION == 28`;
- canonical script still treats `app-version.json` as the authority and has not materially changed;
- required protected status is still `CI result` and merge queue/`merge_group` remains applicable;
- #2343 has not merged and no equivalent event-aware fix has landed independently.

Any material mismatch -> Architecture return.

## New product PR / exact final-head rule

- Create one new branch/PR from the fresh canonical main.
- Record the new PR number, base SHA and final product head.
- All PR acceptance binds to the **final product head after all task-specific record commits**.
- Any later commit creates a new final head and invalidates prior exact-head acceptance until automatic checks rerun.
- Historical #2343 `bf62cd...` and synthetic merge `265ceea...` are provenance only.

## PR-head Actions acceptance

Mandatory on one final product head:

1. diff is within allowlist and no forbidden file is changed;
2. iOS semantic version diff is only `28 -> 29`;
3. canonical script is byte-for-byte unchanged by the task;
4. automatic `pull_request` `Canonical version contract` runs and is neither skipped nor neutral/cancelled;
5. raw checkout evidence proves actual worktree HEAD equals the final product head;
6. raw evidence proves the canonical script executes only after that exact-head checkout;
7. child concludes SUCCESS;
8. same-run required `CI result` concludes SUCCESS and raw aggregate evidence reports child exact result `success`;
9. no manual dispatch/rerun/historical/different-SHA/optional-status/sibling-green substitution;
10. fresh independent code review approves that exact final product head.

The recommended evidence hardening is an explicit `git rev-parse HEAD` readback; equivalent raw checkout evidence is acceptable only if it unambiguously proves actual HEAD.

## Independent code review gate

Review must independently verify the exact final successor head, diff allowlist/forbidden list, event expression semantics, raw PR actual HEAD, unchanged canonical script, child -> `CI result` fail-closed propagation, and no bypass. Any product-head change after review invalidates the PASS.

Architecture does not perform this review.

## Protected merge_group gate

Only after exact-head independent review PASS may the downstream merge/test owner use protected merge queue.

Mandatory merge-group evidence:

- automatic `merge_group` workflow for current group SHA;
- canonical child actual worktree HEAD equals that current merge-group SHA, **not** the individual PR head;
- unchanged canonical script runs after group checkout and succeeds;
- same-group required `CI result` succeeds with child exact result `success`;
- no direct merge/bypass.

PR exact-head proof and merge-group current-combination proof are complementary and both required.

## Canonical main readback / downstream gate

After protected merge the downstream owner must read back exact canonical main and prove:

- accepted queue result is canonical;
- event-aware topology exists in `.github/workflows/ci.yml`;
- `merge_group` and fail-closed `CI result` dependency remain;
- canonical script is unchanged by this task;
- `app-version.json.iosBuildNumber == 29`;
- `mobile/ios/project.yml CURRENT_PROJECT_VERSION == 29`.

Even then, test release remains blocked until separately frozen applicable `IOS-FIXTURE-001`, `EVIDENCE-CONTRACT-001`, `EVIDENCE-JOURNEY-001` and other MAINSAFE prerequisites close. Stable release is a later independent gate.

## Historical provenance — do not mutate

- #2341 head `2241c856fb3da498ac99ade89007fe01dd335183` — historical version-only.
- #2342 head `570b874318bfe42406c6f46f51798baed8c89e48` — historical guard-only.
- #2343 head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa` / synthetic merge `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac` — failed bootstrap candidate.
- #2344 head `b60b8e2483333db21ca6cea068b7a1be9c0f4851` — records-only failed independent review.

All four remain provenance in this architecture round.

## Open-source/source-impact note

Official GitHub Actions semantics and official `actions/checkout@v5` documentation support explicit PR-head checkout using `github.event.pull_request.head.sha`; merge queue requires the separate `merge_group` event/current group commit. Existing `actions/checkout@v5` is retained under MIT; no new dependency or copied upstream implementation is authorized.

## Architecture handoff state

Records-only Architecture work is complete when #2340 diff is re-verified as project-record-only and this handoff is posted to #2340. Execution/review/merge/testing/release remain unstarted by this round.
