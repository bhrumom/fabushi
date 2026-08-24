# M8-APPREG-001 — Telegram-style searchable App Registry

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-APPREG-001`
- **Stage**: `M8 Mini Apps`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-24`
- **Branch**: `feat/tfi-m8-app-registry-search-publishing`

## Objective

Converge Fabushi publishing and discovery on one cloud App Registry so every approved published App automatically becomes searchable from the Messenger global Apps category, including the official apps that were historically present only in the legacy public catalog.

## Source requirements

- `../../source/2026-08-24-telegram-style-app-registry-search-publishing.md`
- `../../source/2026-08-23-online-miniapp-marketplace.md`
- `../../source/完整telegram融合进fabushi.txt`
- `../wbs/M8.md`

## Verified baseline

- Renderer Apps search already calls the online Marketplace through `feature.marketplace.browse`.
- Production AppHost delegates browsing to the Product API.
- Platform Worker search is backed by approved D1 marketplace records.
- `.agents/plugins/marketplace.json` and the public `.well-known` catalog currently enumerate 12 official plugins, but those files are not the production D1 search index.

## In scope

- Make the official publication catalog a governed publication input, not a client-side runtime registry.
- Add normalized search/discovery metadata and strict contract validation.
- Add an idempotent protected-main publication/backfill workflow to production Marketplace.
- Preserve immutable release semantics; never overwrite an existing plugin version.
- Verify cloud discovery for official Apps using the same API/Host path as third-party Apps.
- Keep the existing global Apps UI and install/open route; do not create a second marketplace screen/runtime.
- Add E2E/CI evidence for discovery and publication.

## Acceptance criteria

1. The official internal catalog, public catalog, and on-disk plugin set are one-to-one and have unique normalized IDs.
2. Each public App has searchable category/keywords/aliases metadata and supported platform declarations.
3. The publication workflow authenticates only on protected `main`/manual execution, never on untrusted PRs.
4. Publishing creates immutable HTTPS-hosted artifacts with SHA-256/size/provenance and uses the existing `mahayana plugin publish` cloud Registry path.
5. Existing immutable versions are skipped idempotently instead of overwritten.
6. After publication, `global-dharma` and the remaining official apps are discoverable through the production marketplace query for their supported platforms.
7. Electron simulated-user E2E exercises global search -> Apps -> official App result -> install -> open, retaining screenshots/video/trace on canonical main.
8. Required PR checks pass, the PR merges through protected main, canonical main is read back, and post-main package/E2E/Release evidence is recorded before completion.

## Open-source-first evidence

Inspected the canonical Telegram Desktop repository for WebView/App attach handling, top-peers/discovery data, and MTProto schemas. Reused the product architecture principle (first-class App discovery through shared search) without copying Telegram implementation code.

## Implementation plan

- `scripts/check-official-plugin-marketplace.py`: strengthen searchable Registry contract.
- `scripts/sync-official-app-registry.sh`: deterministic/idempotent official publisher/backfill.
- `.github/workflows/official-app-registry-sync.yml`: secret-bearing protected-main publication and verification.
- `.github/workflows/plugin-marketplace-contract.yml`: validate sync tooling and Registry contract in PR/push gates.
- public catalog: add discovery metadata while retaining compatibility.
- desktop E2E: verify a current official App is discoverable through global Apps search.
- project records/evidence: append implementation, CI, merge, production Registry, post-main E2E, package and Release facts.

## Current blockers

None for implementation. Completion remains gated by protected PR merge and canonical-main post-delivery evidence.

## Evidence

`../../evidence/M8-APPREG-001/README.md`
