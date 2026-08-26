# M2-SYNC-002 — Telegram-class multi-device account synchronization

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-SYNC-002`
- **Stages**: `M2 realtime sync + M7 Bot identity + M8 Mini Apps`
- **Status**: `TESTING`
- **Started**: `2026-08-27`
- **Implementation PR**: `#2159` — merged as `18042e968f80c97efba6f8bc6878579348c21d3a`
- **Acceptance follow-up branch**: `test/tfi-m2-sync-packaged-recovery`
- **Source**: `../../source/2026-08-27-telegram-multidevice-account-sync.md`
- **Depends on**: `M2-SYNC-001`, `M8-MARKET-002`

## Objective

Promote the existing durable Messaging v2 cursor/journal mechanism from a transport-level second-device capability into one coherent **Fabushi account synchronization model**, including conversation/message history, added Bots, installed Mini Apps, Mini App cloud state and cross-device convergence.

The implementation intentionally keeps two durable synchronization domains instead of duplicating data:

1. **Messaging v2 cursor** — normal conversations/Bot conversations, messages, delivery/read state and realtime messaging.
2. **Account sync cursor (`as1:<sequence>`)** — installed Mini Apps, account-added Bot membership, Mini App CloudStorage and Mini App Bot/content invalidation events. Mini App Bot history itself stays in the existing central account message store and is reloaded when invalidated.

## Atomic deliverables

### M2-SYNC-002.A — stable account identity
- Replace token-hash Marketplace ownership with a canonical account scope resolved from authenticated account identity.
- Different device/session access tokens for the same account map to one account key.
- Device/session identity remains separate and auditable.
- **State**: IMPLEMENTED + branch-tested + merged.

### M2-SYNC-002.B — account sync state / difference protocol
- Add explicit account sync state and snapshot/delta response metadata around a durable account event journal.
- Detect ahead/expired/missing cursor and perform account-scoped snapshot recovery.
- Preserve pagination, idempotent projection and account isolation.
- **State**: IMPLEMENTED + branch-tested + merged.

### M2-SYNC-002.C — Bot add/remove synchronization
- Persist account-level added-Bot membership independently from global Bot registry/profile data.
- Add/remove operations emit durable account-scoped events.
- Snapshot/delta sync reconstructs added Bots on a new device.
- Manual Bot membership remains independent from a Mini App-owned Bot source.
- **State**: IMPLEMENTED + branch-tested + merged.

### M2-SYNC-002.D — Mini App install/uninstall synchronization
- Make installed Mini Apps account-scoped and durable.
- Installation/uninstallation emits the account sync stream and projects the manifest Bot identity into Contacts/Bots.
- New devices restore the account install list and reconcile missing local package bytes automatically.
- **State**: IMPLEMENTED + branch-tested + merged.

### M2-SYNC-002.E — Mini App cloud storage
- Add account + MiniApp scoped cloud key/value storage with revision/update events.
- Keep device-local and secure-device storage explicitly outside cloud sync.
- Expose list/get/set/delete through the authenticated native bridge and a Mini App iframe `FabushiMiniApp.CloudStorage` host API bound to the current app id.
- **State**: IMPLEMENTED + branch-tested + merged.

### M2-SYNC-002.F — Bot conversation/history convergence
- Normal/self-hosted Bot conversations remain on canonical Messaging v2 and inherit its durable message/read-state cursor.
- Mini App Bot messages no longer use renderer memory as authority; they persist in the existing central `user_id + plugin_instance_id` message store.
- Mini App message writes emit account-sync invalidation events so another device reloads canonical history.
- **State**: IMPLEMENTED + branch-tested + merged.

### M2-SYNC-002.G — desktop sync coordinator
- Persist the account sync cursor in renderer + native client persistence.
- Startup: restore local projection immediately, run Messaging v2 catch-up, then account catch-up.
- Online: account changes converge on the active 2-second foreground/background synchronization cadence; cursor gaps use difference recovery.
- Account switch/logout clears account-bound cursors/projections.
- **State**: IMPLEMENTED + renderer build-tested + merged.

### M2-SYNC-002.H — objective verification
- Existing Messaging v2 tests cover two-device actor/session cursor resume, restart and pruned-cursor snapshot recovery for canonical chat data.
- Backend integration uses different device/session tokens for the same account and verifies Mini App/Bot/history/CloudStorage/content convergence plus different-account isolation.
- Electron native bridge tests cover account sync, account Bot and Mini App package reconciliation APIs.
- Renderer TypeScript + Vite build proves the desktop coordinator/CloudStorage bridge compiles in the shipping renderer.
- Protected PR gates, merge queue, canonical-main packaged E2E screenshots/video/trace and Release evidence remain mandatory before completion.
- **State**: IMPLEMENTATION MERGED; packaged recovery acceptance follow-up in progress.

## Open-source-first decision

- Learn/adapt the update-state and get-difference behavior from `tdlib/td` (`Boost-1.0`), especially gap detection, durable state, pagination and restart catch-up.
- Learn/adapt Telegram official attachment-menu behavior: change events invalidate installed state and clients reconcile against an authoritative account list.
- Retain Fabushi Messaging Protocol v2 and Mahayana/Marketplace data models; do not copy MTProto/TL formats.

## Acceptance criteria

- One account is the server-side source of truth; a device is never the ownership namespace for account data.
- Two devices with different access tokens but the same authenticated account converge to the same added Bots, installed Mini Apps, Bot conversation/history state and Mini App cloud state.
- Offline devices catch up from durable deltas; old/pruned cursors recover via account-scoped snapshot without leaking another account's data.
- Mini App package bytes/runtime caches remain device-local, while installation entitlement/configuration is account-level.
- Secure device storage remains intentionally device-local and never enters general account sync.
- Account logout/switch cannot expose the previous account's cursor or projection.
- Exact-main packaged Electron acceptance must demonstrate install → Contacts/Bots → Bot chat → restart/history recovery → Mini App CloudStorage recovery and retain screenshot/video/trace evidence.

## Evidence

- Evidence index: `../../evidence/M2-SYNC-002/README.md`.
- Renderer integration gate: GitHub Actions run `33022386381` — SUCCESS (`git diff --check`, Native tests, Electron TypeScript + Vite renderer build).
- Two-device integration gate: GitHub Actions run `33022543329` — SUCCESS. Verified different session tokens for one account, Mini App install/Bot projection, Mini App Bot history, CloudStorage, content state, cursor difference replay, uninstall propagation and cross-account isolation.
- Implementation PR `#2159` merged through repository protection as exact main SHA `18042e968f80c97efba6f8bc6878579348c21d3a`.
- Exact-main Electron run `33024284365` and Native mobile run `33024284539` started from that SHA; their final outcome is not used as completion evidence until they finish.
- Acceptance follow-up commit `fa6c0d5802ff053e719bc77e1dec21d33086271f` strengthens `desktop/e2e/miniapp-bot-parity.spec.ts` with deterministic Bot history + `FabushiMiniApp.CloudStorage` restart recovery and explicit before/after screenshots; Playwright already records video + trace.
- Persistent regression tests: `ai-backend/test/account_sync_store.test.js`, `ai-backend/test/miniapp_marketplace_http.test.js`, `ai-backend/test/multidevice_account_sync_integration.test.js`, `desktop/electron/native-capability-handlers.test.cjs`.
- Completion remains blocked on the acceptance follow-up protected PR, its canonical-main packaged E2E, Native mobile success and the corresponding exact-SHA Release.
