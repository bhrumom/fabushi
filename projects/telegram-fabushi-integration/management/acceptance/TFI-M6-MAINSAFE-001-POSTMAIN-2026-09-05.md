# TFI-M6-MAINSAFE-001 post-main acceptance matrix — 2026-09-05

Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`

| Acceptance ID | Task | Required evidence | Current | Closure rule |
|---|---|---|---|---|
| `M6-PM-A01` | `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` | one-file `mobile/ios/project.yml` 28->29; architecture/version guard green | FAIL | reviewed head -> protected queue -> canonical readback |
| `M6-PM-A02` | `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001` | deterministic `FABUSHI_FEATURE_HOST_TEST` bootstrap reaches login/authenticated shell; all current iOS UI identifiers green | FAIL | no assertion weakening; reviewed head -> protected queue -> canonical readback |
| `M6-PM-A03` | `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` | pass+fail always-upload; labelled screenshots; full video; trace/report/runtime/native logs; exact identity manifest/naming; target 90d | FAIL | verified passing and failing artifact families on current head, then protected merge/readback |
| `M6-PM-A04` | `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` | one packaged OWNERSHIP journey covering send, subscribe/unsubscribe, Community join approval, unread projection | MISSING | unweakened dedicated journey + evidence contract; semantic failure returns to architecture |
| `M6-PM-A05` | post-main test release | Linux/macOS/Windows packaged + Android/iOS native + ownership evidence on same accepted SHA | BLOCKED | fresh exact-main session only after A01-A04 applicable changes land |
| `M6-PM-A06` | stable release | test-release acceptance and independent downstream gates | BLOCKED | never inferred from partial CI success |

## Non-substitution rules

- macOS/Windows/Android successes from run set around `dbf22b...` are collateral failed-round evidence, not closure for A01-A05.
- Messaging Product Gate success does not substitute for native iOS or packaged user acceptance.
- #2339's incorrect iOS method/failure description does not substitute for original job log + exact-main source + xcresult evidence.
- Retry counts are not distinct source test-method counts.
- Artifact provenance must match exact SHA/platform/run/job/journey/time before it can satisfy a gate.

## Pipeline

For every atomic implementation task:

`execution exact head -> independent code review -> protected main merge queue -> canonical main readback`.

Only after all applicable tasks have landed may test-release open a new acceptance round using the newly read-back canonical SHA. Stable release remains a separate later gate.
