# ADR-0001 — Mahayana owns the Design/Artifact runtime

Status: Accepted
Date: 2026-08-28

## Context
OpenDesign contains valuable design-system, skill, adapter and artifact patterns but also a complete daemon/desktop product overlapping Mahayana/Fabushi.

## Decision
Mahayana remains the only agent loop/session/policy/runtime owner. Reuse compatible schemas/algorithms or clean-room architectural patterns, expose them as Fabushi/Mahayana contracts, and project results through the existing Workbench/MiniApp host.

## Consequences
No duplicated permission/session model; lower integration risk; some OpenDesign UI/daemon code is intentionally not imported. Apache-2.0 attribution is preserved for any direct code reuse.
