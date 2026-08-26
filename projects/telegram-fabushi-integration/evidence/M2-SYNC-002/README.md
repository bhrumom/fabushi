# M2-SYNC-002 — Telegram-class multi-device account synchronization evidence

## Scope

This task extends the already-tested Messaging Protocol v2 cursor/journal layer into an account-wide synchronization model for Fabushi. The implementation deliberately keeps two durable synchronization domains:

1. **Messaging v2 cursor** — conversations, messages, delivery/read state, communities and canonical realtime messaging.
2. **Account sync cursor (`as1:<sequence>`)** — installed Mini Apps, account-added Bot memberships, Mini App CloudStorage revisions and Mini App Bot/content invalidation events.

The desktop coordinator advances both. This avoids duplicating the full message corpus into a second event store while preserving Telegram-style snapshot + difference recovery semantics.

## Implemented account semantics

- Stable account identity is resolved from the authenticated Fabushi user, never from a bearer-token hash.
- Different session/access tokens for the same user map to the same account namespace.
- Installed Mini Apps are account state. A second device restores the entitlement and reconciles the local package automatically.
- Each installed Mini App projects its manifest Bot into account Bot membership, Contacts/Bots and the Mini App Bot conversation surface.
- Manual Bot membership is a separate source; uninstalling a Mini App does not remove a separately-added Bot.
- Mini App Bot messages use the existing central `user_id + plugin_instance_id` message store instead of renderer memory as authority.
- Mini App message/content writes emit lightweight account-sync invalidation events; other devices reload canonical history/state.
- Mini App CloudStorage is account + MiniApp scoped, bounded to 1024 keys, 1-128 character keys and 4096-byte values. Cloud state survives uninstall.
- Device-local package bytes/cache, OS permissions and SecureStorage remain intentionally device-local.
- Account logout/reset clears account cursor/projection mirrors.
- Account sync supports initial snapshot, cursor difference, pagination, invalid/ahead cursor recovery and retained-floor snapshot fallback.
- Online desktop convergence runs on the active 2-second sync cadence; offline/restarted devices resume from the durable cursor.

## Objective verification

### Backend + native implementation gate

GitHub Actions one-shot integration gates proved the deterministic backend/native integration before the generated code was committed. The final native/backend generated integration run passed:

- account sync + Marketplace tests;
- Native capability handler tests;
- `git diff --check`.

### Renderer gate

Workflow run `33022386381` (`TFI multi-device renderer finalizer v3`) completed SUCCESS on 2026-08-26/27 UTC boundary:

- deterministic renderer integration: SUCCESS;
- `git diff --check`: SUCCESS;
- Native account bridge tests: SUCCESS;
- Electron dependency install: SUCCESS;
- renderer TypeScript + Vite bundle (`npm run build:renderer`): SUCCESS;
- verified renderer code committed back to the feature branch.

### Two-device account integration gate

Workflow run `33022543329` (`TFI multi-device synchronization verification`) completed SUCCESS and exercised two distinct device/session identities against one shared account store:

1. Device B captured an initial account cursor.
2. Device A installed `global-dharma`.
3. Device B observed the installed Mini App and `global-dharma-bot` without reinstalling.
4. Device A persisted a Mini App Bot user command and assistant reply.
5. Device B loaded the identical Bot message history from the central account store.
6. Device A wrote Mini App CloudStorage and content state; Device B read the same state.
7. Device B replayed account deltas from its old cursor and received install/Bot/message/cloud/content events in order.
8. A third account observed none of Device A/B's apps, Bot history or CloudStorage.
9. Device A uninstalled the Mini App; Device B observed Mini App/Bot membership removal while Bot history and CloudStorage remained preserved.
10. Backend source syntax checks, Native bridge tests and Electron renderer build all passed in the same workflow.

Persistent regression tests:

- `ai-backend/test/account_sync_store.test.js`
- `ai-backend/test/miniapp_marketplace_http.test.js`
- `ai-backend/test/multidevice_account_sync_integration.test.js`
- `desktop/electron/native-capability-handlers.test.cjs`

## Telegram / open-source reference

- Telegram official update semantics (`pts/qts/seq`, `updates.getDifference`) informed durable cursor/difference and safe snapshot fallback behavior.
- Telegram attachment-menu Mini App semantics informed account-level install membership and Bot projection behavior.
- `tdlib/td` (Boost Software License 1.0) was used as an architectural reference for durable update state, gap recovery and difference replay. Fabushi retains its own protocol and storage formats.

## Remaining completion gates

This evidence is **pre-merge**. `M2-SYNC-002` must remain `IN_PROGRESS / TESTING` until all of the following are true:

- protected PR current-head gates pass;
- merge queue/merge-group checks pass;
- canonical `main` is read back at the merged SHA;
- exact-main packaged Electron E2E records the install → Contacts/Bots → Bot chat/history → Mini App/CloudStorage recovery journey with screenshots/video/trace where supported;
- the corresponding newer Release is published only after the canonical-main package gate succeeds.
