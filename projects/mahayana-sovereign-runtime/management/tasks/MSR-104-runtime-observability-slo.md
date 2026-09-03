# MSR-104 — Runtime observability and SLO

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-104
- **Status:** in-progress
- **Started:** 2026-08-22T16:55:00+08:00
- **Updated:** 2026-08-22T22:20:00+08:00
- **Completed:** null

## Objective
Define and implement provider-neutral Mahayana runtime telemetry so sessions, operations, approvals, tools, failures and latency can be measured consistently across native and adapter paths.

## Source requirements
MSR-R01, MSR-R02, MSR-R08; `docs/08-upstream-capability-matrix.md`.

## In scope
Kernel telemetry contract; native-engine instrumentation; SLI/SLO specification; deterministic telemetry tests.

## Out of scope
External vendor APM selection.

## Dependencies
MSR-102.

## Acceptance criteria
1. Mahayana owns a provider-neutral runtime metrics contract.
2. Native sessions/operations/tool calls/approvals/success/failure update metrics without vendor types.
3. SLI/SLO targets and alert thresholds are documented.
4. CI executes telemetry tests.
5. Protected merge and canonical-main verification complete.

## Verification
`cargo test -p mahayana-kernel -p mahayana-native-engine --profile ci`; source-boundary check; project acceptance trace.

The normative SLI/SLO and alert-threshold specification is `projects/mahayana-sovereign-runtime/docs/09-runtime-observability-slo.md`.

## Branch / commit / PR
Branch: `feat/msr-sovereign-runtime-final`
Commit: SLO specification introduced at `f14858f48914589d7dd371cf437d88d3a5bbff37`; final implementation head pending.
PR: #2017

## Implementation summary
Provider-neutral telemetry primitives and native runtime instrumentation exist in `mahayana-kernel::telemetry` / `mahayana-native-engine`. The product-owned SLI/SLO, alerting, error-classification and privacy rules are now documented in `docs/09-runtime-observability-slo.md`.

## Evidence
Implementation/CI evidence remains pending exact-final-head Actions and canonical-main verification. This task must not be marked passed before those gates complete.

## Blockers / risks
Telemetry must not capture prompts, secrets or raw tool payloads by default.

## Next action
Run the final kernel/native-engine telemetry tests and source-boundary gate on the exact #2017 final head, then record merge/main evidence.
