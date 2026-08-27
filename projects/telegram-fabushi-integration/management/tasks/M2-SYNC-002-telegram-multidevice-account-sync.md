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
- **Active acceptance branch**: `fix/tfi-m2-sync-e2e-peer-identity`
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
- Exact-main packaged Electron acceptance covers install → Contacts/Bots → Bot chat → restart/history recovery → Mini App CloudStorage recovery and retains screenshot/video/trace evidence.
- Protected PR gates, merge queue, canonical-main packaged E2E and exact-SHA Release remain mandatory before completion.
- **State**: TESTING — product projection is visible; final E2E locator now being aligned to canonical user-facing Bot identity.

## Exact-main regression found during acceptance

Electron exact-main run `33024284365` against `18042e968f80c97efba6f8bc6878579348c21d3a` correctly failed before packaging. The diagnostic UI reported:

`No handler registered for 'fabushi-edge:native-desktop:call:addMiniAppToAccount'`.

Root cause: the account-sync methods existed in `native-capability-handlers.cjs` and direct handler tests passed, but `desktop/electron/native-edge.cjs` had not allowlisted the new account-sync surface. Therefore renderer calls could not cross the shipping Electron IPC boundary. The same acceptance also showed that real-Host E2E test mode needs deterministic account-platform persistence rather than accidentally depending on product-network authentication after the local Feature Host login.

The repair branch therefore:
- exposes the complete account-sync method set on `NATIVE_EDGE`;
- adds a regression contract test that fails if any account-sync method is missing from the edge;
- adds a deterministic, file-backed test account platform used only when `FABUSHI_FEATURE_HOST_MODE=test` so the real Rust Host E2E remains network-free while preserving Mini App installs, Bot memberships, Bot history, CloudStorage and account cursor across process restart;
- leaves production `platform.request` behavior unchanged.

## Second exact-main acceptance result

Electron exact-main run `33025670225` against `ab6e3eb4787f9570aaff00342362000e1e960973` again blocked release before Linux packaging. This run proved the native-edge repair itself is active: edge parity reported 184 methods, all 37 Electron main-process tests passed, including account-sync edge coverage and deterministic test-account restart persistence. The remaining failures were acceptance-test contract drift rather than a missing product edge:

- the real UI successfully opened the Global Dharma iframe and displayed `Mini App · 已安装线上包 · 账号云同步`, while two older E2E assertions still expected the historical `受控宿主容器` copy;
- `miniapp-bot-parity.spec.ts` checked onboarding/login selectors before the first DOM surface had stabilized, so the onboarding dialog could mount after the helper had already moved on to waiting for Messenger. Other long-lived E2E helpers already guard this race with an initial surface poll.

Diagnostic artifact `9628343898` (`fabushi-electron-linux-e2e-diagnostics`) contains screenshots, traces and error contexts. PR `#2162` synchronized assertions to the current product copy and adopted the established deterministic first-surface wait before onboarding/login handling. Product sync semantics were unchanged.

## Third exact-main acceptance result

Electron exact-main run `33026283621` against `f565e46d070ce6f23183d861fee6cda589eca460` reduced the real-Host suite to a single failure. Diagnostic artifact `9628549449` proves the product requirement itself is already satisfied: after installation, the Contacts rail visibly contains a button named `全球法布施 … @global_dharma_bot` while the failing assertion waits for the internal test id `peer-miniapp:bot:global-dharma`.

This is expected after account-level Bot convergence. Messenger deduplicates a Mini App-owned Bot against an existing canonical Bot identity; therefore the same visible Bot may be backed by a canonical Bot peer key instead of the temporary `miniapp:bot:*` projection key. The internal peer key is not a product contract. The acceptance test is being repaired to assert and open the Bot by its stable user-facing identity `@global_dharma_bot`, in both Contacts and Bots, while retaining all downstream history/CloudStorage restart assertions.

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
- Implementation PR `#2159` merged as exact main SHA `18042e968f80c97efba6f8bc6878579348c21d3a`.
- Packaged acceptance PR `#2160` merged as `69bafdbd726ba78e99f3dd69700183f00851a970`, strengthening `desktop/e2e/miniapp-bot-parity.spec.ts` with Bot history + `FabushiMiniApp.CloudStorage` restart recovery, before/after screenshots, and existing Playwright video + trace capture.
- Native product-edge PR `#2161` merged as `ab6e3eb4787f9570aaff00342362000e1e960973`; its current-head protected gates all passed.
- E2E shell-contract PR `#2162` merged as `f565e46d070ce6f23183d861fee6cda589eca460`; all protected gates passed.
- First exact-main Electron run `33024284365` failed before packaging; artifact id `9627834782` captured the missing native-edge handler.
- Second exact-main Electron run `33025670225` failed after native-edge repair; artifact id `9628343898` proved product UI success plus stale copy/first-surface test drift. Exact-main Native mobile run `33025670242` succeeded on iOS SwiftUI and Android Compose simulated user tests.
- Third exact-main Electron run `33026283621` has a single real-Host failure; artifact id `9628549449` proves the Global Dharma Bot is present in Contacts under canonical visible identity while the test still expected a projection-specific peer key. This run is regression evidence, not completion evidence.
- Persistent regression tests include `ai-backend/test/account_sync_store.test.js`, `ai-backend/test/miniapp_marketplace_http.test.js`, `ai-backend/test/multidevice_account_sync_integration.test.js`, `desktop/electron/native-capability-handlers.test.cjs`, and `desktop/electron/edge-ipc.test.cjs`.
- **Completion remains blocked** until the canonical Bot-identity E2E repair is protected/merged, the next exact-main Electron + Native delivery succeeds, packaged E2E evidence is archived, and the matching exact-SHA Release is published.
