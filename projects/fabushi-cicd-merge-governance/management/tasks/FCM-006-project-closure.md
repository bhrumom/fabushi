# FCM-006 — Project closure and canonical verification

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-006
- **Status:** in-progress
- **Started:** 2026-08-22
- **Updated:** 2026-08-22

## Objective

Close FAB-P0003 only after the remaining implementation, live GitHub verification, project-folder migration, protected merge, and canonical-main evidence all agree.

## Acceptance criteria

1. Enterprise project folder contains every mandatory standard area or an explicit justified N/A.
2. FCM-002, FCM-004 and FCM-005 pass their objective acceptance checks.
3. PR #1999 required CI and dedicated governance/latency workflows succeed.
4. Sensitive workflow changes land through protected merge queue, not direct protected-main merge.
5. Canonical `main` is re-read after merge for observer workflow, release gates, CODEOWNERS and project records.
6. WBS, milestones, acceptance matrix, status report, changelog, risks/dependencies/actions and evidence indexes are synchronized.
7. `PROJECT.yaml` and README show final closed/completed state only after the above evidence exists.

## Current status

Implementation and scaffold migration are in progress on PR #1999. No completion claim is allowed before CI/merge/main verification.

## Next action

Complete static implementation, mark PR ready, inspect GitHub Actions, resolve all failures, merge through queue, then write final evidence/closure records and verify canonical `main`.
