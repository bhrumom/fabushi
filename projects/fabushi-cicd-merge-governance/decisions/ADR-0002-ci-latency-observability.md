# ADR-0002 CI latency observability

- Status: Accepted
- Date: 2026-08-22
- Project: FAB-P0003

## Context

FCM-001 and FCM-003 reduced unnecessary validation work. Without measurement, future workflow changes may accidentally reintroduce latency.

## Decision

Add a lightweight GitHub Actions based latency observer. It consumes Actions metadata rather than building code or changing product validation behavior.

## Alternatives considered

1. Manual inspection only.
   - Rejected: no trend detection.

2. Make latency observer a required merge check.
   - Rejected: metrics collection should not become a bypass or availability risk.

3. External monitoring service as first step.
   - Deferred: GitHub Actions metadata is sufficient for initial governance.

## Consequences

- CI latency becomes measurable by change tier.
- Low sample sizes remain explicit.
- Future optimization can target evidence instead of assumptions.
