# M8-MARKET-002 — OpenMaus avatar + Telegram Mini App Bot parity

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-002`
- **Stage**: `M7 Bot/Agent identity + M8 Mini Apps`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-27`
- **Branch**: `feat/tfi-m8-openmaus-avatar-miniapp-bot-parity`
- **Source**: `../../source/2026-08-27-openmaus-avatar-telegram-miniapp-bot-parity.md`

## Deliverables

1. Replace irregular bot-id-hashed avatar silhouettes with an OpenMaus-aligned unified mascot silhouette and expression/state behavior.
2. Add explicit static/animated control, hidden-page/window pause behavior, parked rendering and reduced-motion behavior so dense lists do not keep the GPU busy.
3. Keep dense surfaces (search, group stacks, maps and equivalent list-only identity surfaces) static unless the active/working state requires motion.
4. Extend Marketplace summaries/install state with canonical Mini App Bot metadata.
5. Project every installed Mini App's default Bot into Messenger peers so it is visible in Contacts and Bots, opens a conversation, supports slash/natural-language routing and exposes Open Mini App.
6. Remove the projected Bot when the Mini App is uninstalled without deleting unrelated user conversations.
7. Add objective tests for identity stability, install/uninstall projection and the complete packaged Electron user journey.

## Open-source-first decision

- **OpenMausBot** (`milind-soni/OpenMausBot`, Apache-2.0) is the avatar behavior/reference implementation. Reuse/adapt its unified mascot, `animated`/`paused` contract, parked rendering and page visibility strategy with provenance retained.
- **Telegram Mini Apps/Bots** are the product lifecycle reference. The Mini App is attached to a Bot identity; Fabushi adapts this into its own canonical Messenger/Host model rather than cloning Telegram protocol/storage.
- Existing Fabushi `BotMark`, Messenger peer model, Marketplace/Plugin installer, Mahayana command routing and self-hosted messaging remain the integration boundaries; no second messaging stack is introduced.

## Acceptance criteria

- All Bot/Agent/Mini App mascot identities share one consistent base silhouette; no `botId -> blob/pebble/tablet/wedge/hex/cloud/teardrop` visual lottery remains in the normal identity path.
- Hidden or unfocused app windows do not continuously animate avatars; paused/static avatars do not continuously repaint.
- Installing a Marketplace Mini App immediately yields a peer with the manifest Bot id/name/description in both Contacts and Bots views.
- Opening that peer can send normal text to the Mini App Bot route; `/` commands are derived from the installed Mini App command catalog; the Bot UI exposes the Mini App launch action.
- Uninstall removes the generated Mini App Bot peer while preserving unrelated conversations/data.
- Typecheck/unit/integration tests pass on PR head.
- After protected merge, exact canonical `main` packaged Electron E2E captures screenshots, full video, trace/results for install -> Contacts/Bots -> chat -> open Mini App; a newer Release is published only after required gates pass.

## Evidence

- Source/architecture research: OpenMausBot Apache-2.0 avatar files and Telegram official Mini Apps/Bot documentation.
- Implementation/PR/CI/Release evidence will be appended before status can advance beyond `IN_PROGRESS`.
