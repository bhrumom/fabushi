# TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001 — historical guard-only attempt

- Project: `FAB-P0001 / TFI`
- Requirement ID: `M6-PM-VG-R01`
- Acceptance ID: `M6-PM-VG-A01`
- Status: `HISTORICAL / BLOCKED / TOPOLOGY-PROVEN / SUPERSEDED-BY-VERSION-BOOTSTRAP-001`
- Canonical baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Historical implementation PR: `#2342@570b874318bfe42406c6f46f51798baed8c89e48`, OPEN / UNMERGED
- Superseding task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Superseding Requirement / Acceptance: `M6-PM-VB-R01` / `M6-PM-VB-A01`

## Historical objective

This task attempted to wire the existing `.github/scripts/assert-native-electron-canonical.sh` into protected required `CI result` without changing the known iOS version value.

That topology objective was operationally proven by #2342, but the task cannot satisfy its own success acceptance on the current canonical baseline because the newly truthful child detects the pre-existing `iosBuildNumber=29` vs `CURRENT_PROJECT_VERSION=28` drift.

## Execution evidence that superseded the plan

On #2342 final exact head `570b874318bfe42406c6f46f51798baed8c89e48`, CI run `33928934236` shows:

- `Canonical version contract` job `101203371687` executed, not skipped;
- the job ran the unchanged canonical script and failed on `iOS build number drift: canonical=29 project=28`;
- `CI result` job `101203476417` observed the child failure and failed;
- `Canonical architecture guardrails` succeeded separately and is not substituted for version evidence.

This proves the child + aggregate wiring works. It also proves a guard-only first protected merge cannot self-bootstrap from this canonical drift.

## Historical implementation allowlist

The old task allowed `.github/workflows/ci.yml` only, plus TFI records. #2342 stayed within that implementation boundary.

No evidence establishes a need to modify the canonical assertion script, ruleset, branch protection, another workflow, app-version authority, application/test source, Cargo/dependencies, or release logic.

## Current disposition

Do **not** continue, review, queue, merge, rebase, retarget, or force-push #2342 as the replacement path. Its exact head and failure are durable topology/provenance evidence.

The old planned successor `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002` is also superseded before execution. The only next executable task is `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`, which combines the proven topology with the one-value iOS mirror repair on one fresh-main exact head.

Only after a fresh-main replacement bootstrap PR exists and records provenance to #2342 exact head, #2341 exact head, and blocker comments `5547556953` / `5547296411` may the appropriate execution/product owner close #2342 as superseded. Architecture does not close it in this round.

## Historical non-bypass rules retained

- no edit to `.github/scripts/assert-native-electron-canonical.sh`;
- no weakening/skipping/special-casing the child;
- no manual `workflow_dispatch`/rerun/different-head evidence as closure;
- no ruleset or required-status bypass;
- no local build/test as acceptance substitution.

## Superseding evidence

- `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md`
- `projects/telegram-fabushi-integration/decisions/ADR-0013-version-bootstrap-atomic-required-gate.md`
- `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001.md`
