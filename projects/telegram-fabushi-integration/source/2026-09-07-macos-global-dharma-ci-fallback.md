# 2026-09-07 macOS Global Dharma CI fallback requirement

## User goal

On macOS, validate the same end-user Global Dharma Mini App goal without treating live `fabushi test` control or plugin connectivity as a hard prerequisite:

1. Search the app/Mini App surface for `小程序` / `全球法布施` and install `全球法布施`.
2. Confirm `全球法布施` Bot appears in Messenger.
3. `打开应用` opens the Telegram-style Web UI.
4. Natural-language Bot input routes through WebMCP and the Bot/Web UI converge on the same execution revision/state.
5. A logged-in Fabushi account is projected into the Mini App without exposing bearer/refresh credentials.
6. Test-mode CNY 1080 durable purchase and restore grant the local prayer-wheel entitlement; server-side entitlement contract is independently required for the same exact source SHA.
7. The entitled Bot can start the local prayer wheel; restart recovery and logout cleanup are verified.
8. Evidence must contain named step screenshots, full/segmented video, Playwright trace, logs/report, exact source SHA, PR/merge, Actions runs, Release, and downloadable artifacts.

## Engineering constraints

- Canonical `main` + TFI records are authoritative.
- Heavy build/test remains GitHub Actions only.
- Prefer the narrowest Actions path and reuse npm/native/package artifacts rather than rebuilding.
- A failed E2E remains a failure; repair via a new minimal PR, protected merge, strictly newer test Release, and retest from the newest Release.
- Device/plugin evidence is supplemental. Plugin failure or absence cannot block the repeatable CI simulated-user journey.
- No real-money charge is performed. The CNY 1080 flow uses the repository's test payment rail while the service entitlement contract is verified separately for the exact source SHA.
- Never claim a feature passed unless the required evidence exists.
