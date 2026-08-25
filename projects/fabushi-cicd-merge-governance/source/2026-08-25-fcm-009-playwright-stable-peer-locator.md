# 2026-08-25 · FCM-009 Playwright stable peer locator research

## Trigger

Canonical `main` Electron desktop quality gates for `52b7c10889e585660b7d2a22a40781c22f31b7a1` and `6ae21cba7878d113ac2902df94d867e7d3b7cd34` failed the same peer-switch regression journey after the peer list changed during the test.

The current test captured `peers.nth(0)` and `peers.nth(1)` as Playwright locators, then clicked them across React state updates. The Messenger peer list is sorted by pinned state and `updatedAtMs` and can change after opening/reading a conversation. A Playwright locator is live: it resolves the current DOM again for each action/assertion, so `nth(1)` can refer to a different peer after a re-render/reorder.

## Open-source / upstream review

Primary upstream: Microsoft Playwright documentation and implementation model (Apache-2.0 project).

Reviewed:

1. `https://playwright.dev/docs/locators`
   - Locators resolve an up-to-date DOM element for every action.
   - `first()` / `last()` / `nth()` are discouraged when the page can change because they may select an unintended element.
   - `getByTestId()` is the explicit stable testing-contract locator when a durable test id exists.
2. `https://playwright.dev/docs/best-practices`
   - Prefer resilient locators and explicit contracts over DOM-position coupling.
   - Keep assertions retryable so UI state transitions are awaited instead of sampled once.

## Decision

Do not change product ordering or weaken the identity assertion. The product already exposes stable `data-testid="peer-${peer.key}"` and each BotMark exposes a semantic `data-bot-id`.

Adapt the upstream-recommended pattern:

- snapshot the first two peers' `data-testid` values before any click;
- re-create locators with `page.getByTestId(stableId)` so later list reordering cannot retarget them;
- snapshot each peer's `data-bot-id` before state changes;
- use Playwright retryable `toHaveAttribute` for header identity after switching.

This is a test-stability repair, not a product-behavior waiver. The test must still prove both peer avatars remain visible, the header identity follows the selected peer, and the narrow info panel opens.

## License / provenance

No Playwright source code is copied. The repair follows documented locator semantics and public best practices from the Apache-2.0 Playwright project; no new dependency or license obligation is introduced.
