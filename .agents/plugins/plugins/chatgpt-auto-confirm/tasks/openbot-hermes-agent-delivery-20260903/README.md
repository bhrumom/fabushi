# OpenBot + Hermes Agent delivery

Task ID: `openbot-hermes-agent-delivery-20260903`
Project: `FAB-P0005 / MSR`
Revision: 1
Status: in progress

## Goal
Fuse compatible OpenBot and Hermes Agent capabilities into Fabushi's existing Mahayana Agent runtime without introducing a competing executor. Deliver durable task-oriented Bot conversations, governed tool execution, resumable work, artifact delivery, and consistent desktop/Web state.

## Pinned upstream research
- CopilotKit/OpenBot `257c1280d684089be9adb0b35cce262efc7064bf` — MIT.
- NousResearch/hermes-agent `593aa74c6182ce2e5e23bc102daaaae71710c05d` — MIT.

OpenBot informs coworker identity/workspace, policy-first action gateway, audit/watch/takeover, durable threads and component delivery. Hermes informs streaming terminal/tool output, interruption/redirection, recovery/compression, memory/skills, scheduled/background work, subagent parallelism and cross-entry continuity. Designs are adapted behind Fabushi boundaries; upstream code is not wholesale copied.

See PRD.md, ARCHITECTURE.md, TASK.md and ACCEPTANCE.md.