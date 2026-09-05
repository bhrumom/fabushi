# M6 MAINSAFE post-merge blocker — Architecture replan and Execution handoff

- Project: `FAB-P0001 / TFI`
- Architecture PR: `#2340` (records-only; execution must re-read its latest head before starting)
- Accepted canonical baseline observed: `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`
- Accepted product PR: `#2345` head `9c46c1d8f030be390995cc78f321aac0d96b7f44`, merged via protected queue at `2026-09-05T02:29:10Z`
- Architecture scope: records/task contracts only. No implementation/review/merge/test-release/stable-release is performed here.

This record **supersedes earlier MAINSAFE sections that call the pre-#2345 version/checkout blocker the "authoritative latest"**. Those sections remain provenance. Current truth is the accepted-main post-merge failure/evidence gap documented here and in `evidence/TFI-M6-MAINSAFE-001/POSTMERGE-BLOCKER-RAW-EVIDENCE-2026-09-05.md`.

## Current blocker classification

1. **Actual accepted-main iOS failure:** Native run `33939200888`, iOS job `101233115134`, current UI tests fail at `FabushiUITests.swift:137` because `app-shell` is not reached; raw job log and xcresult artifact `9961442374` are available.
2. **Evidence-contract gap:** current Native evidence retention is configured for 14 days; evidence identity/always-path contract is not yet uniformly accepted across packaged/native paths.
3. **Owned packaged journey gap:** no single dedicated packaged OWNERSHIP journey is accepted for send + subscribe/unsubscribe + Community approval + unread + ownership identity.
4. **Records-delivery topology gap:** the three Architecture task files exist on #2340 but are 404 on accepted `main@63e49b87...`. This is separate from item 1.

## Frozen stable tasks

| Task | Requirement | Acceptance | Execution relationship |
|---|---|---|---|
| `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001` | `M6-PM-IOSF-R01` | `M6-PM-IOSF-A01` | may execute in parallel with EVC |
| `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` | `M6-PM-EVC-R01` | `M6-PM-EVC-A01` | may execute in parallel with IOSF; must land before EVJ final acceptance |
| `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` | `M6-PM-EVJ-R01` | `M6-PM-EVJ-A01` | authoring may parallelize; final proof/closure waits for EVC canonical readback |

No duplicate task is created. Each task's exact allowlist and forbidden files are authoritative in its own task file.

## Dependency graph / parallel boundary

```text
accepted main 63e49b87...
   |-- IOS-FIXTURE-001 --------------------------> review -> protected merge_group -> canonical readback --\
   |-- EVIDENCE-CONTRACT-001 --------------------> review -> protected merge_group -> canonical readback ----+--> fresh exact-main Test Release
   `-- EVIDENCE-JOURNEY-001 authoring (parallel) ---- waits for EVC canonical readback -> final proof -> review -> merge_group -> readback --/
```

The three implementations must not share a broad catch-all PR. Each is independently reviewable and fail-closed. If execution groups run concurrently, overlapping files are prohibited; EVC owns workflow/evidence-plumbing files and EVJ owns only its packaged E2E spec/fixture.

## Execution entry

For each task, the Execution group must:

1. in its existing single project-group tab, re-read live canonical main; expected starting observation is `63e49b87...`; if main advanced, record the new accepted SHA and re-check task assumptions before editing;
2. read the exact task file from latest #2340 head plus this handoff and raw-evidence record;
3. create/use an atomic implementation lineage from canonical main, not from old #2341/#2342/#2343/#2344 or product #2345 branch;
4. stay inside the task allowlist; any forbidden-file need is `SCOPE-EXPANSION-REQUIRED` and returns to Architecture;
5. use GitHub Actions for heavy verification; no local heavy build/test is authorized by this architecture record.

## Code Review gate — each task independently

- review exact final execution head and exact diff;
- confirm allowlist/forbidden compliance and no assertion/evidence weakening;
- verify current-head Actions/evidence and stable Requirement/Acceptance IDs;
- only a review PASS on that exact head may authorize protected merge queue.

## Protected merge-group / canonical-main gate — each task independently

- use protected merge queue only; no direct/bypass merge;
- required `merge_group` checks must run and succeed on the queue group identity;
- after merge, re-read canonical main and verify the reviewed change is present at the accepted SHA;
- skipped/neutral/manual/rerun/historical/different-SHA evidence fails closed.

## Test-release / stable-release gate

Test Release stays blocked until all of `M6-PM-IOSF-A01`, `M6-PM-EVC-A01`, `M6-PM-EVJ-A01` have protected-main + canonical-readback proof. Then one fresh exact-main session must run packaged Electron and Native Android/iOS from one accepted SHA and bind evidence to run/job/platform/journey identity. Stable Release remains a later independent gate and is not authorized here.

## Evidence contract for the later test-release

Required family, success **and** failure where produced: meaningful-step screenshots, complete dedicated-journey video, Playwright trace + HTML/report, Electron runtime/Host logs, Android reports/logs, iOS raw log + xcresult. Manifest binds packaged app identity/version, platform, exact main SHA, workflow/run, job, stable journey/test ID, UTC timestamp, format/version and result. Retain 90 days where repository/org/platform permits; record any verified lower cap explicitly.

## Rollback / recovery rule

No force-push/rebase/retarget/old-PR reuse. If one atomic task lands and creates a regression, rollback is a **new reviewed protected-main revert/fix PR limited to that task's owned change**, preserving accepted evidence and provenance. Do not roll back already-accepted #2345 version/checkout lineage merely because a downstream task fails. Test/stable release remains blocked until the new canonical state is revalidated.

## Provenance that must remain untouched

- #2341 historical version-only head `2241c856...`;
- #2342 historical guard-only head `570b8743...`;
- #2343 historical review-failed bootstrap head `bf62cd97...`;
- #2344 historical review record head `b60b8e24...`;
- #2345 accepted product head `9c46c1d8...` -> canonical `63e49b87...`.

Testing group's isolated records branch `records/tfi-m6-mainsafe-001-test-release-20260905` remains head `6d45a60d...`, changes only `management/07-变更日志.md`, and has no associated PR at live readback. It is provenance; do not silently treat it as canonical project delivery.

## Architecture handoff state

After this records-only commit, #2340 comment handoff and final diff/head/readback audit are still required. Execution is authorized only after that comment is posted and re-read successfully.
