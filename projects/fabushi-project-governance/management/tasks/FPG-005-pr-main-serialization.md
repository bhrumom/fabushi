# FPG-005 — PR-to-main serialization gate

- Project ID: `FAB-P0002`
- Project Key: `FPG`
- Task ID: `FPG-005`
- Source: `source/2026-08-24-FPG-005-pr-main-serialization.md`
- Status: `in-progress`
- Started: `2026-08-24`
- Updated: `2026-08-24`
- Completed: pending

## Objective

Make repository task execution serial at the PR completion boundary: the current task PR must pass required gates, merge to canonical `main`, and be verified on `main` before another independent PR task may begin or advance.

## In scope

- root `AGENTS.md` hard gate;
- durable source requirement;
- WBS and acceptance traceability;
- status/changelog evidence;
- protected PR merge and canonical-main readback.

## Out of scope

- changing GitHub branch protection settings;
- implementing a new CI bot to auto-block PR creation;
- emergency incident policy redesign.

## Acceptance criteria

1. `AGENTS.md` explicitly prohibits starting/advancing the next independent PR task while the current task PR remains unmerged.
2. Completion sequence is explicit: acceptance checks -> required review/CI -> protected merge -> canonical-main verification -> next PR task.
3. Pending/failed current PR remains `in-progress`/`blocked`/`failed` rather than being bypassed.
4. Narrow emergency exception requires explicit authorization/policy and durable record.
5. This governance change itself is merged to `main` and verified there before FPG-005 is marked passed.

## Verification

- GitHub PR diff review;
- required GitHub Actions checks;
- protected merge result;
- post-merge fetch of canonical `main` `AGENTS.md` and project records.

## Branch / commit / PR

- Branch: `governance/fpg-005-pr-main-serialization`
- Initial source commit: `6209e77a50ebfc889a2234ec3fb53df3169e7d6b`
- AGENTS commit: `de50a82a734d2fb49ec0538c46e8b409c29d41c6`
- PR: pending

## Implementation summary

Added root `AGENTS.md` section `1B. CRITICAL: PR-to-main serialization gate` and reinforced the same constraint in implementation/completion rules. Captured the user requirement as a durable source record.

## Evidence

Pending PR/check/merge/main evidence.

## Blockers / risks

- Existing unrelated open PRs predate this rule and are not retroactively rewritten by this task.
- This task itself must not be marked complete before merge + main verification.

## Next action

Update governance WBS/acceptance/status/changelog, open PR, inspect required checks, merge, and verify canonical `main`.
