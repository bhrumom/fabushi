# TFI-MACOS-SEMANTIC-MESSAGE-ACTIONS-001

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Trigger: macOS interactive run `34019929170`, release `v1.2.38`, App-owned device `gha-34019929170-1-macos-app`
- Evidence artifact: `9985464811`

## Problem

The installed macOS App stayed online and renewed its bounded account session, and packaged App Agent Surface Playwright passed, but the required external journey could not honestly execute `reply/edit/delete/forward`: normal message actions are reachable only through React `onContextMenu`, while the semantic App MCP exposes `invoke/focus/setValue/pressKey/scroll/selectOption/toggle` and rendered messages/menu actions have no stable semantic IDs.

## Scope

Single issue only: expose the existing message context menu and its existing actions through the current semantic `invoke` contract without changing messaging business behavior or broadening the MCP action allowlist.

Acceptance:
1. A normal rendered message has a stable semantic ID and an explicit marker authorizing `invoke` to dispatch its existing context-menu event.
2. Existing message-menu actions have stable semantic IDs.
3. Packaged App Agent Surface Playwright proves the semantic bridge can open the menu and resolve/invoke a stable menu action while stale-generation fail-closed behavior remains intact.
4. PR merges through protected main; a strictly newer macOS test release is built/published in GitHub Actions; a new App-owned macOS device completes the full journey with READY note, finish, exact `settings-logout`, video/screenshots/trace/Playwright/log/report always-upload evidence.

## Open-source-first gate

No new protocol/framework is introduced. The implementation follows the existing DOM/React event model already used by the product and the repository's established App-Agent Surface. A separate dependency would increase surface area for a single explicit semantic event. We retain browser-native `MouseEvent('contextmenu')` dispatch behind an opt-in element attribute and the existing allowlisted `invoke` action.

## Failure evidence

Run `34019929170` intentionally ended with `TFI_MACOS_FULL_JOURNEY FAIL ...` plus `ci_session_finish`; Playwright was `1/1` success and the always-upload artifact contains 119 files / whole-session video / device trace / screenshots / reports. No logout was performed because the READY gate was not satisfied.

### Upstream references checked

- MDN `Element: contextmenu event`: confirms the semantic event fired for user context-menu intent and its bubbling/cancelable event model.
- Playwright `dispatchEvent`: confirms browser event dispatch uses native event initialization and bubbling/cancelable semantics; this is used only as design/test precedent, not as a runtime dependency.
- Decision: adapt the platform-native event model behind Fabushi's existing opt-in semantic marker; no third-party dependency and no new MCP action enum.

## PR validation round 1

- PR #2413 head `4f8c9361ba272f9e826da8a07d08aac816c5aaed` passed CI and project governance.
- Electron quality run `34021419099` reached the real Linux Rust Host journey: 26/27 E2E passed; the new App Agent test opened the semantic message context menu, but selected an asynchronous Agent reply and then incorrectly required the self-only `edit` action.
- This is a test-targeting defect, not a product relaxation. The follow-up selects the exact sent probe message by text, reads its stable `data-agent-id`, and keeps the strict `edit` assertion.
