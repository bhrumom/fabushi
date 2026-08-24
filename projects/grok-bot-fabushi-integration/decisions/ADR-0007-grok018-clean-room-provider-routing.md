# ADR-0007: Grok 0.18 parity uses clean-room capability fusion through Mahayana

Status: Accepted — 2026-08-24

## Context

The user selected `bhrum/grok-bot-0.18-reconstructed` and requested complete code/effect fusion. The pinned repository contains 2,111 tracked paths, including recovered/generated source, a partial renderer reconstruction, build transforms, and Git LFS pointers for original installers. Its `NOTICE.md` and `PROVENANCE.md` explicitly do not grant an upstream source-code license.

The existing GBF architecture already requires one Fabushi/Mahayana Agent/Tool/Host runtime and forbids whole-source merges or a parallel Grok subproduct.

## Decision

1. Treat the exact pinned source commit/tree as an observable behavior, API, protocol, and test reference only.
2. Do not import original installers, shipped renderer bundles, reconstruction build overlays, recovered/generated source, Grok branding assets, or unlicensed code into the product.
3. Independently implement retained capabilities at Fabushi-owned boundaries and preserve Fabushi identity.
4. Implement multi-provider routing inside the Mahayana provider boundary. Fabushi/Codex/Claude Code/OpenRouter must share the same transcript, MCP/tool policy, approvals, usage events, cancellation, and Host lifecycle.
5. Implement optional local containers as a capability-gated, loopback-only, owner-labelled sandbox adapter. It must never stop or replace an unowned container.
6. Observable parity is closed only by the final capability matrix plus canonical-main packaged screenshots, full videos, traces/reports, and Release evidence.

## Alternatives rejected

- Wholesale source merge: incompatible with licensing, current architecture, and rollback safety.
- Shipping the checksum-pinned upstream renderer/installers: redistributes unlicensed product artifacts and defeats Fabushi ownership.
- Keeping the reconstructed Node coordinator beside Mahayana: creates a second formal runtime and divergent security policy.
- UI-only imitation: cannot satisfy Router, transcript, MCP, usage, recovery, or sandbox behavior.

## Consequences

- Delivery is capability-by-capability and evidence-gated rather than a mechanical repository copy.
- Some low-level reconstructed files will be classified as learned/rejected even when their observable behavior is implemented elsewhere.
- Provider and container adapters require security review and cross-platform CI before release.
