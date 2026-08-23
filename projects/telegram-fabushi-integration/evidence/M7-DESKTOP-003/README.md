# M7-DESKTOP-003 Evidence

- Project: `FAB-P0001 / TFI`
- Task: `M7-DESKTOP-003`
- Branch: `feat/tfi-m7-unified-search-resizable-sidebar`
- Status: `TESTING` (post-merge CI repair in progress)
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


## Post-merge gate evidence

- #2057 merged: `ebfb1e090cb677b6d9d35edff3ad912819f3fba6`.
- Electron desktop quality gate `32637615241` failed only at renderer typecheck: TS2367 comparing `WebRtcCallStatus` with unsupported literal `connected`.
- Messaging Product Gate `32637615272` failed only at the same Electron typecheck; Rust self-hosted product passed.
- Canonical `WebRtcCallStatus` = `idle | ringing | connecting | active | ended | failed`; repair maps live-call BotMark state from `active` to `speaking`.


## Final package-verification evidence

- Repair PR #2058 merged: `947f537f8ebe4c762a09c6ac66150d50b5bda724`.
- PR #2058 Electron Messenger contract reached successful TypeScript typecheck after switching to canonical `active`.
- Follow-up E2E guard verifies `profile-navigation-trigger` contains a `data-engine="fabushi-motion-v2"` identity.
- Because `desktop/e2e/**` is a canonical package-classifier path, the follow-up PR and its eventual main merge exercise the package matrix needed for macOS installation evidence.


## Runtime-smoke failure and repair evidence

- #2059 main merge: `ae70c06f4286097d2f90c43d047b77845173d9cf`.
- Electron runtime smoke run `32638060949` failed with three concrete errors:
  - Messenger Mini App global search: `global-search-app-global-dharma` not found.
  - Smoke Mini App journey: legacy UI locator for `全球法布施` timed out after the permanent navigation/Marketplace convergence.
  - Native surface: `getMcpCatalog` returned `bridge/invoke-failed: invalid request: unknown method marketplace.browse`; first attempt also demonstrated the native-menu event registration race on `open-offline-asr`.
- Current repair:
  - AppHost stores its explicit feature mode and exposes deterministic Marketplace browse/release/install behavior only in `Test`; Production remains backed by `MahayanaProductClient` and verified external releases.
  - Native Electron capabilities call `feature.marketplace.*` / `feature.plugin.*` only, with desktop plugin platform normalization.
  - Global search E2E performs visible online-app discovery, installation and opening through the same UI users see.
  - Native-menu probe is fully registered before the main-process menu click.


## Final E2E contract-alignment evidence

- #2060 merge: `bcd0951396a7efe9f5f37aaa5b0ea38c35ec6220`.
- Electron runtime run `32638779651` artifact `electron-runtime-smoke-failure-32638779651-1` shows the Mini App did open successfully: `全球法布施`, subtitle `Mini App · 已安装线上包 · 受控宿主容器`, and iframe are present in the failure snapshot.
- Therefore the remaining Mini App failure was an obsolete expected string (`Mini App · 受控宿主容器`), not a Host/Marketplace/UI-open defect.
- The personal navigation failure is a Playwright strict-mode ambiguity because the Motion-v2 wrapper and its SVG both expose `data-engine`; selecting `.first()` preserves the intended engine assertion.
