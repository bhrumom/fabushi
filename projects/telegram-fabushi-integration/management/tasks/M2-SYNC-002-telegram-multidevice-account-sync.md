# M2-SYNC-002 — Telegram-class multi-device account synchronization

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-SYNC-002`
- **Stages**: `M2 realtime sync + M7 Bot identity + M8 Mini Apps`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-27`
- **Branch**: `feat/tfi-multidevice-account-sync`
- **Source**: `../../source/2026-08-27-telegram-multidevice-account-sync.md`
- **Depends on**: `M2-SYNC-001`, `M8-MARKET-002`

## Objective

Promote the existing durable Messaging v2 cursor/journal mechanism from a transport-level second-device capability into one coherent **Fabushi account synchronization domain**, including conversation/message history, added Bots, installed Mini Apps, Mini App cloud state and cross-device convergence.

## Atomic deliverables

### M2-SYNC-002.A — stable account identity
- Replace token-hash Marketplace ownership with a canonical account scope resolved from authenticated account identity.
- Different device/session access tokens for the same account must map to one account key.
- Device/session identity remains separate and auditable.

### M2-SYNC-002.B — account sync state / difference protocol
- Add explicit account sync state and snapshot/delta response metadata around the existing durable cursor journal.
- Detect ahead/expired/missing cursor and perform scoped snapshot recovery.
- Preserve cursor-group pagination, idempotency and audience isolation.

### M2-SYNC-002.C — Bot add/remove synchronization
- Persist account-level added-Bot membership independently from global Bot registry/profile data.
- Add/remove operations emit durable account-scoped events.
- Snapshot/delta sync reconstructs added Bots on a new device.

### M2-SYNC-002.D — Mini App install/uninstall synchronization
- Make installed Mini Apps account-scoped and durable.
- Installation/uninstallation emits the same account sync stream and projects the manifest Bot identity into Contacts/Bots.
- New devices restore the installed list without re-installing manually.

### M2-SYNC-002.E — Mini App cloud storage
- Add user/account + MiniApp scoped cloud key/value storage with revision/update events.
- Keep device-local and secure-device storage explicitly outside cloud sync.
- Expose list/get/set/delete through the authenticated Mini App bridge/backend contract.

### M2-SYNC-002.F — Bot conversation/history convergence
- Bot conversations/messages use canonical Messaging v2 conversation/message entities and account sync cursors.
- Second device sees prior Bot messages and later updates, including read state.

### M2-SYNC-002.G — desktop sync coordinator
- Persist per-account sync cursor in client persistence.
- Startup: restore projection immediately, then run catch-up until checkpoint is current.
- Realtime events advance cursor; detected gaps trigger difference recovery; account switch clears account-bound cursors/projections.

### M2-SYNC-002.H — objective verification
- Rust unit/integration: two devices, different device/session IDs, same actor/account, online + offline/restart + pruned cursor recovery.
- Backend tests: same account with different valid session tokens shares Mini App/CloudStorage state; different accounts remain isolated.
- Electron E2E: Device A install/add/chat/cloud-write; Device B login/catch-up sees Mini App + Bot + history + cloud value; uninstall propagates.
- PR gates, protected merge queue, canonical-main packaged E2E screenshots/video/trace, and Release evidence are mandatory before completion.

## Open-source-first decision

- Learn/adapt the update-state and get-difference behavior from `tdlib/td` (`Boost-1.0`), especially gap detection, durable state, pagination and restart catch-up.
- Learn/adapt Telegram official attachment-menu behavior: change event invalidates installed list and clients reconcile against an authoritative account list.
- Retain Fabushi Messaging Protocol v2 and Mahayana/Marketplace data models; do not copy MTProto/TL formats.

## Acceptance criteria

- One account is the server-side source of truth; a device is never the ownership namespace for account data.
- Two devices with different access tokens but the same authenticated account converge to the same added Bots, installed Mini Apps, Bot conversations/messages/read state and Mini App cloud state.
- Offline devices catch up from durable deltas; old/pruned cursors recover via account-scoped snapshot without leaking another account's data.
- Mini App package bytes/runtime caches remain device-local, while installation entitlement/configuration is account-level.
- Secure device storage remains intentionally device-local and never enters general account sync.
- Account logout/switch cannot expose the previous account's cursor or projection.

## Evidence

Implementation/PR/CI/main/package/release evidence will be appended before this task can advance beyond `IN_PROGRESS`.
