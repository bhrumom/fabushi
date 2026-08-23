# MSR-202 — Native tool, policy and approval bus

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-202
- **Status:** in-progress
- **Started:** 2026-08-22T16:55:00+08:00
- **Updated:** 2026-08-22T16:55:00+08:00
- **Completed:** null

## Objective
Make Mahayana policy, approval outcomes and permission memory the single fail-closed authorization path for production native tools.

## Source requirements
MSR-R01, MSR-R02, MSR-R08; Codex fail-closed approvals; Grok Build permission memory/loop protection.

## In scope
Tool risk fingerprinting; permission memory; fail-closed timeout/interruption; loop protection before execution; approval audit events/tests.

## Out of scope
UI cosmetics for approval prompts.

## Dependencies
MSR-102; coordinates with MSR-201.

## Acceptance criteria
1. Every native production tool passes through one Mahayana authorization function.
2. Rejected, timed-out, interrupted or missing approval never executes the tool.
3. Session allow and permanent deny memory are supported with explicit clearing.
4. Repeated identical tool actions warn then interrupt according to loop policy.
5. Security/conformance tests prove fail-closed behavior.
6. Protected merge and canonical-main verification complete.

## Verification
Kernel supervisor tests; native-engine authorization/loop tests; Mahayana Fast Checks; source-boundary audit.

## Branch / commit / PR
Branch: `feat/msr-native-runtime-parity`
Commit: pending
PR: pending

## Implementation summary
Pending implementation.

## Evidence
Pending CI/merge evidence.

## Blockers / risks
Permission memory must be scoped by capability and canonical target to avoid accidental broad grants.

## Next action
Bind supervisor permission/loop primitives into NativeEngine tool execution.
