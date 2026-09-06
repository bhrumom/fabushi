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

## PR validation round 2 — stable targets beyond snapshot cap

Release candidate PR #2417 (`f3b6985fc1234e6b7827d70846ff5c18e892f986`) was closed unmerged after Electron quality run `34022105890` failed the semantic message-action regression on both the initial attempt and retry. The version-only diff compiled and 26/27 E2E tests passed; the same App Agent Surface case failed while enumerating stable menu action IDs.

Root cause is in the semantic surface contract rather than release versioning: `snapshot` intentionally caps output at `MAX_ELEMENTS=500`, but `find(agentId=...)` and `action(agentId=...)` also resolved targets by first rebuilding that same capped snapshot/ref map. Consequently an explicit unique stable `agentId` at semantic element 501+ could exist in the DOM yet be reported as not found. The failure is data-size dependent, explaining one earlier green run and the deterministic later failures.

The stabilization keeps the public snapshot payload cap unchanged. Exact stable `agentId` lookups now scan only stable-ID-bearing DOM nodes, require exactly one matching target, build the same redacted element state, and bypass only the 500-item response truncation. Volatile refs remain snapshot-generation bound and capped. The regression deliberately prepends 520 hidden unique semantic decoys, asserts the normal snapshot is truncated and excludes the target, then requires exact `action(agentId=...)` to open the message menu and exact `find(agentId=...)` to resolve every required menu action before invoking Reply.

## PR validation round 3 — authored-message role determinism

PR #2419 Electron run `34022422773` proved the >500 exact stable `action(agentId)` path: the test passed the truncated-snapshot exclusion and successfully opened the message context menu. It then failed with `found.count=0` for one of the required menu actions on both attempts. Source uniqueness audit shows every asserted menu ID is declared exactly once; only `edit` is conditional and exists only for `menu.message.role === 'me'`.

The test target was still selected as the last rendered message containing the probe text. An asynchronous Agent reply can echo the probe and become that last match, recreating the earlier peer-message ambiguity. The product message node now exposes its already-known role as `data-agent-message-role`; the regression selects the exact probe only among `role=me` messages, asserts that role before opening the menu, and keeps all seven strict semantic `find` requirements. Each loop assertion also names the action and independently requires its DOM button to be visible, so any remaining failure distinguishes renderer absence from semantic lookup failure without weakening acceptance.

## PR validation round 4 — mutation generation freshness

PR #2419 Electron run `34022697469` passed every strict DOM and semantic lookup for `reply/copy/react/edit/pin/forward/delete`, proving both the authored-message target and exact stable IDs beyond the 500-element snapshot cap are correct. The only failure moved to the final Reply mutation: the test saved Reply's generation from the first lookup, then performed six more read-only menu lookups while asynchronous Agent updates advanced the live App generation by two. The final action was correctly rejected as `stale_app_surface_generation` (`expected 78, received 76`; retry `expected 83, received 81`).

The product stale-generation gate remains unchanged. The regression now performs a fresh exact `find(reply)` immediately before the Reply mutation and uses that returned generation, matching the required live-controller discipline of read-latest-generation then mutate.
