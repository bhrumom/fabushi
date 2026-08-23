# M3-DESKTOP-002 — Telegram local-first startup and settings absorption

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M3-DESKTOP-002`
- **Stage**: `M3 桌面聊天完整交互`
- **Status**: `TESTING`
- **Started**: `2026-08-24`
- **Updated**: `2026-08-24`
- **Branch**: `feat/telegram-local-first-settings`
- **Source**: `source/2026-08-24-local-first-startup-and-settings.md`
- **Implementation commit**: `cda0bbc37c7f8b2623384fc5a9c1542aef5fcffa`
- **PR**: `#2079`

## Objective

Adopt Telegram Desktop/Unigram's local-first, bounded-initial-load behavior in the canonical Electron Messenger and absorb Telegram's settings information architecture into Fabushi without creating a second messaging/settings state machine.

## In scope

- returning-user Messenger first paint without a HostClient → Messenger remount;
- bounded initial self-hosted sync and cursor-based background deltas;
- fast renderer projection restore reconciled against canonical Rust/Host state;
- remember last active conversation and recent renderer projection for instant paint;
- make absent third/info panel consume zero width at runtime;
- Telegram-inspired grouped settings navigation inside Messenger;
- bind supported settings to real local/runtime preferences and clearly label unavailable backend capabilities;
- E2E/contract assertions for local-first shell and settings entry.

## Out of scope

- replacing the canonical Rust SQLite state store;
- copying Telegram branding/assets verbatim;
- pretending unsupported privacy/device/backend settings are already functional;
- local application build/test (forbidden by repository policy).

## Dependencies

- M1 SQLite durable local-first storage landed in canonical messaging core.
- M3-DESKTOP-001 desktop Messenger interaction work merged via PR #2021.
- Electron Host authentication and native runtime bridge remain authoritative for live session validation.

## Acceptance criteria

1. Returning-user renderer can paint Messenger from a persisted projection before Host network/auth round trips finish.
2. First self-hosted sync is a small bounded request; later synchronization uses cursor deltas.
3. Persisted projection is non-authoritative and is replaced/reconciled by canonical Host/Rust events after initialization.
4. Last selected peer restores when still present.
5. Settings includes grouped sections for account, notifications, privacy/security, data/storage, chat appearance, folders, devices, calls, language, advanced, and Fabushi-native AI/Mini App controls.
6. Supported toggles persist and affect their real UI behavior; unsupported server capabilities are shown disabled/planned.
7. GitHub Actions typecheck/product gate and relevant Messenger Playwright coverage pass before completion.
8. PR merges to protected `main` and canonical-main state is re-read before task is marked complete.

## Verification plan

- Electron TypeScript typecheck in GitHub Actions.
- Messaging Product Gate in GitHub Actions.
- Messenger Playwright assertions for instant shell projection/settings navigation.
- PR/CI/merge evidence recorded under `evidence/M3-DESKTOP-002/`.

## Risks

- stale renderer projection could diverge from Rust state; mitigation: projection is display-only and canonical events overwrite it.
- auth-invalid returning users must still land in login/HostClient path after validation.
- settings breadth can imply functionality not present; mitigation: explicit availability metadata and disabled rows.

## Implementation summary

- Added bounded renderer fast-start projection (`fabushi.desktop.messenger-projection.v1`) for returning-user first paint while Rust SQLite/Host remains authoritative.
- Changed first self-hosted sync to 20 records and cursor-based background batches to 100; delta sync batches merge instead of replacing projected state.
- Restores last active self-hosted conversation and bounded recent messages.
- Fixed the <=1280 responsive third-column mismatch by allocating the 286px column only when the info panel is actually visible.
- Added Telegram-inspired Settings navigation and detail workspace for account, notifications, privacy/security, data/storage, chat, folders, devices, calls, language, advanced, and Fabushi AI/Mini Apps.
- Wired real desktop preferences for message preview, video autoplay, info-panel visibility, Enter-to-send and reduced motion; unsupported server-backed options are explicitly marked planned.
- Added Playwright coverage for settings/preferences and reload-from-projection.

## Verification / evidence

- `git diff --check`: PASS before push.
- Local application build/test: intentionally NOT RUN per repository disk-safety policy.
- GitHub Actions: pending on PR #2079.
- Protected merge + canonical-main verification: pending.
- Evidence index: `evidence/M3-DESKTOP-002/README.md`.

## Blockers

- Required GitHub Actions / protected-main gates have not completed yet; task remains `TESTING`.

## Next action

Drive PR #2079 through current-head CI, fix any failures, merge through protected `main`, then re-read canonical main and update acceptance/project records before closure.
