# TFI-M6-P0-001-E2E-001 — canonical-main packaged journey evidence

## Identity
- Project: `FAB-P0001 / TFI`
- Parent: `TFI-M6-P0-001`
- Type: atomic Test/Release validation task
- Status: `BLOCKED_BY_MERGE_001`

## Goal
Validate P0-001 from an installable/packaged application built from the exact accepted canonical-main SHA, using the project-recorded simulated-user journey and preserving complete audit evidence.

## Preconditions
1. `TFI-M6-P0-001-MERGE-001` accepted.
2. Exact canonical-main SHA containing P0-001 is recorded and immutable for this evidence run.
3. Test/Release group uses the repository's approved packaged-app workflow; source-tree unit tests alone cannot satisfy this task.

## Allowed scope
- packaged build/install/run and simulated-user E2E on supported platform(s) required by the project handoff;
- evidence capture and TFI record write-back.

## Forbidden scope
- no application/test/workflow edits in this validation task;
- no testing an unmerged branch, local untracked build, or artifact whose source SHA cannot be proven;
- no substituting Atomic/unit/Electron CI for packaged user-journey evidence;
- no formal production release in this task.

## Required journey/evidence contract
Use `evidence/TFI-M6-P0-001/TEST-RELEASE-HANDOFF.md` and current acceptance records. At minimum preserve:
- exact canonical-main SHA, app/package version, platform, workflow run/job and artifact identity;
- journey/test ID and timestamps;
- step-by-step screenshots covering the whole journey;
- one complete, uncut video from install/open through final expected result;
- browser/app trace where applicable;
- HTML/native test report;
- platform/application logs sufficient to diagnose failure;
- pass/fail result for every step and correlation to the exact package.

Evidence upload must execute on both pass and fail (`always()`-equivalent behavior in the existing approved workflow). Retention target is 90 days. If GitHub policy or repository settings enforce a lower maximum, record the actual maximum and do not claim 90 days.

## Acceptance
- package provenance resolves to the exact accepted canonical-main SHA;
- full simulated-user journey passes without manual source patching or branch substitution;
- screenshots, complete video, trace/report/logs are all present and readable;
- evidence artifact retention is recorded;
- evidence is handed to an independent code-review session/group, which reviews the complete video and evidence bundle and returns an explicit evidence verdict.

This task is not accepted until that independent evidence/video review returns PASS.

## Rollback / risk
- Any user-journey failure returns P0-001 to `E2E-BLOCKED`; do not release.
- If the packaged artifact cannot be tied to exact main SHA, discard the run as non-authoritative and rerun with proven provenance.
- If GitHub retention is lower than target, record the limitation; do not fabricate retention.

## Handoff
On packaged journey PASS **and** independent evidence/video review PASS, hand to `TFI-M6-P0-001-RELEASE-001`. `TFI-M6-P0-002` remains blocked until formal FULL-CLOSE.
