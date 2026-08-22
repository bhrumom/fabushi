# ADR-0001 — Mahayana owns product contracts

Status: Accepted
Date: 2026-08-22
Decision owners: Fabushi project owner / engineering

## Context
Mahayana began with significant Codex inheritance and now also studies Grok Build. Simply combining or renaming upstream implementations would preserve vendor ownership of product assumptions.

## Decision
Mahayana owns all public IDs, protocols, state machines, capability contracts and cross-platform ABI. Codex/Grok Build implementations or ports may exist only as attributed adapters/reference-derived implementations behind those boundaries. New native product crates must not directly expose vendor product types.

## Alternatives
1. Keep Codex as canonical core and layer Grok features: rejected due to continued product/vendor coupling.
2. Replace Codex wholesale with Grok Build: rejected because it substitutes one vendor dependency for another.
3. Fork both trees into one monolith: rejected due to upgrade, provenance and architecture complexity.

## Consequences
Requires staged migration and conformance testing, but makes upstreams independently replaceable and preserves Fabushi/Mahayana product identity.
