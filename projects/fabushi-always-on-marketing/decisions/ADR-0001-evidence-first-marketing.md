# ADR-0001 — Evidence-first marketing

- Status: Accepted
- Date: 2026-08-23
- Owners: Fabushi growth + engineering

## Context

Daily marketing must scale without creating fake demos or requiring teams to manually re-record product functionality.

## Decision

GitHub Actions/E2E verification artifacts are the canonical source for product-function marketing. A platform-neutral campaign package separates capture/evidence from content transformation and publishing. Successful-feature claims require passing verification; prototypes/roadmap content must be labeled.

## Alternatives

- Manually record every post: rejected as non-scalable and weakly traceable.
- Generate synthetic product demos: rejected for authenticity risk.
- Build directly against one social platform: rejected due to lock-in and policy volatility.

## Consequences

More engineering work upfront, but stronger authenticity, reuse, auditability, safety and cross-platform portability.
