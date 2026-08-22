# MSR-302 — Production orchestration parity

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-302
- **Status:** in-progress
- **Started:** 2026-08-22T16:56:00+08:00
- **Updated:** 2026-08-22T16:56:00+08:00
- **Completed:** null

## Objective
Bind Mahayana prompt queue, goals/oracles, attempt journal, loop protection, workflows, hooks, memory and subagents to production turns with serializable recovery state.

## Source requirements
MSR-R03, MSR-R08; Grok Build queue/oracle/attempt/workflow/hook/subagent concepts.

## In scope
Serializable orchestration state; production turn journal; hook dispatch around model/tool/checkpoint lifecycle; workflow execution and descendant guard; tests.

## Out of scope
Vendor-specific workflow formats.

## Dependencies
MSR-102; coordinates with MSR-201/202.

## Acceptance criteria
1. Native production turns record attempts and verification state.
2. Prompt queue/workflow/memory/subagent state is snapshot-safe.
3. Pre/post model/tool/checkpoint hooks execute in deterministic order.
4. Live descendant work prevents unsafe parent suspension unless explicitly cascaded.
5. CI proves persistence and production-path integration.
6. Protected merge and canonical-main verification complete.

## Verification
`mahayana-orchestrator` and `mahayana-native-engine` integration tests in Fast Checks.

## Branch / commit / PR
Branch: `feat/msr-native-runtime-parity`
Commit: pending
PR: pending

## Implementation summary
Pending implementation.

## Evidence
Pending CI/merge evidence.

## Blockers / risks
Hooks must be bounded and cannot silently bypass the policy bus.

## Next action
Introduce serializable orchestration snapshot and production hook/journal wiring.
