# TFI-M11 Android Global Dharma terminal evidence follow-up

- Date: 2026-09-07
- Base canonical main: `9f8ab6fd960c8563d2ee8c1c58b1d421f734c1b4`
- Parent delivery: PR #2478, merged as `9f8ab6fd960c8563d2ee8c1c58b1d421f734c1b4`
- Scope: E2E evidence quality only; no product behavior change.

## Reason

The packaged Android Global Dharma CI driver originally treated an idle disabled `mobile-bot-send` as sufficient evidence that a natural-language Bot command had completed. Because the draft is cleared immediately after send, that predicate could become true before the WebMCP operation reached a terminal state.

## Required terminal evidence

Before recording `bot-natural-language-verified`, the CI driver must now prove all of the following on the App-owned Android semantic surface:

1. Capture the pre-command count of Bot chat `log` elements.
2. Send the natural-language status request.
3. Observe `mobile-bot-stop` enabled, proving the Bot entered busy execution.
4. Observe a later terminal idle snapshot where `mobile-bot-stop` is absent and `mobile-bot-send` is present.
5. Require at least two new `log` elements relative to the pre-command snapshot.
6. Require `mobile-bot-error` to be absent.
7. Only then record `bot-natural-language-verified` and continue to `打开应用` / shared-runtime validation.

## Acceptance

- Narrow Android App-owned contract workflow passes the updated driver and contract test.
- Protected merge to canonical `main` completes before any new Android release is published.
- The exact-latest packaged Android E2E must still pass the full Global Dharma journey and produce screenshot/video/trace/log/report evidence before the Android platform can be reported as passed.
