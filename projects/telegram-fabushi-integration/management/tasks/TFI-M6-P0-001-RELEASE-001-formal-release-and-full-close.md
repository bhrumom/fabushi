# TFI-M6-P0-001-RELEASE-001 — formal release and FULL-CLOSE

## Identity
- Project: `FAB-P0001 / TFI`
- Parent: `TFI-M6-P0-001`
- Type: atomic formal-release closeout task
- Status: `BLOCKED_BY_E2E_001`

## Goal
Authorize and record formal release only after the exact canonical-main packaged journey and independent evidence/video review have passed, then mark TFI-M6-P0-001 FULL-CLOSE with complete lineage.

## Preconditions
All are mandatory:
1. formatter repair accepted on an exact reviewed head;
2. every required CI check passed on the accepted integration lineage;
3. protected canonical-main merge/readback accepted;
4. packaged E2E from the exact accepted canonical-main SHA passed;
5. complete screenshot/video/trace/report/log bundle exists with recorded retention;
6. independent code-review group reviewed the packaged evidence/video and returned PASS.

## Allowed scope
- existing approved formal release/publishing procedure for the already accepted canonical-main artifact;
- TFI release/evidence/project-record write-back.

## Forbidden scope
- no application/test/workflow feature changes;
- no release from an unmerged branch or different SHA;
- no bypass of packaged evidence review;
- no declaration of FULL-CLOSE before release provenance exists;
- no start of TFI-M6-P0-002 before this task's final state is recorded.

## Acceptance
- release artifact/version/channel resolves to the exact accepted canonical-main SHA used by E2E, or the repository's documented reproducible promotion lineage proves byte/source equivalence;
- release workflow/job IDs and final conclusions are recorded;
- formal publication succeeds on the intended channel;
- release notes/evidence do not overclaim unrelated M6/P0-002+ work;
- durable TFI records are updated append-only with the exact review, CI, merge, E2E, evidence-review, and release lineage;
- only then does the parent state become `FULL-CLOSE(TFI-M6-P0-001)`.

## Evidence
Record exact main SHA, package/release version, release/workflow IDs, timestamps, artifact identity/digests when available, destination/channel, E2E evidence reference, evidence-review verdict reference, and final project state.

## Rollback / risk
- Failed publication leaves the task `RELEASE-BLOCKED` and P0-001 not FULL-CLOSE.
- If the released artifact cannot be proven to descend from the accepted canonical-main SHA, stop distribution where the platform permits and rerun the approved promotion path with correct provenance.
- Any semantic hotfix required during release is a new implementation change and must return through code review, required CI, canonical-main merge and packaged E2E.

## Handoff
After FULL-CLOSE is durably recorded on canonical main, architecture may unblock **implementation** of `TFI-M6-P0-002` according to its own task contract. No other downstream task is implicitly accepted by this closure.
