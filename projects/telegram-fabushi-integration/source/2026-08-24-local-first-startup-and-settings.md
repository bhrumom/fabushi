# 2026-08-24 — Telegram local-first startup + settings absorption

## User requirement

Continue the Telegram → Fabushi integration by implementing the startup/data-flow behavior observed in Telegram Desktop/Unigram and by absorbing Telegram's settings surface into Fabushi's canonical Electron Messenger.

## Source-derived implementation principles

### Local-first startup

Reference behavior audited from `telegramdesktop/tdesktop` and `UnigramDev/Unigram`:

- restore account/session/local state before waiting for network synchronization;
- render the chat shell from local data immediately;
- first chat-list load is bounded (Telegram Desktop uses 20 dialogs for the first load; Unigram loads chat-list slices incrementally);
- later network work is incremental/delta synchronization and must not block first interaction;
- a hidden/absent third panel must consume zero layout width.

Fabushi adaptation:

- keep the canonical Rust `native/mahayana-messaging` state machine authoritative;
- use its already-versioned SQLite durable store as the canonical local messaging persistence;
- renderer projection caches are permitted only as a non-authoritative fast-start projection and must reconcile against Rust/Host state;
- remove the HostClient-before-Messenger remount from the normal returning-user path;
- reduce initial self-hosted sync from an unbounded 1000-event first pass to a small first slice, then continue delta sync in the background;
- preserve explicit login/authentication when no valid returning-user projection/session exists.

### Settings surface

Reference surface audited from Telegram Desktop `Telegram/SourceFiles/settings/` and `settings/sections/` including active sessions, advanced, blocked peers, business, calls, chat, notification/privacy/data-related sections.

Fabushi should absorb the information architecture and interaction quality, not copy Telegram branding or create a second settings state machine. Initial desktop settings categories:

1. Profile / account
2. Notifications & sounds
3. Privacy & security
4. Data & storage
5. Chat settings / appearance
6. Folders
7. Devices / active sessions
8. Calls
9. Language
10. Advanced
11. Fabushi-native AI/Bot/Mini App controls where applicable

Settings that already have a real Fabushi backend must bind to it. Settings whose backend is not yet implemented must be clearly identified as planned/disabled rather than pretending to work.

## Acceptance direction

- Returning-user first paint shows Messenger immediately from local projection instead of `HostClient` followed by remount.
- Initial self-hosted synchronization requests a small bounded slice and subsequent sync uses the cursor incrementally.
- Settings opens as a native Messenger section with Telegram-inspired grouped navigation and real toggles for currently supported desktop preferences.
- Existing messaging, update, search, drafts, pin/mute/archive, and authentication flows remain compatible.
- Verification is performed in GitHub Actions; local build/test is prohibited by repository instructions.
