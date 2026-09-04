# TFI-M6-MAINSAFE-001 post-main acceptance matrix — 2026-09-05

Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`

| Acceptance ID | Task | Required evidence | Current | Closure rule |
|---|---|---|---|---|
| `M6-PM-A01` | `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` / #2341 | historical one-file `mobile/ios/project.yml` 28->29 plus actual current-head canonical version script execution | **HISTORICAL / BLOCKED / SUPERSEDED BY VB-A01** | retain provenance only; do not review/merge #2341 |
| `M6-PM-VG-A01` | `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` / #2342 | guard-only topology + exact-head canonical script + required `CI result` | **HISTORICAL / BLOCKED / TOPOLOGY PROVEN / SUPERSEDED BY VB-A01** | #2342 proves child/aggregate wiring but cannot pass canonical 29/28 drift |
| `M6-PM-VR-A02` | `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002` | formerly planned version-only repair after guard merge | **SUPERSEDED BEFORE EXECUTION** | do not start; repair folded into VB-A01 atomic bootstrap |
| `M6-PM-VB-A01` | `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001` | one fresh-main exact head with `.github/workflows/ci.yml` + `mobile/ios/project.yml` 28->29 only; canonical child executes/not-skips/succeeds; same-head `CI result` succeeds; independent review; merge-group child + `CI result` succeed; canonical readback proves 29/29 + topology + unchanged script | **FROZEN / NEXT-ONLY-EXECUTABLE** | exact PR head -> independent review -> protected merge queue `merge_group` -> canonical main readback |
| `M6-PM-A02` | `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001` | deterministic `FABUSHI_FEATURE_HOST_TEST` bootstrap reaches login/authenticated shell; all current iOS UI identifiers green | FAIL / NOT STARTED THIS ROUND | no assertion weakening; reviewed head -> protected queue -> canonical readback |
| `M6-PM-A03` | `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` | pass+fail always-upload; labelled screenshots; full video; trace/report/runtime/native logs; exact identity manifest/naming; target 90d | FAIL / NOT STARTED THIS ROUND | verified passing and failing artifact families on current head, then protected merge/readback |
| `M6-PM-A04` | `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` | one packaged OWNERSHIP journey covering send, subscribe/unsubscribe, Community join approval, unread projection | MISSING / NOT STARTED THIS ROUND | unweakened dedicated journey + evidence contract; semantic failure returns to architecture |
| `M6-PM-A05` | post-main test release | Linux/macOS/Windows packaged + Android/iOS native + ownership evidence on same accepted SHA | BLOCKED | fresh exact-main session only after bootstrap + all applicable atomic prerequisites land |
| `M6-PM-A06` | stable release | test-release acceptance and independent downstream gates | BLOCKED | never inferred from partial CI success |

## Bootstrap cycle acceptance facts

- #2341 final exact head `2241c856fb3da498ac99ade89007fe01dd335183` is OPEN / UNMERGED. Its only semantic product/config patch is `mobile/ios/project.yml CURRENT_PROJECT_VERSION 28 -> 29`, but its base lacks the frozen required canonical-version child in `CI result`.
- #2342 final exact head `570b874318bfe42406c6f46f51798baed8c89e48` is OPEN / UNMERGED. CI run `33928934236` proves `Canonical version contract` job `101203371687` executes the unchanged script and fails on canonical=29/project=28; `CI result` `101203476417` propagates that failure.
- live ruleset `15857448` requires exactly `CI result`, uses merge queue, and has no bypass actor.
- canonical main remains `app-version.json.iosBuildNumber=29` and `mobile/ios/project.yml CURRENT_PROJECT_VERSION=28` at this Architecture readback.

Therefore neither historical split PR is a mergeable closure path under the frozen truth requirements. `M6-PM-VB-A01` supersedes their execution order while retaining both as provenance.

## M6-PM-VB-A01 exact acceptance order

1. **Fresh baseline:** execution re-reads canonical main, ruleset and canonical script; if 29/28 or control-plane facts changed, stop to Architecture.
2. **Exact allowlist:** implementation/config changed files are exactly `.github/workflows/ci.yml` and `mobile/ios/project.yml` (`CURRENT_PROJECT_VERSION 28 -> 29`), plus task-specific TFI records only.
3. **Pull-request truth:** automatic CI on the final PR head executes `Canonical version contract`, not skipped; raw evidence shows `bash .github/scripts/assert-native-electron-canonical.sh`; child = SUCCESS; same-head `CI result` = SUCCESS.
4. **Independent review:** Code Review approves the exact final bootstrap head; Architecture does not substitute for review.
5. **Protected queue truth:** merge queue only; `merge_group` Actions execute the same child, child = SUCCESS, required `CI result` = SUCCESS; no direct merge/bypass.
6. **Canonical readback:** new main SHA is read back; `iosBuildNumber=29`, `CURRENT_PROJECT_VERSION=29`, accepted canonical-version child + aggregate topology are present, and the canonical script is unchanged.
7. **Downstream:** only after this may remaining MAINSAFE fixture/evidence prerequisites progress; test release remains blocked until all applicable prerequisites close; stable release remains later.

## Non-substitution rules

- A successful check with a similar name is not evidence for a different script; the actual canonical script execution must be visible.
- Manual `workflow_dispatch`, rerun-only, historical-head, different-SHA, optional/non-required status, or skipped/neutral child does not satisfy VB-A01.
- `Canonical architecture guardrails` is not the version-contract child.
- Native mobile PR fast-path success does not substitute for the canonical version child or later packaged/native acceptance.
- Pull-request head success does not substitute for required merge-group evidence.
- No ruleset/branch-protection waiver or bootstrap special case is permitted.

## Historical PR disposition

#2341 and #2342 remain historical blocked provenance. They must not be merged, rebased, retargeted or force-pushed into the replacement lineage. Only after a fresh-main bootstrap replacement PR exists and records both old exact heads and blocker comments `5547296411` / `5547556953` may the appropriate execution/product owner close the old PRs as superseded.

## Authoritative pipeline

`VERSION-BOOTSTRAP-001 fresh-main exact head -> automatic canonical child + CI result -> independent code review -> protected merge queue / merge_group canonical child + CI result -> canonical main readback -> remaining MAINSAFE prerequisites -> test release -> stable release`

The former `VERSION-GUARD-CI-001 -> VERSION-CONTRACT-002` two-stage pipeline is superseded by this same-head bootstrap because #2342 proved its first protected merge cannot self-bootstrap against the pre-existing canonical drift.
