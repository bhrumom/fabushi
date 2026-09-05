# M8-CARD-001 — Bot-generated MiniApp entity/card projection

- Project: `FAB-P0001 / TFI`
- Task ID: `M8-CARD-001`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `2`
- Risk: medium/high; generated-content UX + install actions

## Single objective

Change the Bot MiniApp generation completion surface from code-only/transient workflow output to a canonical MiniApp entity reference rendered as a discoverable/installable/direct-open card with real manifest/version/preview/install/runtime state.

## Dependencies

`M8-ENTITY-001`, `M8-BIND-001`, and `M3-DESKTOP-004` must be complete/read back because this task owns Messenger shell UI.

## Exact implementation allowlist

- `ai-backend/src/miniapp_marketplace_mcp.js`
- `desktop/src/messaging-shell-v2.tsx`
- `desktop/src/messaging-shell-v2.module.css`
- `frontend/apps/web/src/app/host/host-client.tsx`
- `desktop/e2e/miniapp-bot-parity.spec.ts`
- `projects/telegram-fabushi-integration/evidence/M8-CARD-001/**`

Forbidden: MiniApp canonical schema, account-sync schema, Mahayana runtime, device control, workflows/version files.

## Card contract

Card identity comes from `mini_app_id + version + manifest_digest`; display includes title/icon/description, preview reference, publisher/source where available, review/discoverability status, install state and runtime/open state. Actions are state-dependent (`install`, `open`, `update`, `retry`, `uninstall` where appropriate) and call canonical lifecycle APIs. Raw generated code may be available as secondary detail/artifact, never the only completion object.

## Acceptance

1. `generate_and_submit_miniapp` completion returns/references a durable entity even when the generator itself created the manifest; it does not return `draft:null` as the only product state.
2. Chat/Host renders the entity card after generation and after app restart/account sync.
3. Installing from the card produces the exact M8-BIND-001 Bot/conversation identity and updates card state without optimistic divergence.
4. Open is enabled only for a verified runnable installed version; failed build/install/runtime states remain visible and retryable where policy permits.
5. Version/update changes are visible and preserve manifest digest identity.
6. Packaged E2E records generate -> card -> install -> Bot chat -> open -> restart -> card restored.

## Rollback

Card rendering can fall back to a plain entity link/structured result without deleting canonical entity/install data. Never roll back by returning to code-only storage or inventing UI-only install state.
