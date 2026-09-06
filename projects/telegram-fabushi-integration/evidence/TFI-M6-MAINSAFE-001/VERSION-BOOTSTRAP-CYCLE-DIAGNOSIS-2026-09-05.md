# TFI-M6-MAINSAFE-001 version bootstrap dependency-cycle diagnosis — 2026-09-05

## Verdict

`ARCHITECTURE-VERSION-BOOTSTRAP-CYCLE-DIAGNOSED / ATOMIC-TASKS-REPLANNED`

The earlier sequential plan (`guard-only -> merge -> version-only`) is not mergeable from the current canonical baseline. The smallest truthful bootstrap is a single fresh-main exact-head transaction containing only the proven CI topology change and the proven iOS build-number mirror repair, plus TFI records.

New executable task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`.

## Live canonical baseline

GitHub readback on 2026-09-05:

- repository: `bhrumom/fabushi`
- canonical branch: `main`
- exact SHA: `dbf22b467d35c8af2a074896c355a41993c8c191`
- project: `FAB-P0001 / TFI`
- authoritative project path: `projects/telegram-fabushi-integration/`
- `app-version.json`: `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`
- `mobile/ios/project.yml`: `MARKETING_VERSION=1.2.22`, `CURRENT_PROJECT_VERSION=28`
- canonical assertion implementation: `.github/scripts/assert-native-electron-canonical.sh`; it rejects `CURRENT_PROJECT_VERSION != app-version.json.iosBuildNumber`.

## PR fact table

| PR | Role | Base | Exact head | State | Relevant changed files / finding |
|---|---|---|---|---|---|
| #2340 | records-only Architecture | `main@dbf22b...` | pre-replan `a514a396cc7f6c1a3a622aba54906d33c00c3e4b` | OPEN / UNMERGED | 17 files, all under `projects/telegram-fabushi-integration/**`; reused by this round |
| #2341 | historical version-only implementation | `dbf22b...` | `2241c856fb3da498ac99ade89007fe01dd335183` | OPEN / UNMERGED | only semantic product/config patch is `mobile/ios/project.yml` `CURRENT_PROJECT_VERSION 28 -> 29`; required canonical version script did not run as protected aggregate evidence |
| #2342 | historical guard-only implementation | `dbf22b...` | `570b874318bfe42406c6f46f51798baed8c89e48` | OPEN / UNMERGED | `.github/workflows/ci.yml` + four TFI records; topology worked but truthfully failed on pre-existing 29/28 drift |

Historical handoffs:

- #2341 execution blocker: comment `5547296411`.
- previous architecture handoff on #2341: comment `5547466413`.
- #2342 execution blocker / architecture return: comment `5547556953`.

No old PR is merged, rebased, retargeted, force-pushed, reviewed, or closed by this Architecture round.

## #2342 Actions proof — topology works, value prevents self-bootstrap

Final exact-head CI run: `33928934236`, event `pull_request`, head `570b874318bfe42406c6f46f51798baed8c89e48`, conclusion `failure`.

Observed jobs:

- `Classify CI changes` / `101203371495`: SUCCESS.
- `Canonical version contract` / `101203371687`: **FAILURE**, with actual checkout and `Execute canonical native/Electron version contract` step executed, not skipped.
- `Canonical architecture guardrails` / `101203450496`: SUCCESS and correctly distinct from version evidence.
- Frontend / Worker / MCP / Electron Feature Host: SKIPPED under the existing classifier.
- `CI result` / `101203476417`: **FAILURE**.

The durable execution record and PR blocker comment preserve the raw-log observations:

- `Run bash .github/scripts/assert-native-electron-canonical.sh`
- `iOS build number drift: canonical=29 project=28`
- aggregate `version_contract_result="failure"`
- `Canonical version contract failed: failure`

Interpretation: this is not a wiring failure. It proves the new child actually runs and the protected aggregate actually propagates failure. A guard-only PR based on the current drift therefore cannot satisfy its own success acceptance without changing the version mirror.

## #2341 proof — patch shape is correct but topology is absent

PR #2341 changed-files contain exactly one semantic product/config file plus four task records. The product patch is exactly:

`mobile/ios/project.yml: CURRENT_PROJECT_VERSION 28 -> 29`.

Its green workflows are valid only for what they executed. The existing `Canonical architecture guardrails` job checks retired Flutter/Tauri/Capacitor workflow commands and does not run `.github/scripts/assert-native-electron-canonical.sh`. Native mobile PR fast path likewise is not the required canonical-version script proof. The protected required aggregate on #2341's base had no canonical-version child.

Thus the version-only PR cannot satisfy the frozen requirement that the canonical script execute automatically on the accepted exact head as part of required `CI result`.

## Protected-main control-plane proof

Live ruleset `15857448` (`main-merge-queue`) is active for `refs/heads/main` and contains:

- merge queue, squash merge, ALLGREEN grouping;
- required status checks: exactly `CI result`;
- no bypass actors; current user bypass is `never`.

This makes the aggregate topology material. A different optional status, a manual workflow, or a historical job cannot stand in for `CI result`.

The #2342 workflow already listens to `merge_group: checks_requested` and makes `CI result` depend on `canonical-version-contract`. That shape must be preserved by the replacement bootstrap task.

## Dependency-cycle proof

Let `G` be the guard topology and `V` the iOS 28 -> 29 repair.

- Current main has neither `G` nor `V` and is internally 29/28 drifted.
- PR `G` only (#2342): the newly truthful guard executes and rejects the current drift; required aggregate is red, so `G` cannot reach protected main.
- PR `V` only (#2341): the drift is repaired on the PR head, but the base lacks `G`; the required aggregate cannot prove the canonical script ran, so the frozen acceptance is unsatisfied.
- Therefore the former dependency order `G -> V` is cyclic from the protected-merge perspective.
- PR `G + V` on one fresh-main exact head removes the known drift at the same time the required child becomes authoritative. The child can execute truthfully and succeed; the same-head `CI result` can then satisfy the protected required status. The merge queue can repeat the same topology on `merge_group`.

No evidence-supported smaller protected transaction exists under the stated constraints.

## Chosen bootstrap boundary

`TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`

Implementation/config allowlist:

- `.github/workflows/ci.yml`
- `mobile/ios/project.yml` — only `CURRENT_PROJECT_VERSION 28 -> 29`
- task-specific records under `projects/telegram-fabushi-integration/**`

Everything else is prohibited, including canonical script, ruleset/branch protection, other workflows, app-version.json, Android, product/test source, Cargo/dependencies and release controls.

## Rejected alternatives

1. **Merge #2342 despite failure** — rejected: violates active required `CI result`; no bypass actor exists.
2. **Merge/review #2341 first** — rejected: would accept a version repair without the frozen required canonical-script topology.
3. **Manual `workflow_dispatch` / rerun** — rejected: diagnostic only; does not install the durable required topology and is not same protected merge-group evidence.
4. **Allow `skipped`/neutral child** — rejected: hides the exact contract this task exists to enforce. GitHub may generally treat skipped/neutral checks as successful in some dependency/required-check semantics, so the repository aggregate must deliberately require exact child `success`.
5. **Special-case the topology PR** — rejected: makes bootstrap untruthful and creates a durable bypass surface.
6. **Change ruleset/branch protection** — rejected: broader control-plane change, unnecessary and outside scope.
7. **Duplicate version comparisons into YAML** — rejected: violates single-authority design; unchanged script remains the source.
8. **Edit canonical script** — rejected: no script defect is demonstrated.

## Official/open-source-first evidence

Official GitHub documentation reviewed 2026-09-05:

- Workflow syntax / `jobs.<job_id>.needs`: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- `needs.<job_id>.result` context: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts
- Required status checks and latest-SHA / merge-queue guidance: https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks
- Ruleset required-status semantics: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets

Adopted semantics:

- explicit direct job dependency via `needs`;
- aggregate reads the child result and requires exact success;
- required status must be reported on the relevant latest PR/merge-group head;
- merge-queue Actions required checks must listen to the separate `merge_group` event.

Open-source action provenance:

- `actions/checkout` — MIT License; already used by repository; no new dependency and no code copied.
- `actions/github-script` — MIT License; already used by the classifier; no new dependency and no upstream code copied.

Repository precedent:

- #2342 operationally proves the child + aggregate wiring.
- Fabushi FCM `ADR-0005-extreme-throughput-fail-fast.md` requires preserving aggregate `CI result`, merge queue and cheap deterministic PR gates.

## Historical PR disposition

#2341 and #2342 remain open as blocked historical provenance while Architecture finishes this writeback. Only after a fresh-main replacement bootstrap PR is created and records exact provenance to both old heads/comments may the appropriate execution/product owner close them as superseded. They must never be merged as shortcuts and must not be rebased/retargeted/force-pushed into replacement lineage.

## Downstream pause

This diagnosis authorizes no implementation in Architecture, no code review, no merge, no test release, and no stable release.

The next and only executable task after Architecture handoff is `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`. Test release remains additionally dependent on the separately frozen MAINSAFE iOS fixture/evidence tasks after bootstrap merges and canonical main is read back.