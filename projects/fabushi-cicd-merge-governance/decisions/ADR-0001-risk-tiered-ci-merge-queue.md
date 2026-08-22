# ADR-0001 — Risk-tiered CI with merge queue retained

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

The repository already has a protected `main` and merge queue, but current merge-group handling forces every canonical product test for every change, creating unnecessary latency and cost.

## Decision

Retain PR checks, aggregate required `CI result`, merge queue and merge-group validation. Select internal checks by actual changed domains on both PR and merge-group candidates. Treat explicitly safe documentation/project paths as Tier 0 and unknown non-doc paths as fail-safe all-checks. Production deployment is separately change-aware.

## Consequences

Low-risk changes become fast without bypassing protected-main safety. Classifier maintenance becomes a governed CI concern; unknown paths deliberately cost more until classified.
