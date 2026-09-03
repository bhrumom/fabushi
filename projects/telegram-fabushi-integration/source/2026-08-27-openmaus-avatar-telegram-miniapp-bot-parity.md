# 2026-08-27 — OpenMaus avatar + Telegram Mini App bot parity

## User requirement

- Learn the relevant OpenMausBot repository settings/implementation and fuse them into Fabushi so the avatar experience matches OpenMausBot rather than the current irregular multi-shape identity system.
- Preserve the OpenMausBot low-power behavior: explicit animated/static control, parked rendering for paused mascots, page visibility awareness, reduced-motion support, and static rendering on dense surfaces.
- Mini Apps must expose a corresponding Bot after installation. The Bot must be visible in both Contacts and Bots, have a conversation, accept natural-language and slash-command input, and expose an Open Mini App menu action.
- Align the Mini App/Bot lifecycle with Telegram: a Mini App belongs to a Bot identity; adding/installing the app makes that bot/chat identity available instead of treating the app as a disconnected marketplace card.
- Verify the complete install -> Bot/Contact -> chat -> slash/natural-language -> open Mini App journey with Electron E2E and canonical-main package evidence.

## Upstream learning / provenance

- OpenMausBot: https://github.com/milind-soni/OpenMausBot — Apache-2.0.
- Relevant upstream implementation: `src/components/CursorAvatar.tsx`, `src/components/Avatar.tsx`, `src/lib/page-visible.ts`, sidebar/search/team-map avatar call sites, and Electron lifecycle choices.
- Telegram Mini Apps: https://core.telegram.org/bots/webapps and Bot features/BotFather documentation. Product model learned: the Bot is the Mini App identity and launch center; Mini App attachment/menu/main-app metadata is configured on that Bot.

## Fabushi adaptation boundary

Fabushi keeps its own messaging/runtime/protocol boundaries. The upstream avatar behavior is adapted into Fabushi components with attribution; Mini App installation projects manifest `bot` metadata into Fabushi's canonical Messenger identity rather than introducing a second chat system.