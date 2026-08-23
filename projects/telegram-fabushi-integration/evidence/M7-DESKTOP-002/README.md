# M7-DESKTOP-002 evidence

- **Project**: `FAB-P0001 / TFI`
- **Task**: `M7-DESKTOP-002`
- **PR**: `#2053`
- **Status**: `TESTING`
- **Date**: `2026-08-23`

## User evidence

The task was opened from a real Fabushi macOS screenshot showing:

- Bot Father selected in the unified Messenger;
- orange error banner: `agent backend is unavailable: plugin not found: bot-father`;
- no visible bottom message composer/input for the selected messaging peer.

Source intake: `../../source/2026-08-23-messenger-composer-miniapp-regression.md`.

## Code evidence

- `frontend/apps/web/src/lib/mahayana-host/electron-transport.ts`
  - removes `kind=miniapp` summaries from ordinary conversation list delivery;
  - stores canonical Mini App routing data;
  - reroutes historical/direct `conversation.open` attempts to `miniapp.open`.
- `desktop/src/messenger-layout-regressions.css`
  - removes flex min-content displacement of the composer;
  - keeps the composer non-shrinking inside the clipped chat workspace.
- `desktop/e2e/messenger-regressions.spec.ts`
  - verifies Mini App transport normalization and direct-open fallback;
  - verifies each exercised chat peer's `messenger-input` bounding box is inside the Electron viewport.

## GitHub evidence

Initial implementation head: `46be6d7268962fe0f682d93efb69f3d29ade8b2a`.

- Project portfolio governance run `32627390573`: SUCCESS.
- Host fast E2E run `32627390610`: SUCCESS.
- Messaging Product Gate run `32627390565`: was running when the evidence ledger was opened.
- Electron desktop quality gate run `32627390618`: was running when the evidence ledger was opened.
- CI run `32627390630`: was running when the evidence ledger was opened.

The project-record synchronization commits after the initial implementation trigger a fresh latest-head CI set. Only that latest-head set plus protected merge and canonical-main readback can promote this task to `TESTED`.

## Closure checklist

- [x] User symptom recorded.
- [x] Root-cause implementation added.
- [x] Regression tests added.
- [x] PR #2053 opened.
- [x] Protected auto-merge enabled.
- [ ] Latest-head required checks all SUCCESS.
- [ ] Protected merge completed.
- [ ] Canonical `main` readback completed.
- [ ] Task/WBS/acceptance/status/evidence promoted to final `TESTED` state.
