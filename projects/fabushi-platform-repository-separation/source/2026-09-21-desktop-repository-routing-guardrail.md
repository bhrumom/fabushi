# PRS-REQ-012 — Repository routing and Spec-first guardrail

Date: 2026-09-21

## Original user requirements

The user first required the root agent instructions in `bhrumom/fabushi` to state that Desktop had already moved out so AI agents would not work in the wrong repository. The user then expanded the requirement to all split projects, explicitly including mobile and CLI, and required the corresponding repositories to have their own `AGENTS.md` and Spec-first development rules.

## Normalized requirement

1. Root `AGENTS.md` in `bhrumom/fabushi` must contain a complete routing table for all formally split target repositories plus the existing standalone userscript repository.
2. Product implementation for a routed scope must not continue in `bhrumom/fabushi`, even when legacy source paths remain.
3. Agents must verify repository identity and switch to the canonical target repository before implementation.
4. Every target repository must have a repository-root `AGENTS.md` that states its own ownership boundary and requires Spec-first development.
5. Every target repository must contain a durable Spec-first policy and a reusable Spec template under `docs/specs/`.
6. Required lifecycle: Discover -> Spec -> Architecture/Plan -> Implement -> Verify -> Spec Compliance Review -> Integrate/Deliver.
7. Missing, stale, unclear, or contradictory Specs fail closed: repair/create the Spec before product-affecting implementation.
8. Migration/governance/history work that intentionally belongs to the legacy source repository remains allowed when explicitly targeted.

## Canonical target repositories

- `bhrumom/fabushi-platform-core`
- `bhrumom/fabushi-cli`
- `bhrumom/fabushi-web`
- `bhrumom/fabushi-desktop`
- `bhrumom/fabushi-android`
- `bhrumom/fabushi-ios`
- `bhrumom/fabushi-wechat`
- `bhrumom/fabushi-chrome-extension`
- `bhrumom/fabushi-backend`
- `bhrumom/fabushi-forum`
- `bhrumom/fabushi-commerce`
- `bhrumom/fabushi-marketplace`
- `bhrumom/fabushi-governance`
- existing standalone `bhrumom/fabushi-chatgpt-auto-confirm-userscript`

## Scope note

This routing/spec governance change does not by itself declare every remaining PRS CI/release/production cutover or source-cleanup gate complete.
