# M8-ENTITY-001 — Durable MiniApp definition/version/install lifecycle

- Project: `FAB-P0001 / TFI`
- Task ID: `M8-ENTITY-001`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `0`
- Risk: high; canonical account-synced data model

## Single objective

Make MiniApp definition, immutable version/manifest digest and account-scoped install lifecycle first-class durable canonical data so UI/runtime can reference an entity instead of treating generated code or a transient draft as the product object.

## Inputs

Current `MiniAppManifest/MiniAppGrant/MiniAppSession`, M8 Marketplace store/account sync and Bot projection. Preserve backwards compatibility with existing installed apps.

## Exact implementation allowlist

- `native/mahayana-messaging/src/miniapp.rs`
- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/engine.rs`
- `ai-backend/src/miniapp_marketplace.js`
- `ai-backend/src/miniapp_marketplace_http.js`
- `ai-backend/src/account_sync_store.js`
- `ai-backend/test/account_sync_store.test.js`
- `ai-backend/test/multidevice_account_sync_integration.test.js`
- `projects/telegram-fabushi-integration/evidence/M8-ENTITY-001/**`

Forbidden: Messenger rendering, Mahayana runtime, device-control code, release/workflow/version files.

## Required model

At minimum: stable `mini_app_id`; immutable `version + manifest_digest + manifest + preview/source refs`; stable account `install_id`; `install_state` and `runtime_state`; timestamps; lifecycle event id/causation/correlation. Existing manifest permissions remain authoritative input, not an install grant by themselves.

## Acceptance

1. Same manifest/version yields deterministic digest; changed manifest under the same version is rejected or explicitly versioned, never silently overwritten.
2. Account sync round-trips definition/version/install state across two devices without leaking another account.
3. Existing pre-migration installed apps are read with a deterministic compatibility mapping and no duplicate install is created.
4. Install/update/uninstall/restore transitions are durable and auditable; a failed transition is represented explicitly.
5. Native protocol snapshot/delta can carry the new data without dropping legacy MiniApp sessions/grants.
6. No UI card is implemented here; this task produces the canonical entity contract only.

## CI / evidence

Rust unit/serialization tests + backend account-sync/marketplace tests + multidevice integration. PR exact-head evidence includes migration/compat fixtures and state-transition transcript. Exact-main readback before `TESTED`.

## Rollback

Keep a compatibility reader during the migration window. Revert new writes/projections without deleting existing Marketplace data; no destructive schema downgrade is allowed.
