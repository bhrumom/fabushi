# Runbook — MAINSAFE post-merge blocker / test-release fail-closed

## Trigger

Use this runbook when accepted canonical main has passed protected product merge but exact-main packaged/native acceptance or evidence provenance fails.

Current recorded instance: accepted `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`, Native iOS run/job `33939200888 / 101233115134`.

## Triage order

1. Read canonical main and accepted product/merge-group identities.
2. Separate real runtime/test failure from records-delivery topology. A missing task file on main is not itself a runtime root cause.
3. Read raw failing job log and produced artifacts before classifying root cause.
4. Verify artifact exact SHA/run/job/platform/test identity and retention.
5. Freeze the smallest independent atomic task; do not broaden a proof/evidence task into product repair.

## Release gate

For the current MAINSAFE instance, Test Release is blocked until:

- `M6-PM-IOSF-A01` PASS on protected canonical main;
- `M6-PM-EVC-A01` PASS on protected canonical main;
- `M6-PM-EVJ-A01` PASS on protected canonical main;
- one fresh exact-main packaged/native run then passes from one accepted SHA with the required evidence family.

Stable Release is a later gate and cannot be inferred from partial CI.

## Rollback / recovery

- never force-push, rebase or retarget an accepted/historical PR to erase evidence;
- never reuse #2341/#2342/#2343/#2344 as a successor implementation lineage;
- if an atomic successor lands and regresses canonical main, use a new independently reviewed protected-main revert/fix PR limited to that task's owned files;
- keep failed raw logs/artifacts/provenance; a rollback does not erase the failed acceptance record;
- do not revert accepted #2345 version/checkout work solely because the later iOS fixture/evidence/journey acceptance is blocked.

## Evidence minimum

On success and failure where produced: labelled screenshots, complete dedicated-journey video, trace, HTML/report, runtime/native logs, Android reports, iOS xcresult/raw log, plus manifest binding packaged app/platform/exact SHA/run/job/stable journey/test ID/result/timestamp. Target retention 90 days where permitted.
