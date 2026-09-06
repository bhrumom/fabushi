# 84 — TFI-M6-MAINSAFE-001 VERSION-BOOTSTRAP 循环诊断与原子重规划状态与验收 — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Canonical baseline readback: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture PR: `#2340`
- Historical version-only PR: `#2341@2241c856fb3da498ac99ade89007fe01dd335183`
- Historical guard-only PR: `#2342@570b874318bfe42406c6f46f51798baed8c89e48`
- New Task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Requirement / Acceptance: `M6-PM-VB-R01` / `M6-PM-VB-A01`
- Architecture state: `ARCHITECTURE-VERSION-BOOTSTRAP-CYCLE-DIAGNOSED / ATOMIC-TASKS-REPLANNED`
- Downstream state: implementation not started by Architecture; code review / protected merge / test release / stable release PAUSED.

## Diagnosed cycle

| Half | Live evidence | Result |
|---|---|---|
| Version-only | #2341 exact patch is `mobile/ios/project.yml CURRENT_PROJECT_VERSION 28 -> 29`, but its base lacks the required canonical-version child in `CI result` | cannot satisfy frozen same-head guard evidence |
| Guard-only | #2342 CI run `33928934236`; child `101203371687` executes and fails on canonical=29/project=28; `CI result` `101203476417` fails | topology is correct, but guard-only cannot self-bootstrap through protected main |
| Protected control plane | ruleset `15857448` requires `CI result`, merge queue active, no bypass actors | failing guard-only PR cannot be accepted by bypass |

The blocker is therefore a **protected-main bootstrap dependency cycle**, not a demonstrated defect in the canonical assertion script and not a reason to weaken required checks.

## Replanned atomic task

`TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`

Exact implementation/config allowlist:

- `.github/workflows/ci.yml`
- `mobile/ios/project.yml` — only `CURRENT_PROJECT_VERSION: 28 -> 29`
- plus task-specific records under `projects/telegram-fabushi-integration/**`

No canonical script, ruleset, branch protection, other workflow, app-version.json, Android, application/test source, Cargo/dependency, release or tag changes.

## Acceptance order

1. Execution starts from freshly re-read canonical main and revalidates 29/28 drift + current ruleset/script facts.
2. One replacement PR carries both allowed implementation/config changes on one exact head.
3. Automatic pull-request CI must execute `Canonical version contract` (not skipped), actually run `bash .github/scripts/assert-native-electron-canonical.sh`, and succeed; same-head `CI result` must succeed.
4. Independent Code Review approves that exact final head.
5. Protected merge queue only. `merge_group` must run the same canonical child, child must execute/succeed, and required `CI result` must succeed.
6. Canonical main readback must prove `iosBuildNumber=29`, `CURRENT_PROJECT_VERSION=29`, accepted CI topology present, canonical script unchanged.
7. Only after that readback may remaining MAINSAFE post-main prerequisites progress; test release remains blocked until those separately frozen prerequisites are satisfied.

## Historical task/PR disposition

- `VERSION-CONTRACT-001` / #2341: historical blocked implementation; do not review/merge/rebase/retarget/force-push.
- `VERSION-GUARD-CI-001` / #2342: historical blocked guard-only implementation; topology evidence is reusable as diagnosis, PR itself is not mergeable replacement lineage.
- `VERSION-CONTRACT-002`: superseded before execution by the atomic bootstrap; do not start it.
- Only after a fresh-main bootstrap replacement PR exists and cites both old exact heads + blocker comments may the appropriate execution/product owner close #2341/#2342 as superseded.

## Stop policy

Any changed baseline, need for a third implementation/config file, canonical-script change, skipped/missing child, same-head failure after the allowed pair, merge-group absence/failure, ruleset change, or newly exposed semantic defect returns to Architecture. No scope expansion or guard bypass is authorized.

## Downstream pause

Architecture does not create the replacement product/CI PR, does not perform code review, does not enqueue/merge, and does not start test/stable release. The only next executable task is `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`.