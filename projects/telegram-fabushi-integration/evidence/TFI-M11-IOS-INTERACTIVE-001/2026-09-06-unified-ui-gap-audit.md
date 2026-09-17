# TFI-M11-IOS-INTERACTIVE-001 — iOS single-latest-UI gap audit (2026-09-06)

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Existing task: `TFI-M11-IOS-INTERACTIVE-001`
- Audited canonical main: `6872793daf727c118510e818e3cd689c09101594`
- Status: `IN_PROGRESS`
- Purpose: preserve the live-code audit and the shortest package-reuse E2E path before product migration work starts.

## Canonical UI truth

Authenticated iOS currently enters `GrokMobileShell` and publishes the `grok-home` / Grok mobile semantic surface. That is the newest authenticated UI and is the canonical target surface for consolidation.

The same shell still retains a user-reachable `legacyOpen` branch that mounts the old monolithic `ContentView`. The old branch is reachable from multiple normal product paths, including:

- the account/avatar button (`grok-mobile-legacy`);
- the explicit semantic `grok-mobile-legacy` action;
- existing conversation rows;
- new-message, new-group, and new-channel flows.

Therefore the product currently has two reachable authenticated UI authorities. This is a real navigation fork, not only a visual mismatch.

Primary evidence:

- `mobile/ios/Fabushi/GrokMobileShell.swift`
- `mobile/ios/Fabushi/ContentView.swift`
- `mobile/ios/FabushiUITests/FabushiUITests.swift`
- PR #2363 (authenticated Grok semantic shell)
- PR #2365 (full native ContentView messaging journey)
- PR #2416 (UI test explicitly enters the legacy message workbench)

## Open-source-first result

Reference inspected: `TelegramMessenger/Telegram-iOS` at search-resolved commit `6ad963e5b62d354da79040f388ae2b9132fb17b8`, especially `submodules/TelegramUI/Sources/NavigateToChatController.swift` plus contact/peer entry points that converge on `navigateToChatController`.

Reusable pattern: keep one authenticated navigation authority and make contacts, search, peer/profile, replies, and compose routes converge on that authority instead of mounting a second full application shell.

Reuse decision: architecture/pattern only. No Telegram source code is copied. GitHub repository metadata did not expose a machine-readable license value in this audit (`license: null`), while its README explicitly requires license compliance; therefore direct code reuse is intentionally avoided.

## Capability gap matrix

