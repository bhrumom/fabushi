# AAC-003 final desktop release gate analysis — 2026-08-26

## Scope

This note records the two cross-platform blockers that remained after PRs #2147, #2150 and #2151. The task remains `in-progress` until an exact-main Electron run publishes a newer GitHub Release and the installed desktop product is verified.

## Blocker 1 — BotMark semantic contract drift

The Grok-style renderer migration changed the outer `BotMark` wrapper from the stable product semantic marker `data-engine="fabushi-motion-v2"` to `data-engine="grok-mark"`. The visual renderer itself was present, but all packaged Electron user journeys intentionally select the stable product marker. This made profile and peer avatars appear absent to Linux, macOS and Windows E2E even though the SVG renderer was mounted.

Resolution: keep the durable semantic identity on the wrapper (`data-engine="fabushi-motion-v2"`) and identify the implementation independently (`data-renderer="grok-mark"`). The Grok geometry/motion engine remains unchanged. The motion contract gate now requires both markers so future renderer work cannot replace the product semantic contract.

## Blocker 2 — desktop auth gate was not re-armed after logout

`DesktopShellV2` performs an initial auth probe and intentionally stops polling while a valid session is active. `resetToLogin()` correctly logs out, clears account-scoped projection/draft/journal state and shows `HostClient`. `HostClient` delegates to the real Electron Mahayana Host and successfully completes browser login, but the top-level shell no longer had an observer that could notice the new authenticated Host state. Therefore the login gate stayed mounted and `messenger-workspace` never returned.

Resolution: install a desktop account-session synchronizer at the renderer root. It is dormant during normal authenticated use. `clearAccountScopedDesktopCaches()` already emits `MAHAYANA_ACCOUNT_SESSION_RESET_EVENT`; only after that event the synchronizer polls `feature.auth.status`. When the Rust Host reports a new authenticated session it reloads the renderer once, rebuilding every account-scoped transport/cache from the new identity. No always-on auth polling is introduced.

## Acceptance

The existing release E2E is authoritative and is not weakened. It must prove:

- profile and peer BotMarks expose the stable `fabushi-motion-v2` semantic marker while using the Grok renderer;
- a real Messenger message creates a non-empty account journal;
- logout clears projection, drafts and conversation journal;
- the login gate appears;
- a second browser login restores `messenger-workspace`;
- Linux pre-package and packaged macOS/Windows user journeys all pass;
- a newer exact-main GitHub Release is published and detected by an installed older client.
