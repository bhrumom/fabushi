# ADR-0012 — Skills over MCP progressive disclosure

- **Status**: Accepted for experimental adapter implementation
- **Date**: 2026-08-27
- **Project**: FAB-P0001 / TFI
- **Task**: M8-SKILLS-001

## Context

Fabushi MiniApps already expose MCP Tools, Resources, UI, CLI/native surfaces, and WebMCP foreground projection. Local Agent Skills also exist, but they are installed into a filesystem Skill directory and are not discoverable from a connected MiniApp MCP server. The MCP Skills Over MCP WG is converging SEP-2640 on `skills/list`, `skills/get`, individually readable Skill resources, and per-file digests; the proposal remains experimental.

## Decision

1. Skills are a knowledge/orchestration layer, never a second effect-execution layer.
2. MiniApp Skills are served as MCP Resources and discovered through a replaceable Skills-extension adapter.
3. Until the JavaScript MCP SDK exposes a stable SEP-2640 extension registration API, Fabushi exposes `skills_list` / `skills_get` read-only compatibility tools with the same canonical entry shape. This bridge is not the canonical protocol model and may be removed once native extension handlers are stable.
4. Skill bodies use progressive disclosure: listing/get returns frontmatter + complete per-file digest metadata; content is fetched with `resources/read` only when needed.
5. Static resources use `sha256:<hex>` digests. Hosts reject mismatches and unlisted supporting-resource reads. Dynamic Skills are rejected by default unless an explicit host policy allows them.
6. A Skill identity is `(MCP server origin, Skill URI)`. The `name` is display metadata and never an identity key.
7. `skill://` is a recommended resource addressing convention, not a trust signal.
8. Skill content is untrusted instructional data. Loading a Skill never grants Tool permission, never auto-executes scripts, and never bypasses current Fabushi write/open-world/destructive approvals.
9. Host reads are bounded by byte limits and future catalog walkers must also have page/entry budgets.
10. Existing MiniApps remain compatible. When no authored Skill metadata survives the current manifest pipeline, the adapter generates a conservative operator Skill from the existing Tool Contract. Authored manifest Skill normalization is a subsequent schema-hardening step before declaring the extension final.

## Consequences

- Fabushi can start consuming Skills over MCP today without coupling the product core to an unaccepted extension revision.
- Existing Tool Contract and WebMCP security semantics remain authoritative.
- A later native `skills/list` / `skills/get` implementation is an adapter swap instead of a data-model migration.
- The generated fallback Skill is intentionally conservative; richer third-party authored Skill persistence must be added to the canonical MiniApp manifest schema before Marketplace declares full publisher-side Skill support.
