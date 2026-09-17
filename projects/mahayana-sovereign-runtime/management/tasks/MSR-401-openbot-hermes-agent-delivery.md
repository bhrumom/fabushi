# MSR-401 — OpenBot + Hermes Agent delivery fusion

Status: in progress
Task ID: `openbot-hermes-agent-delivery-20260903`

## Objective
Upgrade Fabushi's existing Mahayana Agent runtime into a durable task-oriented Bot delivery experience by adapting proven ideas from OpenBot and Hermes Agent without creating a second executor.

## Open-source-first evidence
- CopilotKit/OpenBot pinned at `257c1280d684089be9adb0b35cce262efc7064bf`, MIT. Reuse/adapt concepts: per-Bot identity/workspace, policy-first action gateway, audit, watch/takeover, durable threads and component responses.
- NousResearch/hermes-agent pinned at `593aa74c6182ce2e5e23bc102daaaae71710c05d`, MIT. Reuse/adapt concepts: streamed tool output, interruption/redirection, recovery/context compression, memory/skills, cron/background work, subagent parallelism and cross-entry continuity.
- Decision: adapt architecture and behavior behind Fabushi's existing runtime, policy, approval, artifact and UI boundaries. Do not import either runtime wholesale.

## Durable task definition
`.agents/plugins/plugins/chatgpt-auto-confirm/tasks/openbot-hermes-agent-delivery-20260903/`

## Completion gate
Only merged canonical main + required exact-main CI/E2E evidence + published release may move this record to complete.