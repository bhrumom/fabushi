# GBF P0 acceptance / risk / dependency / changelog — FAB-ARCH-P0-20260904

## Dependency completion rule
GBF-508 cannot integrate/close until MSR-210, MSR-211, GBF-409 and GBF-411 each have contract acceptance, independent `REVIEW-PASS`, protected canonical-main merge, required CI, and installable/packaged E2E plus Release evidence bound to that dependency's exact accepted canonical-main SHA. MSR-201/202 must similarly complete before MSR-210/211 can count as complete.

## Acceptance
GBF-508 requires clean-room observable anchors, directed trigger/privacy negatives, one-session context, typed tool states, all capability calls through the fully delivered MSR policy plane, and the strict semantic->Computer Use fallback predicate including current client and explicit MiniApp/install permission plus audit/correlation.

## Risks
- `GBF-P0-R1` CRITICAL: ambient group privacy leak.
- `GBF-P0-R2` CRITICAL: account login mistaken for device-control grant.
- `GBF-P0-R3` HIGH: direct provider invocation bypasses MSR approval/audit.
- `GBF-P0-R4` CRITICAL: semantic denial, stale client/session/generation, install disallow or missing correlation improperly falls back to Computer Use.
- `GBF-P0-R5` LEGAL: reconstructed Grok implementation copied despite unclear rights.

## Dependency truth
GBF-409/411 are `IN_PROGRESS`; MSR-201/202 are `in-progress`; therefore MSR-210/211 and GBF-508 remain blocked. Partial work is clean-room/spec/test-vector `contract-only` work only.

## R2 change
Historical R2 `REVIEW-REJECTED` is preserved. Review-only dependency shorthand was removed; no CI/merge/release status was promoted. Failed GBF regression run `33876067936` remains a recorded failure, not a green gate.