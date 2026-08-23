# M7-DESKTOP-003 Evidence

- Project: `FAB-P0001 / TFI`
- Task: `M7-DESKTOP-003`
- Branch: `feat/tfi-m7-unified-search-resizable-sidebar`
- Status: `IMPLEMENTED` (GitHub CI / protected merge pending)
- Date: 2026-08-23

## Implementation evidence

- `desktop/src/messaging-shell-v2.tsx`
  - removed the permanent feature `navRail` from the authenticated Messenger;
  - added bottom-left `profile-navigation-trigger` and menu for Chats/Contacts/Bots/Groups/Channels/Calls/Saved/Archive/Folders/Mini Apps/Payments/Settings;
  - added persisted resizable sidebar with pointer drag and avatar-only collapse;
  - converted peer/story/call/dialog/Mini App identities to canonical `BotMark` / `fabushi-motion-v2`;
  - added `GlobalSearchWorkspace` with 11 category tabs;
  - reused live Marketplace data/actions inside the “应用” search tab.
- `desktop/src/messaging-shell.module.css`
  - added Grok/Fabushi dark-glass personal menu, resizer, collapsed avatar rail, categorized search surface and dark Marketplace styling.
- `desktop/e2e/messenger.spec.ts`
  - asserts personal navigation contents;
  - asserts collapsed/expanded sidebar geometry;
  - asserts all 11 search tabs;
  - opens the installed `global-dharma` Mini App through global Application search.
- `desktop/e2e/smoke.spec.ts`, `desktop/e2e/surfaces.spec.ts`
  - updated canonical navigation expectations to the personal-avatar menu.

## Local lightweight verification

Per repository policy, no local Electron build, Playwright, Cargo, package build or heavyweight test was executed.

- `git diff --check` — PASS.
- source marker inspection — PASS for `profile-navigation-trigger`, `sidebar-resizer`, global search tabs, unified `peer:*` BotMark and `miniapp:*` BotMark identities.

## Pending objective evidence

- GitHub Actions current-head relevant gates.
- protected PR merge.
- canonical `main` readback.
- final packaged desktop visual acceptance.
