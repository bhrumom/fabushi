# ADR-0001 — Rust-native Harness boundary

Status: Accepted
Date: 2026-08-22
Decision owners: Fabushi project owner / engineering

## Context
DeepSeek Harness is a rapidly evolving TypeScript/Node product built around Cordis and an everything-is-a-plugin architecture. Fabushi already has a Rust-native Mahayana runtime and dedicated Harness crates. Embedding the upstream runtime would create a second lifecycle/config/plugin system and weaken Mahayana product ownership.

## Decision
Use DeepSeek Harness's public behavior, architecture and MIT-licensed source as a reference for capability parity, but implement/bridge required functionality through the existing Rust-native Mahayana Harness and product-owned interfaces. Node.js, Cordis and upstream product types are not required default-runtime dependencies.

Equivalent existing Fabushi capabilities must be adapted into Harness service/provider seams rather than duplicated. Public desktop/mobile/Web/CLI integrations go through Mahayana Host/FeatureHost contracts.

## Alternatives considered
1. Vendor and run the TypeScript/Cordis application inside Fabushi — rejected: duplicate runtime, larger attack/supply-chain surface and product coupling.
2. Mechanical TypeScript-to-Rust translation package-by-package — rejected: preserves implementation structure rather than product contracts and duplicates existing Mahayana capabilities.
3. Ignore upstream behavior and only borrow ideas — rejected: cannot objectively claim full requested fusion/parity.

## Consequences
Requires capability inventory and scenario-level conformance tests, but preserves one Rust runtime, cross-platform capability truth and replaceable providers. Upstream revisions are consumed deliberately through new audit rounds rather than silently controlling Fabushi releases.
