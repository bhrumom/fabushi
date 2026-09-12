# CWA-007 — Official same-account Chrome login and control

- Portfolio Project: FAB-P0011; Project Key: CWA; Task ID: CWA-007.
- Status: in-progress. Started/updated: 2026-09-12. Completed: null.
- Source: source/2026-09-12-official-account-browser-direct.md; CWA-R009..R012, R002..R007.
- Objective: independent Fabushi login in Chrome and official same-account MCP browser discovery/control with complete Bridge compatibility.
- Branch: codex/cwa-007-account-browser-direct-20260912. Commit/PR: pending.
- Dependencies: existing Fabushi account browser-login API, remote MCP device gateway, stable extension identity, CI/protected main and release deployment.
- In scope: login/logout, authenticated browser registration, account isolation, command/event parity, UI and CI evidence.
- Out of scope: unrelated extension deletion, replacing account identity service, exposing desktop control to a browser-only agent.

## Acceptance and verification

CI must exercise packaged extension login, same-account discovery/control, cross-account denial, logout removal, reconnect/restart and the complete command/event parity suite. Retain checkpoint screenshots, full video, traces/reports/logs on success and failure for the exact canonical SHA (90-day target). Verify protected merge, main readback, packaged required E2E, release assets/version and gateway deployment. No local app build/test.

## Open-source survey

Candidates located: microsoft/playwright (packages/extension and MCP), GoogleChrome/chrome-extensions-samples and Chrome identity documentation. Detailed architecture/license/test review pending before custom implementation. Existing Fabushi native browser-control and account-scoped gateway should be reused; do not duplicate the browser engine or account service.

## Findings and implementation status

Canonical main contains fused browser-control.js and optional desktop product bridge. Chrome has no independent account login or browser-only agent. Existing /agent upgrades require Authorization headers, which native browser WebSocket cannot set. Authentication transport must be designed without putting reusable credentials in URLs or exposing them to page scripts. Existing account API offers browser/start and secret-bound attempt polling.

Implemented the 0.6.0 candidate: popup account controls, resumable browser login,
memory-backed short session, published-origin/first-frame gateway authentication,
account-scoped browser registration, direct routing through the existing nine-command
dispatcher, bounded `browser_events`, reconnect, and logout/expiry claim revocation.
Added gateway/account isolation tests, package/validator/version updates, CI path coverage,
server environment documentation and release rollback rules.

PR #2535 is merged (a9d0b883c68dd45c14f9966ab79656bcf43c4d0e), despite the older CWA-006 record.
The later canonical fix #2562 (`75d9105549a8cd99fb5b691bb36b5817d04e5579`)
has a green Chrome workflow `34698045445`; it is the CWA-007 base. CWA-007 has no PR,
CI run, post-main E2E, Release or deployment evidence yet. Only lightweight syntax and diff
inspection were performed locally; no local app build/test was run.

## Risks/blockers/next action

Stable Web Store extension ID and production gateway deployment remain external release
dependencies. Next: commit/push, open PR, run CI review, merge through protected main, deploy
the gateway and execute exact-SHA packaged same-account E2E/Release. All delivery gates remain pending.
