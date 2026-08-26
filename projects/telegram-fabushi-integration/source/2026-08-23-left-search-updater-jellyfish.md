# 2026-08-23 — Left-column search, Grok-like living identity, desktop updater and jellyfish icon

## User requirements

1. Search must stay in the left conversation column. Opening the search field must not replace the right conversation workspace.
2. Clicking search from inside a conversation must reuse the same left search input and add a current-conversation scope, matching Telegram's behavior: only content from the active peer is searched.
3. Remove the always-visible `新建群组`, `新建频道`, and `我的动态` entries from the message/list surface. Group/channel creation may remain available through a compact create menu.
4. Converge the visual language toward the referenced Grok Bot UI: restrained chrome, organic three-dimensional living BotMark identities, and less flat/geometric avatar silhouettes.
5. Future macOS DMG packages must be immutable GitHub Release assets. Release output must also include the updater feed artifacts needed for old clients to discover a newer version.
6. When a newer desktop version is available, show a cloud-update control next to the personal avatar. One click downloads the update, replaces the installed version and relaunches the app.
7. Replace the desktop application icon with a cute minimalist jellyfish; no white border/background around the icon.

## Reference behavior

- Telegram reference: conversation search reuses the left search column with a peer filter rather than injecting a second search bar into the chat pane.
- Grok Bot reference: identity marks are soft, dimensional, lively and visually simple; update affordance appears adjacent to the account/avatar area.

## Non-goals

- Do not remove the underlying group/channel or Story runtime capabilities.
- Do not introduce Telegram API dependency.
- Do not introduce a second search backend or second avatar engine.
