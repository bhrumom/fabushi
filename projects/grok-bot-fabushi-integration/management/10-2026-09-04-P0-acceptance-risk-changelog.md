# GBF P0 acceptance / risk / dependency / changelog — FAB-ARCH-P0-20260904

## Acceptance
GBF-508 requires clean-room observable anchors, directed trigger/privacy negatives, one-session context, typed tool states, and all capability calls through accepted MSR policy. It cannot close before GBF-409/411 + MSR-210/211 are independently accepted.

## Risks
- `GBF-P0-R1` CRITICAL: ambient group privacy leak.
- `GBF-P0-R2` CRITICAL: account login mistaken for device-control grant.
- `GBF-P0-R3` HIGH: direct provider invocation bypasses MSR approval/audit.
- `GBF-P0-R4` HIGH: semantic denial improperly falls back to Computer Use.
- `GBF-P0-R5` LEGAL: reconstructed Grok implementation copied despite unclear rights.

## Dependency truth
GBF-409/411 are `IN_PROGRESS`; MSR-201/202 are `in-progress`; therefore MSR-210/211 and GBF-508 capability closure remain blocked. Partial work is limited to task-declared clean-room behavior/spec/test-vector artifacts.

## Change log 2026-09-04 repair
Preserved original PR #2320 rejection, normalized GBF-508, converted “reuse/coordinate” into hard gates, added MSR-211 capability-policy prerequisite and exact fallback preconditions, repeated full canonical-main evidence contract, and kept reconstructed Grok implementation source forbidden. No CI/merge/release status was promoted.
