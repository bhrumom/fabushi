# 2026-09-05 — M6 MAINSAFE VERSION exact-head 独立代码审查交接

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement / Acceptance: `M6-PM-VEHC-R01` / `M6-PM-VEHC-A01`
- Product PR: `#2345`
- Reviewed base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Reviewed exact final product head: `9c46c1d8f030be390995cc78f321aac0d96b7f44`
- Architecture source: `#2340@9da26347e6de37a6576198b0f09d36928cbb1b0a`
- Execution handoff comment: `5548608629`
- Review task record: `management/tasks/TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001-REVIEW-001.md`
- Review evidence: `evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-REVIEW-2026-09-05.md`
- Result: `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`

## Independent review conclusion

The exact unchanged #2345 final head satisfies the PR-stage hard gates frozen by `M6-PM-VEHC-A01`.

- Final diff: exactly `.github/workflows/ci.yml`, `mobile/ios/project.yml`, and task-specific `projects/telegram-fabushi-integration/**` records; no forbidden product/config surface is changed.
- `mobile/ios/project.yml`: only semantic value change is `CURRENT_PROJECT_VERSION 28 -> 29`, aligned with unchanged canonical `app-version.json.iosBuildNumber=29`.
- Canonical script: `.github/scripts/assert-native-electron-canonical.sh` is unchanged; base/head blob is `932693655177fe8a7192b0e350fbb2cc7f80ec05`.
- PR checkout semantics: `pull_request` selects `github.event.pull_request.head.sha`; `merge_group` remains bound to the current group SHA; non-PR/non-group events retain current `github.sha`.
- Fail-closed identity: actual `git rev-parse HEAD` must equal the event-specific expected SHA before the unchanged canonical script executes.
- Fail-closed aggregate: `CI result` directly needs the canonical child and rejects any child result other than exact `success`.

## Decisive raw evidence

Automatic `pull_request` CI run `33937479501`, attempt 1, is attached to exact product head `9c46c1d8f030be390995cc78f321aac0d96b7f44`.

Canonical job `101228105692` raw log proves:

1. checkout input ref is exact `9c46c1d8f030be390995cc78f321aac0d96b7f44`;
2. checkout executes that exact SHA and reports `HEAD is now at 9c46c1d`;
3. `git log -1 --format=%H` returns the full same SHA;
4. the explicit `git rev-parse HEAD` assertion prints expected and actual as the same `9c46...` SHA;
5. only then does `bash .github/scripts/assert-native-electron-canonical.sh` execute and succeed.

Same-run required aggregate job `101228236513` raw log proves `version_contract_result="success"` and a non-success value exits non-zero. The job and run conclude SUCCESS.

All observed automatic final-head pull-request workflows are SUCCESS: Project portfolio governance `33937479392`, Native mobile quality gate `33937479393`, Developer Fiat Commerce `33937479394`, Explicit automerge `33937479397`, Computer control security gate `33937479417`, and CI `33937479501`.

## Findings

No blocker, high, or medium finding was identified.

Informational only: repository-existing `actions/checkout@v5` uses a mutable major tag rather than a fully pinned commit SHA. This task introduces no new action/dependency; the reviewed run resolved it to `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`. Full-SHA action pinning is a separately scoped supply-chain hardening opportunity and is not an acceptance defect for this frozen task.

## Provenance

#2341, #2342, #2343 and #2344 remain OPEN / UNMERGED provenance only. The failed #2343 synthetic merge `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac` is not reused as acceptance evidence. This review does not mutate any historical PR.

## Authorization boundary

This PASS authorizes only the next protected canonical-main merge gate for the exact unchanged `#2345@9c46c1d8f030be390995cc78f321aac0d96b7f44`.

The review group does not enter merge queue, merge, test release, or stable release. Any later product-head commit invalidates this PASS and requires fresh automatic exact-head evidence plus a new independent review.

The next owner is the test-release project group, which must first run the protected merge-queue gate. The resulting `merge_group` must independently prove actual worktree HEAD equals the current group SHA, then the unchanged canonical script and same-group required `CI result` must succeed. Canonical `main` must be read back after protected merge. Packaged test release and stable release remain blocked by their separate downstream prerequisites.
