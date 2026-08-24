# ADR-0008 — One searchable App Registry for publishing and discovery

- **Status**: Accepted
- **Date**: 2026-08-24
- **Project**: `FAB-P0001` / `TFI`
- **Task**: `M8-APPREG-001`

## Context

Fabushi had two notions of “published”: a legacy official `.well-known` catalog and the newer cloud Marketplace backed by D1. Desktop global Apps search correctly queries the cloud Marketplace, so official apps present only in the legacy catalog were invisible to production search.

Telegram Desktop was studied as an upstream architectural reference: applications are first-class discovery/search entities rather than a separate client-bundled store list.

## Decision

The cloud Marketplace/D1 control plane is the single authoritative searchable App Registry.

- Official source catalogs are publication inputs and compatibility metadata only.
- Approved official and third-party Apps share the same cloud Registry/search API.
- Clients must not maintain or restore a bundled `defaultMiniApps` registry.
- Official publishing is automated from protected `main` using immutable artifacts, existing Mahayana publish validation, provenance, and Registry admission.
- Existing versions are immutable. Sync is idempotent: an existing exact version is verified/skipped; changed bytes require a new version.
- Search ranking/usage signals may evolve independently, but eligibility always originates from approved Registry state.

## Consequences

Positive:
- “上架” and “可搜索” become the same governed lifecycle.
- Desktop/mobile/web can converge on one discovery source.
- Review, revoke, provenance, version, platform, install, and search facts stay synchronized.

Tradeoffs:
- Legacy official entries require a one-time backfill.
- Protected publication requires production test/publisher credentials in Actions.
- A cloud Registry outage can affect fresh discovery; installed apps remain local and runnable.

## Rejected alternatives

1. **Bundle the 12 official apps in the desktop client** — rejected because it recreates the removed `defaultMiniApps` split and drifts across clients.
2. **Search the static `.well-known` file directly from each client** — rejected because review/revoke/release metadata would diverge from the installation authority.
3. **Create a second `app-registry.json`** — rejected because it adds another source of truth rather than converging publishing and discovery.
