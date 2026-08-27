# ADR-0005 — Fail-fast and warm-state CI throughput

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

Fabushi already uses risk-tiered CI, merge queue validation, cache reuse, and post-main packaged E2E. The remaining avoidable latency is increasingly dominated by fixed runner/setup cost: dependency installation before deterministic text/architecture guards, full-history or recursive-submodule checkout on lightweight PR paths, and native package installation before formatting failures are known.

## Decision

1. Order every PR hot path from cheapest deterministic checks to most expensive setup/build/test work.
2. Use shallow checkout and no recursive submodules for PR jobs unless the job objectively consumes them. Fetch only the exact base ref/commit needed for diff validation.
3. Preserve existing warm caches and compiler-result caches; build/package/device work remains post-main where already designed.
4. Preserve merge queue, aggregate `CI result`, unknown-path fail-safe, exact-SHA artifact provenance, signing/notarization, and required packaged E2E.
5. Prefer reusable workflows (`workflow_call`) for future fan-out consolidation when measured data proves that shared orchestration reduces startup/queue overhead without hiding product-specific gates.

## Consequences

Cheap failures return earlier and consume fewer runner-minutes. PR jobs transfer less source history and fewer submodules. Canonical-main safety remains unchanged. Larger workflow consolidation remains an evidence-driven follow-up rather than a risky all-at-once rewrite.
