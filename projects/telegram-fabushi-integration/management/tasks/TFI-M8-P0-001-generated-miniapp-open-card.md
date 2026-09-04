# TFI-M8-P0-001 — generated MiniApp message card

- Project ID: `FAB-P0001`
- Task ID: `TFI-M8-P0-001`
- Status: `NOT_STARTED`
- Owner: Execution project group
- Dependencies: none
- Parallel: yes.

## Objective

When Bot/Mahayana generation finishes, render a typed, directly actionable MiniApp card in chat instead of only source/code text.

## Existing producers/consumers to verify before editing

`ai-backend/src/miniapp_marketplace.js` (`mahayana.miniapp.generation.v1`), marketplace catalog/release manifest, Host transport contracts, `desktop/src/messaging-shell-v2.tsx`, existing `marketplace.install` / `miniapp.open` flows. Do not invent fields before reading their actual current definitions.

## Contract

- Define/version one serializable message-card payload carrying stable MiniApp identity and references to canonical marketplace/release metadata, plus optional Bot preview; avoid duplicating package bytes or trusting arbitrary URLs.
- Installed card action: Open existing MiniApp.
- Not installed: Install through existing validated `InstallMiniApp` path, then Open when successful; failure remains visible/retryable.
- yanked/rejected/invalid/digest-mismatch items cannot be opened through the card.
- renderer treats card data as data, never executable HTML/JS.

## Acceptance

Producer/consumer contract tests, renderer card tests, invalid-state negatives and packaged simulated-user generation-result -> card -> open/install journey with video/screenshot/trace/report/log evidence. Update task/project docs with actual field mapping used.