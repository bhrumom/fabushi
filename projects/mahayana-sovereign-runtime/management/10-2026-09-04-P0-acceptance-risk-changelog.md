# MSR P0 acceptance / risk / dependency / changelog — FAB-ARCH-P0-20260904

## Dependency completion rule
For MSR-210/211, every prerequisite is complete only with contract acceptance + independent `REVIEW-PASS` + protected canonical-main merge + required CI + installable/packaged E2E and Release evidence bound to the prerequisite's exact accepted canonical-main SHA. Anything less remains BLOCKED/contract-only.

## Gates
- MSR-210: `FULL-CLOSE(MSR-201)` first; MSR-201 remains `in-progress` with commit/PR/CI pending.
- MSR-211: `FULL-CLOSE(MSR-202)`, `FULL-CLOSE(MSR-210)`, `FULL-CLOSE(GBF-409)`, `FULL-CLOSE(GBF-411)` first. MSR-202 is `in-progress`; GBF-409/411 are `IN_PROGRESS`.
- MSR-202 is not a current MSR-210 hard dependency; if MSR-210 crosses policy/approval scope, stop and add it with the same full gate.

## Risks
- CRITICAL duplicate runtime/session ownership -> MSR-210.
- HIGH provider/device path bypasses approval/audit -> MSR-211.
- HIGH stale/replayed invocation or stale target/session/client/generation -> MSR-211.
- HIGH semantic denial misclassified as Computer Use unavailability -> MSR-211 fail-closed predicate.

## R2 change
R2 `REVIEW-REJECTED` history is preserved. Task-local gates now require complete prerequisite delivery, not review acceptance alone. No CI/merge/package/release success is promoted.