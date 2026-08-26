# M8-MARKET-002 — OpenMaus avatar + Telegram Mini App Bot parity

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-002`
- **Stage**: `M7 Bot/Agent identity + M8 Mini Apps`
- **Status**: `TESTING`
- **Started**: `2026-08-27`
- **Branch**: `feat/tfi-m8-openmaus-avatar-miniapp-bot-parity`
- **Primary PR**: `#2158`
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

- **OpenMausBot** (`milind-soni/OpenMausBot`, Apache-2.0) is the avatar behavior/reference implementation. The exact `src/components/CursorAvatar.tsx` from commit `667af71ae7e93640ba4b1a5f3b38a1ad342025da` is vendored with SPDX/provenance comments and wrapped by Fabushi's existing `BotMark` API.
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

## Implementation evidence

- PR `#2158` carries the OpenMaus avatar engine and Telegram-style Mini App Bot lifecycle.
- `BotMark` normal identity now uses one base silhouette and stable identity color; hidden/unfocused windows set an effective paused state.
- Dense non-interactive identity surfaces (Stories and global search chat/channel/app/media results) pass `animated={false}` so they park instead of running continuous animation.
- Marketplace install state is projected into Messenger peers from manifest `bot` metadata; the same projected Bot is visible under Contacts and Bots and exposes the manifest Mini App menu button.
- Mini App Bot text goes through the authenticated `/v1/marketplace/plugins/:id/route` endpoint; install/uninstall also call the canonical authenticated add/remove lifecycle.
- Native capability unit coverage verifies add -> route -> remove all traverse `platform.request` with POST/POST/DELETE semantics.
- Dedicated Electron E2E `desktop/e2e/miniapp-bot-parity.spec.ts` covers UI install -> Contacts -> Bots -> slash command -> natural-language route -> Open Mini App.
- One-shot integration run `33018564067` succeeded, including pinned upstream vendoring, deterministic edits, native capability tests and `git diff --check`.
- Electron fast-path on commit `fec871c31b534e0764999fc7fde3460e712baa34` passed architecture/UI contracts, main-process tests and renderer TypeScript after the motion guard was migrated from hard-coded Grok geometry to the pinned OpenMaus contract.
- Dense-avatar applicator run `33019006903` succeeded and deleted its temporary workflow after committing the reviewed static-surface changes.

## Remaining verification

- Current PR-head required gates must pass after this human-authored evidence commit.
- Protected merge and canonical `main` readback are still required.
- Exact-main packaged Electron E2E evidence and release evidence are still required before status can advance from `TESTING` to `TESTED`.
