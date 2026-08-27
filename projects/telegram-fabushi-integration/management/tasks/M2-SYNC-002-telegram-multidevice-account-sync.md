# M2-SYNC-002 — Telegram-class multi-device account synchronization

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-SYNC-002`
- **Stages**: `M2 realtime sync + M7 Bot identity + M8 Mini Apps`
- **Status**: `TESTING`
- **Started**: `2026-08-27`
- **Implementation PR**: `#2159` — merged as `18042e968f80c97efba6f8bc6878579348c21d3a`
- **Packaged acceptance PR**: `#2160` — merged as `69bafdbd726ba78e99f3dd69700183f00851a970`
- **Native product-edge repair PR**: `#2161` — merged as `ab6e3eb4787f9570aaff00342362000e1e960973`
- **E2E shell-contract repair PR**: `#2162` — merged as `f565e46d070ce6f23183d861fee6cda589eca460`
- **Canonical Bot-identity E2E PR**: `#2163` — merged as `9c06c53572f7c95996cd59b05401f1b978d85db6`
- **Active repair branch**: `fix/tfi-m2-sync-miniapp-command-projection`
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
- **State**: IMPLEMENTED + branch-tested + merged; final packaged acceptance pending.

### M2-SYNC-002.E — Mini App cloud storage
- Add account + MiniApp scoped cloud key/value storage with revision/update events.
- Keep device-local and secure-device storage explicitly outside cloud sync.
- Expose list/get/set/delete through the authenticated native bridge and a Mini App iframe `FabushiMiniApp.CloudStorage` host API bound to the current app id.
- **State**: IMPLEMENTED + branch-tested + merged; final packaged recovery proof pending.

### M2-SYNC-002.F — Bot conversation/history convergence
- Normal/self-hosted Bot conversations remain on canonical Messaging v2 and inherit its durable message/read-state cursor.
- Mini App Bot messages no longer use renderer memory as authority; they persist in the existing central `user_id + plugin_instance_id` message store.
- Mini App message writes emit account-sync invalidation events so another device reloads canonical history.
- **State**: IMPLEMENTED + branch-tested + merged; final packaged recovery proof pending.

### M2-SYNC-002.G — desktop sync coordinator
- Persist the account sync cursor in renderer + native client persistence.
- Startup: restore local projection immediately, run Messaging v2 catch-up, then account catch-up.
- Online: account changes converge on the active 2-second foreground/background synchronization cadence; cursor gaps use difference recovery.
- Account switch/logout clears account-bound cursors/projections.
- **State**: IMPLEMENTED + renderer build-tested + merged; shipping IPC contract repaired and verified.

### M2-SYNC-002.H — objective verification
- Existing Messaging v2 tests cover two-device actor/session cursor resume, restart and pruned-cursor snapshot recovery for canonical chat data.
- Backend integration uses different device/session tokens for the same account and verifies Mini App/Bot/history/CloudStorage/content convergence plus different-account isolation.
- Electron native bridge tests cover account sync, account Bot and Mini App package reconciliation APIs.
- Renderer TypeScript + Vite build proves the desktop coordinator/CloudStorage bridge compiles in the shipping renderer.
- Exact-main packaged Electron acceptance covers install → Contacts/Bots → `/` commands → Bot chat → restart/history recovery → Mini App CloudStorage recovery and retains screenshot/video/trace evidence.
- Protected PR gates, merge queue, canonical-main packaged E2E and exact-SHA Release remain mandatory before completion.
- **State**: TESTING — fourth exact-main run found a real Marketplace-to-Messenger command metadata projection gap; repair implemented on active branch.

## Exact-main acceptance history

### First exact-main — shipping IPC gap
Electron run `33024284365` on `18042e968f80c97efba6f8bc6878579348c21d3a` failed before packaging with:

`No handler registered for 'fabushi-edge:native-desktop:call:addMiniAppToAccount'`.

