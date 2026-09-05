# M8-BIND-001 — One MiniApp install -> one default Bot actor/direct conversation

- Project: `FAB-P0001 / TFI`
- Task ID: `M8-BIND-001`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `1`
- Risk: high; identity/account-sync lifecycle

## Single objective

Enforce and expose the Telegram-like account-scoped relationship: each current MiniApp install has exactly one default Bot actor and one direct conversation, with durable permissions/update/uninstall/restore audit.

## Dependency

`M8-ENTITY-001` complete on an exact reviewed head.

## Exact implementation allowlist

- `native/mahayana-messaging/src/miniapp.rs`
- `native/mahayana-messaging/src/bot.rs`
- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/engine.rs`
- `ai-backend/src/account_sync_store.js`
- `ai-backend/src/miniapp_marketplace.js`
- `desktop/src/account-sync-client.ts`
- `ai-backend/test/multidevice_account_sync_integration.test.js`
- `desktop/e2e/miniapp-bot-parity.spec.ts`
- `projects/telegram-fabushi-integration/evidence/M8-BIND-001/**`

Forbidden: Mahayana session implementation, remote-device transport, generic Contacts redesign, release/workflow/version files.

## Acceptance

1. Current install has non-null `install_id`, `bot_actor_id`, `bot_conversation_id`, version/digest and permission revision after `BotBound`.
2. Unique invariants prevent duplicate current install/Bot/direct-conversation bindings for `(account_id, mini_app_id)`.
3. Reinstall/restore deterministically reuses or migrates the previous Bot/conversation per explicit policy; it never silently creates duplicate peers.
4. Uninstall removes the generated current Bot projection only when no other ownership requires it and preserves unrelated user conversations/history.
5. Update changes version/digest and permission revision atomically; newly requested privileges require explicit approval.
6. Two same-account devices converge to the same install/Bot/conversation identity; different accounts do not.
7. Audit can answer install/update/uninstall/restore actor, target install, Bot, conversation, permission revision and causation id.

## CI / E2E evidence

Native serialization/state tests, backend account-sync multidevice tests, packaged Electron install -> Contacts/Bots -> direct chat -> open MiniApp -> update -> uninstall -> restore journey with screenshots/video/trace.

## Rollback

Disable new binding writes only with a compatibility reader that keeps old projections functional. Do not delete unrelated conversations; revert of this task must leave M8-ENTITY-001 durable install data intact.
