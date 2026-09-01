# ADR-0001 — Provider and license boundary

Status: Accepted for RDF-001  
Date: 2026-09-01  
Owners: Fabushi product/engineering; license review required for later native provider

## Decision

Fabushi account identity, device ownership, permission policy, audit and session grants remain authoritative. Existing `fabushi-webrtc` is the initial provider. RustDesk-grade behavior is represented by normalized capabilities. A future RustDesk implementation must be isolated as a separately distributable sidecar/service or use separately licensed code; it may not silently replace Fabushi authorization.

## Reasons

RustDesk client and OSS server are AGPL-3.0; direct copying/linking into a proprietary application has material copyleft/distribution obligations. A provider boundary also prevents duplicate IDs, pairing and audit models.

## Consequences

RDF-001 can safely deliver inventory value now. RustDesk wire/media interoperability remains explicitly unimplemented until RDF-D002 closes. The boundary adds mapping work but preserves provider replacement and honest capability state.