| Scope | Existing iOS business capability | Latest `GrokMobileShell` surface | Gap / required convergence |
| --- | --- | --- | --- |
| Login / account | Pre-auth/onboarding and account session are implemented through existing iOS model / `ContentView`; app-owned device registration is proven in CI. | Authenticated Grok shell is the default after login, but avatar/account sends the user to legacy `ContentView`. | Add Grok-native profile/account destination; keep pre-auth flow as the single login route; remove authenticated legacy account entry only after parity. |
| Conversation list | `MessagingModel` exposes conversations, unread, pin/mute/archive state. | Latest shell renders conversations. | Keep list in Grok shell, but conversation selection currently flips `legacyOpen`; must route to one Grok-native message destination. |
| Messages | `ContentView` + `MessagingModel` cover draft/send, reply, forward, reaction, edit, pin, delete and sync. | Grok-native human conversation UI is absent; rows enter legacy workbench. | Migrate message timeline/composer/actions behind Grok navigation while reusing `MessagingModel`; then remove legacy chat route. |
| Search | Legacy/search business data exists; Grok semantic surface can set query. | Search icon is present, but the visual button action is currently empty; visible search field depends on query state. | Implement real visual search entry/focus and keep semantic + visual behavior identical. |
| Contacts / groups / channels | `MessagingModel` supports contacts, direct creation, group/channel creation and participants; legacy compose exposes them. | New message/group/channel actions route to `legacyOpen`. | Add Grok-native compose/participant flow and route all create actions to it. |
| Bot / Agent | Grok shell has native Bot list, `MobileBotChat`, Mahayana entry, send/stop lifecycle and semantic controls. | Native and reachable. | Preserve this as canonical; ensure no second authenticated Bot channel remains reachable through legacy shell after migration. |
| Settings / Profile | Legacy `ContentView` publishes profile/menu capability; unsupported calls/payments/settings are truthfully represented where applicable. | Avatar routes to legacy. | Add Grok-native profile/settings surface and preserve truthful unavailable states for capabilities not implemented on iOS. |
| Media / attachments | `ContentView` + `MessagingModel` cover blob/media, contact, location, poll and media-viewer paths; `MediaViewer.swift` exists. | No native Grok human-chat/media path. | Reuse existing media/message business APIs from the Grok chat destination; do not create a second media stack. |
| Notifications / sync | `MessagingModel.refresh()` executes canonical `sync` and maintains loading/error state. No `UNUserNotificationCenter` implementation was found by this audit. | Grok consumes conversation state but does not establish a separate push-notification implementation. | Preserve canonical sync; treat native push notification support as unproven/missing until a concrete implementation + evidence exists. |
| Mini Apps / WebMCP | `ContentView` opens `MiniAppWebMcpSurface`; iOS WebMCP surface and prior M8 evidence exist. | No verified Grok-native reachable Mini App entry was found in the audited shell. | Add one Grok-native Mini App/Marketplace route backed by the existing `MiniAppWebMcpSurface` and existing permission model; remove legacy-only reachability. |
| Permissions | Existing Mini App surface has host permission handling; location/media actions already exist in legacy business path. | No complete Grok human-chat permission journey. | Route permission prompts through existing native permission authorities; do not duplicate authorization state. |
| Error / offline recovery | `MessagingModel` exposes `errorMessage`, loading and sync failure handling. | Grok shell has partial Bot error presentation; full human-chat/offline recovery parity is not proven. | Surface canonical messaging errors/retry/offline state in Grok destinations and add deterministic E2E coverage. |

## Existing compatible package and E2E evidence

A compatible current-main Simulator package already exists and must be reused before requesting another build:

- source SHA: `6872793daf727c118510e818e3cd689c09101594`
- workflow run: `34030851007`
- job: `101479942005`
- package artifact: `9989009924` (`fabushi-ios-simulator-test-6872793daf727c118510e818e3cd689c09101594`)
- package SHA-256: `c423346e94a19406edff79e58a065de15155d562dffb01276777032261ec49e0`
- evidence artifact: `9989170643` (`fabushi-ios-interactive-evidence-34030851007-1`)
- evidence SHA-256: `955f6717391739d8bb5fcd64469ac661c1d94774cd5b7997a5ea1e2b933f34a2`
- App-owned device ID: `gha-34030851007-1-interactive` (expected offline after the workflow deletes its isolated Simulator)

The run proves recording -> package install -> protected test-account login -> App-owned registration -> bounded 600-second live hold -> always-upload evidence. It does **not** prove the complete simulated-user matrix: external semantic control did not complete the six registered tools before the hold expired, so the final gate correctly failed.

## Exact current blocker and narrow remediation

`.github/workflows/ios-interactive-app-e2e.yml` supports manual dispatch but has no package-origin inputs; every dispatch performs Rust/Xcode build/test before install. Because artifact `9989009924` already exists, rebuilding is unnecessary for the current inspection run.

The narrow CI remediation is to add an optional manual-dispatch package reuse mode that:

1. accepts an exact origin `run_id` + 40-character package source SHA;
2. downloads only `fabushi-ios-simulator-test-<source-sha>` from that exact run;
3. verifies the origin run `head_sha`, artifact checksum, archive naming, and app bundle ID;
4. skips Rust/Xcode build/test only in reuse mode;
5. starts recording before package extraction/install interaction, logs workflow SHA separately from package source SHA, then performs the same install -> login -> App-owned registration -> `@fabushi test` hold -> always-upload evidence path;
6. keeps the normal push/current-source build path unchanged.

This remediation is CI infrastructure only; it is not evidence that the UI gaps above are fixed. Final closure still requires atomic product PRs, protected-main readback, a new exact-product package, and a complete simulated-user video/evidence run on the unified Grok UI.