Root cause: account-sync handlers existed, but the shipping `native-edge.cjs` allowlist omitted them. PR `#2161` exposed the complete edge and added deterministic file-backed test-account platform persistence for installs, Bot membership, history, CloudStorage and account cursor while leaving production `platform.request` unchanged. Artifact: `9627834782`.

### Second exact-main — stale shell test contract
Electron run `33025670225` on `ab6e3eb4787f9570aaff00342362000e1e960973` proved native-edge parity and all main-process tests were green, but old E2E assertions expected historical copy and the new recovery helper had a first-surface race. PR `#2162` aligned tests to the shipping `账号云同步` copy and established first-surface stabilization. Artifact: `9628343898`. Native run `33025670242` passed iOS SwiftUI and Android Compose simulated-user tests.

### Third exact-main — internal peer-key coupling
Electron run `33026283621` on `f565e46d070ce6f23183d861fee6cda589eca460` reduced the real-Host suite to one failure. Artifact `9628549449` proved the Global Dharma Bot was visibly present as `全球法布施 … @global_dharma_bot`; the test was still coupled to temporary `miniapp:bot:*` peer keys. PR `#2163` moved acceptance to the stable user-facing Bot identity.

### Fourth exact-main — canonical commands dropped
Electron run `33026757416` on `9c06c53572f7c95996cd59b05401f1b978d85db6` passed 20/21 real Rust Host user journeys. The only remaining failure occurred after the synchronized `@global_dharma_bot` was opened successfully: entering `/` did not render `miniapp-bot-commands`. Artifact `9628733328` shows the Bot is open and the composer contains `/`, but no command menu exists.

This is a real product projection bug, not test drift. `browseMarketplace()` returns canonical `bot` and `commands` metadata at the **top level** of each Marketplace plugin, while `miniAppBotProjection()` only read `source.bot/source.commands` and `releaseManifest.bot/releaseManifest.commands`. Account-level Bot convergence therefore preserved the visible Bot identity and Mini App launch link but could drop its slash-command catalog.

The active repair:
- extends `MarketplacePluginSummary` to type canonical top-level `bot`, `commands`, `surfaces` and `installMode` metadata;
- makes `miniAppBotProjection()` prefer top-level `app.bot` and `app.commands`, retaining legacy source/release fallbacks;
- preserves an explicit server-provided slash usage when present;
- extends the fast product UI contract gate so Marketplace top-level Bot/command output and Messenger consumption cannot silently diverge again.

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
- Exact-main packaged Electron acceptance must demonstrate install → Contacts/Bots → `/` command catalog → Bot chat → restart/history recovery → Mini App CloudStorage recovery and retain screenshot/video/trace evidence.

## Evidence

- Evidence index: `../../evidence/M2-SYNC-002/README.md`.
- Renderer integration gate: GitHub Actions run `33022386381` — SUCCESS.
- Two-device integration gate: GitHub Actions run `33022543329` — SUCCESS; different session tokens for one account converged Mini App install/Bot projection/history/CloudStorage/content state, difference replay and uninstall, with cross-account isolation.
- PRs `#2159`, `#2160`, `#2161`, `#2162`, `#2163` are merged through protected `main`.
- Fourth exact-main run `33026757416`: 20/21 real-Host journeys passed; artifact `9628733328` captured the missing slash-command menu after canonical Bot convergence. This is regression evidence, not completion evidence.
- Persistent regression tests include `ai-backend/test/account_sync_store.test.js`, `ai-backend/test/miniapp_marketplace_http.test.js`, `ai-backend/test/multidevice_account_sync_integration.test.js`, `desktop/electron/native-capability-handlers.test.cjs`, `desktop/electron/edge-ipc.test.cjs`, the product UI contract gate, and `desktop/e2e/miniapp-bot-parity.spec.ts`.
- **Completion remains blocked** until the command-projection repair is protected/merged, a new exact-main Electron + Native delivery succeeds, packaged recovery evidence is archived, and the matching exact-SHA Release is published.
