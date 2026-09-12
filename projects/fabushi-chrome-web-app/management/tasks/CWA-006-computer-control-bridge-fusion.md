# CWA-006 — Computer Control Bridge fusion, release and migration

- Portfolio Project: FAB-P0011
- Project Key / Task ID: CWA / CWA-006
- Objective: ship Fabushi Chrome 0.5.0 as the sole product/browser-control/userscript
  extension, preserving the old Bridge contract and Fabushi 0.4.1 surfaces, then complete
  verified release and profile migration.
- Source: source/2026-09-12-user-requirement.md and approved CWA plan.
- Branch: codex/cwa-006-computer-control-bridge-fusion-20260912
- Registry allocation baseline: canonical main `656d05e8d66bfed241f5b9d871a062abfbf2f952`
- PR: pending creation/merge; status in-progress.
- Started: 2026-09-12; updated: 2026-09-12; completed: null.

## Scope and dependencies

In scope are the three MV3 modules, dual native hosts, all nine commands and eight actions,
tab/CDP/download lifecycle, generation fail-closed claims, 0.4.1 product UI and userscript
runner (including the bundled auto-confirm workbench and Task Queue companion), deterministic
package/Web Store workflow, and Mac Default/Profile 2 migration. Out of scope are official
ChatGPT non-Bridge features, shared Computer Use runtime/native helpers, and runtime-loaded
remote JavaScript.

Dependencies are FCM protected-main/release gates, MSR Mahayana Host, AAC account boundary,
GBF-409 capability (not a duplicate project), Web Store review, and access to the two local
Chrome profiles.

## Open-source survey and reuse decision

Surveyed official Chrome Native Messaging and Debugger API docs plus GoogleChrome
nativeMessaging/Debugger samples. Reused only public framing, lifecycle and API model; no
third-party implementation was copied. The old codex/fabushi-chrome-userscripts branch was
selectively mined for secure userscript validation, platform server and packaging shape,
then adapted to include the approved 0.4.1 userscript runner and bundled automation source
rather than the earlier branch's exclusion.

## Acceptance criteria and verification

1. Manifest is MV3 0.5.0 with debugger, nativeMessaging, downloads, tabs, tabGroups,
   webNavigation, scripting, userScripts, storage, alarms and the preserved `<all_urls>`
   content bridge while bundled executable scripts match only the two approved ChatGPT HTTPS
   hosts; package is explicit allow-list only.
2. browser-control mirrors list_tabs, claim_tab, cdp, cdp_auto_attach_frame, downloads,
   tab_action, create_tab, cleanup_tabs, detach, all actions and CDP events with
   title/URL/generation fail-closed.
3. Platform/account uses com.fabushi.chrome_platform; browser/CDP uses
   com.fabushi.browser_control; extension has no credentials.
4. Chats, Mini Apps, Marketplace, settings, the 0.4.1 script list/import controls and both
   bundled ChatGPT automation scripts remain available through one popup.
5. Actions passes Chrome/security/governance/Electron checks and canonical packaged journeys,
   retaining screenshots/video/trace/reports for the exact SHA.
6. Exact-main Release and Web Store update use a strictly newer version and include ZIP/SHA/
   content manifest; only then migrate profiles and remove old extensions via UI.

## Implementation summary

Added first-class extension shell, preserved the 0.4.1 userscript runner/content bridge and
bundled automation sources, renamed browser host, generation claim plumbing, Electron platform
server integration, runtime staging, Marketplace platform filtering, package/validator scripts,
focused workflow and contract tests. New installs stage beside the old Bridge source, rotate
legacy install keys, and require an explicit published ID before the desktop account bridge
will accept the platform socket. The packaged Chrome journey now captures labelled screenshots,
video, trace and report evidence on an always-uploaded CI path. Project scaffold, source/
decision/risk/dependency/evidence/runbook records are in this change stream.

## Evidence, blockers and next action

Only lightweight node --check/static inspection and the dependency-free Chrome validator are
run locally; application builds, package generation, Electron/mobile tests and E2E are deferred
to GitHub Actions. No PR, CI, Release, Web Store review, local migration or old-extension
uninstall is complete. Next action is finish static checks, push the governed PR and follow the
canonical post-main loop before marking this record passed.
