# 06 运维可观测性与 SLO

Runtime project; not N/A.

## Required signals
- agent/turn/step lifecycle and terminal status;
- tool call, approval, interception and duration outcomes;
- plugin/profile mount/unmount/config generation;
- model stream start/first-token/end/error/cancel;
- session append/persist/replay/fork/recovery outcomes;
- job/workflow/subagent state transitions;
- capability rejection/fallback reason.

## Initial SLO direction
- No silent loss of durable session events after acknowledged persistence.
- Every admitted turn/job/workflow reaches an observable terminal or suspended state.
- Unsupported local capabilities fail explicitly; no silent remote-agent fallback.
- Tool approvals remain fail-closed on policy errors.
- Runtime snapshot/config dump is deterministic for the same profile/config inputs.

Concrete latency/throughput/resource budgets are set by DHRF-603 after baseline measurements exist.

Telemetry must avoid secrets, credentials and private prompt/tool payloads by default; use redacted identifiers and aggregate metrics.
