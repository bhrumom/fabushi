# M7-DESKTOP-004 — messaging account identity normalization

- Status: TESTING
- Parent milestone: M7 — Bot/Agent unified contact system
- Trigger: final signed/notarized macOS local-app smoke after M7-DESKTOP-003

## Problem

The installed canonical-main macOS build restored an authenticated account but failed to issue the local self-hosted messaging credential with `authenticated account has no stable user id`.

The production account service emits numeric JSON `id` / `userId` values, while the Host assumed the first present identity field was a string. This rejected a valid authenticated account before the unified Messenger could finish establishing its messaging access boundary.

## Implementation

1. Normalize stable identity values from JSON strings or numbers.
2. Prefer principal identifiers when present, then current/legacy user identifiers.
3. Search both `auth.user` and the UI-safe session root for compatibility with restored historical sessions.
4. Preserve the existing one-way SHA-256 account fingerprint before constructing the local `ActorId`.
5. Add regression tests for numeric IDs, top-level legacy IDs, trimmed usernames and missing stable identity.

## Acceptance

- [ ] Feature Host tests pass on current head.
- [ ] Existing authenticated desktop session can issue messaging access without re-login.
- [ ] No account credential or raw messaging bearer token crosses the presentation boundary.
- [ ] Missing stable account identity still fails closed.
- [ ] Protected merge reaches canonical `main`.
- [ ] Canonical-main Electron package matrix is green on macOS, Windows and Linux.
- [ ] macOS package passes Developer ID signing, stable nested Host/ASR identifiers, App Store Connect notarization, stapling and Gatekeeper verification.
- [ ] The exact canonical-main artifact is installed over `/Applications/fabushi.app` and opened on the target Mac.
- [ ] Final visual/runtime smoke has no `authenticated account has no stable user id` banner.

## Evidence

See `evidence/M7-DESKTOP-004/README.md`.
