# 2026-08-27 — Telegram-style multi-device account sync

## User requirement

Implement Telegram-class multi-device synchronization across Fabushi, with special emphasis on:

- conversation/message history;
- Bot add/contact state and Bot conversations;
- installed Mini Apps / plugins;
- Mini App account-level cloud data and permissions;
- recovery on another device after login;
- realtime propagation while multiple devices are online;
- offline catch-up with cursor/delta recovery after reconnect.

The expected product behavior is account-scoped rather than device-scoped: if one authenticated device installs a Mini App, adds a Bot, sends/receives Bot messages, or changes account-level Mini App state, another device logged into the same Fabushi account must converge to the same state without a second manual install/add operation.

## Telegram reference semantics to adapt

1. Telegram clients maintain durable update state (`pts` / `qts` / `seq`) and use `updates.getDifference` / channel difference for startup catch-up and gap recovery.
2. Attachment/side-menu Mini Apps are account state: `messages.toggleBotInAttachMenu` changes the installed list, other clients receive `updateAttachMenuBots`, then re-fetch the authoritative installed list with `messages.getAttachMenuBots`.
3. The Mini App is attached to a Bot identity rather than being a disconnected local package record.
4. Mini App small cloud state is scoped by user + bot/app; device-only and secure-device storage remain local by design.

Fabushi must adapt these semantics to its own Rust Messaging v2 / Mahayana / Marketplace architecture and must not depend on Telegram network APIs.

## Open-source-first research

- `tdlib/td` (`Boost Software License 1.0`): use its UpdatesManager architecture as a reference for durable update state, gap detection, recursive difference fetching, deduplication and restart recovery.
- Telegram official protocol documentation: use update sequence / getDifference and attachment-menu lifecycle as behavioral references.
- Do not copy Telegram protocol or storage formats; preserve Fabushi's own protocol and account model.

## Required acceptance journey

1. Device A and Device B authenticate to the same account with different device/session IDs and independently issued access tokens.
2. Device A installs a Marketplace Mini App.
3. Device B receives/catches up the account-level install event and sees the same Mini App plus its Bot in Mini Apps, Contacts and Bots.
4. Device A opens the Mini App Bot, sends messages/commands, and receives Bot replies; Device B catches up the same conversation history/read state.
5. Device A changes Mini App cloud storage; Device B reads the updated value after sync.
6. Device A uninstalls the Mini App; Device B removes the installed projection/Bot association while unrelated conversations remain intact.
7. Device B may be offline during steps 2–6 and must recover by durable cursor/difference after reconnect; expired/pruned cursor must fall back to an account-scoped snapshot plus new deltas.
8. No device-local token hash may define account identity; different valid tokens for the same account must resolve to the same account scope.
