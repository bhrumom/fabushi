# TFI-M6-MAINSAFE-001 post-main acceptance matrix — 2026-09-05

Authoritative accepted baseline: `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`.

## Accepted version/merge provenance

- Product PR #2345 final head `9c46c1d8f030be390995cc78f321aac0d96b7f44` merged through protected merge queue at `2026-09-05T02:29:10Z`.
- merge-group run `33939126976` on accepted group SHA `63e49b87...`: canonical-version job `101232897597` SUCCESS; required aggregate `CI result` job `101233054947` SUCCESS.
- `M6-PM-VEHC-A01` is therefore historical accepted provenance and is not reopened by the post-merge test failure.
- historical #2341/#2342/#2343/#2344 remain provenance only; this Architecture round does not close, merge, rebase, retarget or force-push them.

## Current atomic acceptance

| Stable Requirement | Stable Acceptance | Task | Current | Closure rule |
|---|---|---|---|---|
| `M6-PM-IOSF-R01` | `M6-PM-IOSF-A01` | `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001` | **FAIL ON ACCEPTED MAIN / READY FOR EXECUTION HANDOFF** | deterministic app-local bootstrap reaches `app-shell`; all canonical iOS UI tests green without weakening; exact-head review -> protected `merge_group` -> canonical readback |
| `M6-PM-EVC-R01` | `M6-PM-EVC-A01` | `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` | **GAP PROVEN / READY FOR EXECUTION HANDOFF** | pass+fail always-path evidence; exact identity manifest; labelled screenshots/full video/trace/report/native logs; 90d where permitted; review -> queue -> canonical readback |
| `M6-PM-EVJ-R01` | `M6-PM-EVJ-A01` | `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` | **MISSING OWNED JOURNEY / READY FOR EXECUTION HANDOFF** | packaged real-Host journey covers send + subscribe/unsubscribe + Community approval + unread + ownership identity; final proof only after EVC contract lands |
| — | `M6-PM-TEST-RELEASE-A01` | exact-main packaged/native test release | **BLOCKED** | all three stable acceptances above must first pass protected-main + canonical readback; then rerun from one accepted SHA |
| — | `M6-PM-STABLE-RELEASE-A01` | stable release | **BLOCKED** | test-release acceptance plus later release gates; never inferred from partial CI |

Legacy umbrella rows `M6-PM-A02`, `M6-PM-A03`, and `M6-PM-A04` map respectively to `M6-PM-IOSF-A01`, `M6-PM-EVC-A01`, and `M6-PM-EVJ-A01`; the stable IDs above are authoritative going forward.

## Accepted-main test facts

- exact-main Electron packaged run `33939200878`: SUCCESS.
- Native run `33939200888`: FAILURE.
- Native Android job live from the run job list is `101233115022`: SUCCESS. The previously reported `101233118496` endpoint returns 404 and is not retained as a verified job identity.
- Native iOS job `101233115134`: FAILURE at `SwiftUI unit and simulated user UI tests`.
- raw failure: `testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable` and `testMiniAppOpensAndClosesDedicatedWebMcpSurface` each fail/retry at `FabushiUITests.swift:137` because `app-shell` never appears after the helper's login/bootstrap waits; summary `Executed 5 tests, with 4 failures (0 unexpected)`; job exits 65.
- iOS `Upload iOS result bundle` succeeds after the test step, producing artifact `9961442374`; therefore failure is evidenced, not an unknown-log blocker.

## Non-substitution / fail-closed rules

- Three exact task paths remain 404 on accepted main; that records-delivery topology gap is distinct from the actual iOS runtime failure and must not be reported as its root cause.
- PR-head success never substitutes for protected merge-group evidence or canonical-main readback.
- skipped/neutral/manual/rerun/historical/different-SHA/other-platform evidence cannot satisfy an acceptance.
- a green functional test with missing required evidence identity/retention still fails `M6-PM-EVC-A01`.
- a semantic product failure exposed by `EVIDENCE-JOURNEY-001` returns to Architecture; the proof task may not modify product code.
