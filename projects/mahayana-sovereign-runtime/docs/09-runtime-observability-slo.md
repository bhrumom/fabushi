# Mahayana Runtime Observability SLI/SLO

**Project:** FAB-P0005 / Mahayana Sovereign Runtime  
**Scope:** provider-neutral runtime reliability for native and compatibility-adapter execution paths  
**Source contract:** `mahayana-kernel::telemetry`

## Principles

Mahayana telemetry measures runtime behavior without recording prompt text, secrets, credentials, raw tool arguments, raw tool output, or provider-specific payloads as metric labels. Rejections explicitly chosen by a user are not counted as infrastructure failures. Suspended operations are lifecycle transitions rather than failures unless they cannot later resume.

## Canonical signals

The runtime contract emits or aggregates the following product-owned signals: sessions opened; operations started/completed/failed/suspended/resumed; model calls and model latency; tool calls and tool failures; approvals requested/approved/rejected/timed-out/interrupted. Any external APM or dashboard must derive its views from these Mahayana signals rather than vendor-specific counters.

## SLI and SLO targets

| SLI | Calculation | 30-day objective | Alert threshold |
|---|---|---:|---|
| Operation completion availability | `operations_completed / (operations_completed + operations_failed)` for terminal operations | >= 99.0% | page if < 98.5% for 15m; ticket if < 99.0% for 1h |
| Model call reliability | successful model calls / all model calls | >= 99.0% | page if failure ratio > 2% for 15m |
| Tool execution reliability | `(tool_calls - tool_failures) / tool_calls` | >= 99.0% | page if failure ratio > 2% for 15m |
| Interactive model latency | p95 duration derived from model-call latency observations | <= 15s | warn if p95 > 15s for 15m; page if p95 > 30s for 15m |
| Approval transport reliability | `1 - (approvals_timed_out + approvals_interrupted) / approvals_requested` | >= 99.0% | warn if timeout+interruption ratio > 1% for 30m; page if > 5% for 15m |
| Resume success | resumed operations reaching a terminal completion / resumed operations reaching a terminal state | >= 99.0% | warn if < 99% for 1h; page if < 95% for 15m |

`approvals_rejected` is intentionally excluded from approval transport reliability because rejection is a valid user/policy outcome. `operations_suspended` is intentionally excluded from terminal availability until the operation completes or fails.

## Failure classification

User-facing failures must remain structured through Mahayana kernel/runtime errors and events. Reliability dashboards should classify failures into at least: policy denied, capability unavailable, provider/model failure, tool failure, approval timeout/interruption, operation interruption, and internal runtime failure. Unknown failures are treated as internal failures until classified.

## Alerting and burn-rate guidance

The short-window thresholds above catch acute regressions. For sustained degradation, alert when a 6-hour window consumes more than 25% of the 30-day error budget for operation completion, model reliability, tool reliability, or approval transport reliability. Alerting systems may implement multi-window burn-rate rules, but must preserve the SLO definitions above.

## Privacy and cardinality guardrails

Telemetry labels may include stable low-cardinality values such as runtime profile, product surface, operation outcome class, tool class, and backend class. They must not include user prompts, conversation text, filenames containing user data, secret identifiers, access tokens, raw URLs containing credentials, arbitrary tool arguments, raw provider responses, or unbounded error strings.

## Verification

Acceptance requires deterministic telemetry tests in `mahayana-kernel` / `mahayana-native-engine`, Mahayana source-boundary validation, and GitHub Actions evidence on the exact final FAB-P0005 head. This document defines objectives only; it is not evidence that the implementation or CI gate has passed.
