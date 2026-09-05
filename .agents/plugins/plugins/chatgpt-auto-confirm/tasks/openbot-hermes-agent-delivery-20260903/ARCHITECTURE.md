# Architecture

## Single runtime
`Mahayana Agent Runtime` remains the only executor. New capability is expressed through its canonical run-event stream and stores, not through an embedded OpenBot/Hermes runtime.

## Canonical event families
- lifecycle: goal, plan, step.started/progress/completed/failed, run.paused/resumed/stopped/completed/failed
- tools: tool.requested/approval-required/started/output/completed/failed
- delegation: subagent.started/progress/completed/failed
- delivery: artifact.created/updated/failed and delivery.ready/opened/retry-requested/failed
- control: redirect.requested/applied and takeover.requested/acquired/released

Every event carries conversationId, runId, sequence, timestamp and correlation identifiers. Desktop/Web projections are rebuildable from canonical state.

## Governance
All side effects route through Fabushi's existing policy/approval/audit boundary. Policy resolves before execution; audit records decision and result while redacting secrets. Human takeover suspends conflicting Bot actions.

## Persistence and recovery
Run, step, tool, approval, artifact and delivery records are durable. Resume uses idempotency/correlation keys and never repeats a committed side effect. Context compression and memory/skills are inputs to the existing runtime rather than an alternate loop.

## Queue supervisor
chatgpt-auto-confirm records wall-clock turnStartedAt/turnEndedAt plus monotonic duration, Chat conversation ID, same-chat follow-up count and new-chat continuation count. For unfinished turns shorter than 1200 seconds, it sends at most two audited follow-ups in the same Chat. After two follow-ups, or after any >=1200-second turn, it rolls to a fresh Chat carrying only durable task/revision/workspace/PR/Actions evidence and remaining work.