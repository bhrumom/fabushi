# TFI-M6-MAINSAFE-001 post-main acceptance matrix — 2026-09-05

Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`

| Acceptance ID | Task | Required evidence | Current | Closure rule |
|---|---|---|---|---|
| `M6-PM-A01` | `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` / #2341 | one-file `mobile/ios/project.yml` 28->29 **plus actual current-head canonical version script execution** | **BLOCKED / GUARD NOT RUN** | historical implementation round remains unreviewed/unmerged; replaced by VG-A01 then VR-A02 |
| `M6-PM-VG-A01` | `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` | `.github/workflows/ci.yml` only; exact-head `Canonical version contract` job executes existing script and is a failing dependency of protected required `CI result` | FROZEN | exact head logs -> independent review -> protected queue -> canonical readback |
| `M6-PM-VR-A02` | `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002` | fresh post-VG canonical base; one-file `mobile/ios/project.yml` 28->29; new version-contract job runs/not-skips and succeeds; same-head `CI result` succeeds | BLOCKED BY VG-A01 | reviewed head -> protected queue -> canonical readback |
| `M6-PM-A02` | `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001` | deterministic `FABUSHI_FEATURE_HOST_TEST` bootstrap reaches login/authenticated shell; all current iOS UI identifiers green | FAIL / NOT STARTED THIS ROUND | no assertion weakening; reviewed head -> protected queue -> canonical readback |
| `M6-PM-A03` | `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` | pass+fail always-upload; labelled screenshots; full video; trace/report/runtime/native logs; exact identity manifest/naming; target 90d | FAIL / NOT STARTED THIS ROUND | verified passing and failing artifact families on current head, then protected merge/readback |
| `M6-PM-A04` | `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` | one packaged OWNERSHIP journey covering send, subscribe/unsubscribe, Community join approval, unread projection | MISSING / NOT STARTED THIS ROUND | unweakened dedicated journey + evidence contract; semantic failure returns to architecture |
| `M6-PM-A05` | post-main test release | Linux/macOS/Windows packaged + Android/iOS native + ownership evidence on same accepted SHA | BLOCKED | fresh exact-main session only after all applicable atomic changes land |
| `M6-PM-A06` | stable release | test-release acceptance and independent downstream gates | BLOCKED | never inferred from partial CI success |

## Version-guard blocker acceptance facts

- #2341 final exact head is `2241c856fb3da498ac99ade89007fe01dd335183`, OPEN / UNMERGED.
- Its product semantic diff matches the old one-file allowlist; no evidence shows that value change itself failed.
- Exact-head CI, Native mobile, portfolio governance, Developer Fiat Commerce and Explicit automerge are all green, but none is the required canonical version-script proof.
- `Canonical architecture guardrails` is a retired-architecture workflow-command check; it does not execute `.github/scripts/assert-native-electron-canonical.sh`.
- Native mobile pull-request fast path explicitly skips heavy iOS/Android build, XcodeGen, Simulator/emulator and UI-test steps.
- ruleset `15857448` requires only `CI result`; existing `CI result` does not depend on a canonical version-contract job.

Therefore #2341's green workflow set cannot satisfy `M6-PM-A01`.

## Non-substitution rules

- A successful check with a similar name is not evidence for a different script; raw steps/logs must prove the canonical version script executed.
- A manually dispatched workflow, historical-head run, non-required Electron status or skipped Native mobile step does not substitute for the automatic required aggregate gate.
- macOS/Windows/Android successes from the earlier `dbf22b...` failed round are collateral evidence, not closure for A02-A05.
- Messaging Product Gate success does not substitute for native iOS or packaged user acceptance.
- #2339's incorrect iOS method/failure description does not substitute for original job log + exact-main source + xcresult evidence.
- Artifact provenance must match exact SHA/platform/run/job/journey/time before it can satisfy an evidence gate.

## Pipeline

Version repair now has a strict two-stage pipeline:

`VERSION-GUARD-CI-001 exact head -> independent code review -> protected main merge queue -> canonical readback -> VERSION-CONTRACT-002 fresh main-based exact head -> actual canonical version job + CI result -> independent code review -> protected queue -> canonical readback`.

Only after all applicable post-main tasks have landed may test-release open a new acceptance round using the newly read-back canonical SHA. Stable release remains a separate later gate.
