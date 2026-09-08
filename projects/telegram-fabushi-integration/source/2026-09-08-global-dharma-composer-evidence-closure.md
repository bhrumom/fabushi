# 2026-09-08 — Global Dharma composer/evidence closure source

Project: `FAB-P0001 / TFI`
Parent acceptance: `M9-GLOBAL-DHARMA-003`
Baseline canonical main: `f443d54d43ecda808c9d52c66bc6ae8dcfe68549`
Source request marker: `Fabushi:4679b65f-b2c2-4b3a-bf99-98ff90864cd4`

## User requirement preserved for this round

Close only the remaining gaps in the original desktop Global Dharma Mini App journey:

1. The `全球法布施` Bot must expose `打开应用` at the message composer, immediately beside the message input. Acceptance must prove DOM ownership and geometry, not only existence/visibility, and retain a clear screenshot.
2. Freeze the payment acceptance boundary. The original target asks for the Fabushi payment system, CNY 1080 lifetime purchase of `local.prayer-wheel.start`, and a downloadable video that simulates the actual user situation. It does not require a live-money production charge. Therefore the packaged acceptance in this round MAY use the existing deterministic `FABUSHI_FEATURE_HOST_MODE=test` provider only when the journey still crosses the canonical Fabushi Pay/product/order/entitlement authority and proves the complete chain `PaymentIntent -> checkout/callback -> entitlement -> restore -> local.prayer-wheel.start`. No client-only unlock, fabricated entitlement, or claim of production PSP/KYC readiness is allowed.
3. After the product change reaches protected canonical `main`, rerun packaged E2E against that exact source revision and freshly capture the continuous journey: exact Mini App search/install -> projected Bot -> composer-adjacent `打开应用` -> natural-language WebMCP -> opened Web UI/shared revision -> bounded Fabushi account projection -> CNY 1080 lifetime entitlement + restore -> `local.prayer-wheel.start`. Retain downloadable video, diagnostics, screenshots, trace/report/logs, links and SHA-256 digests, then perform an independent video review.

## Explicit payment acceptance decision

For this round, `模拟实际情况` means a non-charging packaged test-provider transaction is acceptable **only** because it exercises the production-shaped canonical Fabushi Pay state machine and server-authoritative entitlement semantics. Required evidence must identify the provider as test/non-charging and must not imply that production PSP onboarding, KYC, merchant activation or a real-money settlement was verified.

A future request that explicitly requires production payment readiness or a named real PSP must instead provide and verify the corresponding PSP sandbox/KYC/provider integration. That is a separate production-readiness gate and is not silently imported into this original desktop acceptance round.

## Composer placement acceptance

The packaged E2E must fail closed unless all of the following are true while the Global Dharma Bot conversation is open:

- exactly one `data-testid="miniapp-bot-open"` control is visible;
- the control is a descendant of the same message composer form as `data-testid="messenger-input"`;
- the control and input occupy the same horizontal composer row with meaningful vertical overlap;
- the control is horizontally adjacent to the input with a bounded gap (maximum 24 px), rather than appearing in the header or elsewhere on screen;
- a dedicated screenshot clearly shows the Bot identity, composer input and `打开应用` control together.

## Scope boundary

- Desktop/Electron packaged acceptance is the scope required by the original target in this round.
- Android/iOS are not additional prerequisites unless the user separately asks for them.
- No local heavy build/test is acceptance evidence. Heavy validation and packaged evidence must run in GitHub Actions.
- Existing Marketplace, WebMCP, account, payment and prayer-wheel implementations are reused; this round must not create a second authority or mock client-only feature path.
