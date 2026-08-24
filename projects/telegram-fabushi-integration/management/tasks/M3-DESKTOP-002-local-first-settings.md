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
- **Performance/Release source**: `source/2026-08-24-startup-performance-release-gate.md`
- **Implementation commit**: `cda0bbc37c7f8b2623384fc5a9c1542aef5fcffa`
- **PR**: `#2079`
- **Merge commit**: `01b33d60f7d7d9add41a5fba84d21014094cb5dc`

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
9. Returning-user cached conversation list first-interactive time is objectively measured in packaged E2E and is `< 1000 ms`.
10. The exact accepted main SHA completes the post-main packaged E2E → Release → updater proof before final `COMPLETED`.

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
- GitHub Actions: PASS — CI `32673731408`, Messaging Product Gate `32673731405`, self-hosted messaging `32673731410`, Electron desktop quality gate `32673731418`.
- Electron renderer `tsc --noEmit && vite build`: PASS in the quality gate.
- Messenger Playwright: PASS, including the new Telegram Settings + fast-start projection reload test.
- macOS packaged E2E had one unrelated Mini App flake on the first attempt; the job rerun passed fully.
- Protected merge queue: PASS — PR #2079 merged as `01b33d60f7d7d9add41a5fba84d21014094cb5dc`.
- Canonical-main verification: PASS — `main` re-read at `01b33d60f7d7d9add41a5fba84d21014094cb5dc`.
- Evidence index: `evidence/M3-DESKTOP-002/README.md`.

## Current delivery gate

- Core implementation PR #2079 is merged and canonical-main readback passed.
- A new packaged returning-user startup performance E2E now enforces the project `< 1 second` first-interactive target.
- Final task closure remains pending until this measurement is green on canonical main and the same accepted SHA is published through the post-main Release/updater loop.

## 2026-08-24 durability/performance continuation

Canonical `main@ace59b487bb8b1838508d08acbea5f4e7e4fa775` ran the new startup-performance E2E. The projection contained `首屏性能验收` before shutdown, but the row was missing after a full Electron relaunch; therefore the run produced no acceptable first-interactive measurement and Release stayed blocked.

The follow-up fix on branch `fix/tfi-m3-durable-fast-start` mirrors the bounded renderer projection into the existing Electron native client-persistence store while preserving Rust SQLite/Host as authoritative. Startup prefers synchronous `localStorage`, falls back to the native mirror before routing to HostClient, and mirrors recovered data back into local storage. The E2E now verifies the durable mirror before closing the first process.

Status remains `TESTING` until the protected-main packaged E2E records `< 1000 ms`, all required exact-main desktop/mobile gates pass, and the tested artifacts are published as a new Release.
