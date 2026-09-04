# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002 — reapply iOS build mirror after required guard lands

- Project: `FAB-P0001 / TFI`
- Requirement ID: `M6-PM-VR-R02`
- Acceptance ID: `M6-PM-VR-A02`
- Status: `FROZEN / BLOCKED-BY-VERSION-GUARD-CI-001`
- Predecessor implementation fact: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` / PR #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`
- Hard dependency: `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` must be independently reviewed, protected-merged, and read back from canonical `main` before this task starts.

## Goal

From the new canonical main that contains the required version-guard CI topology, create a fresh main-based version-contract implementation that changes exactly the stale XcodeGen build-number mirror from 28 to 29 and proves the authoritative canonical version script actually ran on that exact product head.

This is a replacement execution task, not continuation/review of #2341.

## Why a new task/PR is required

PR #2341 proves the minimal product patch shape but cannot satisfy the frozen current-head guard acceptance because its base lacks the required CI topology. Architecture will not rewrite, rebase, merge or close #2341. After `VERSION-GUARD-CI-001` lands, execution must branch from the newly read-back canonical main so the first replacement product PR is natively subject to the repaired required `CI result` topology.

## Exact product allowlist

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29` only.

Permitted task/evidence/status/changelog writes remain limited to `projects/telegram-fabushi-integration/**`.

## Out of scope / prohibited

- no `app-version.json` edit;
- no Android version/code change;
- no desktop/mobile package version edit;
- no application or test source edit;
- no `.github/**` edit — CI topology belongs exclusively to `VERSION-GUARD-CI-001`;
- no Cargo/dependency/version-generation/release/tag change;
- no assertion relaxation or evidence substitution;
- no local build/test;
- do not reuse #2341 branch/head as the replacement implementation lineage.

If the fresh canonical main no longer has `app-version.json.iosBuildNumber=29` with `mobile/ios/project.yml CURRENT_PROJECT_VERSION=28`, STOP and return to architecture rather than forcing this planned patch.

## GitHub Actions exact-head acceptance

On the replacement product PR exact head:

1. changed product/config diff is exactly one semantic value in `mobile/ios/project.yml`, 28 -> 29;
2. repository CI automatically selects the new `Canonical version contract` child job from `VERSION-GUARD-CI-001`;
3. that job is **executed, not skipped**, and raw steps/logs show `bash .github/scripts/assert-native-electron-canonical.sh` actually runs on the PR checkout;
4. the canonical version job succeeds and protected required `CI result` succeeds on the same exact head;
5. every other automatically applicable current-head check is green; skipped heavyweight native PR steps are recorded as skipped and are not substituted for post-main acceptance;
6. independent code review approves the exact product head;
7. protected merge queue only; no direct merge/bypass;
8. canonical main readback proves both `app-version.json.iosBuildNumber=29` and `mobile/ios/project.yml CURRENT_PROJECT_VERSION=29`, and confirms the accepted product SHA lineage.

## Post-main prerequisite

After protected merge and canonical readback, this task still does not authorize test or stable release by itself. The broader M6 post-main acceptance remains blocked by the separately frozen `IOS-FIXTURE-001`, `EVIDENCE-CONTRACT-001`, and `EVIDENCE-JOURNEY-001`; those tasks are not started by this replanning round.

## #2341 supersession condition

Keep #2341 OPEN / BLOCKED / UNREVIEWED during `VERSION-GUARD-CI-001`. Once this replacement task creates a fresh main-based product PR and records its exact provenance, the appropriate execution/product owner may close #2341 as superseded. #2341 must never be merged as a shortcut around the repaired required guard.
