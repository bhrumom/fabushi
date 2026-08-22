# M3-DESKTOP-001 evidence index

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Stage**: `M3`
- **Status**: `IMPLEMENTED / CURRENT-HEAD CI PENDING`

## Desktop implementation

- `desktop/src/messaging-shell-v2.tsx`
  - bounded peer render window: 120 rows per batch;
  - bounded message render window: latest 240 per batch with explicit older-message expansion;
  - controlled in-conversation search with real message filtering and no-match state;
  - per-peer draft persistence through `fabushi.desktop.messenger-drafts.v2`;
  - cursor-aware incremental sync poll;
  - recipient-visible typing status with expiry cleanup.
- `desktop/src/selfhosted-messaging-client-v2.ts`
  - cursor-aware `sync`;
  - Protocol v2 `startTyping` / `stopTyping` commands.

## Rust typing semantics

- `native/mahayana-messaging/src/service.rs`
  - `StartTyping` and `StopTyping` become audience-scoped `TypingChanged` events;
  - 5-second TTL on active typing;
  - conversation-membership authorization;
  - expired active typing events filtered from delta replay.
- `native/mahayana-messaging/tests/typing_contract.rs`
  - recipient receives active typing;
  - outsider cannot observe typing delta;
  - expired typing is not replayed;
  - non-member cannot publish typing state.

## Playwright evidence added

`desktop/e2e/messenger.spec.ts` adds a real renderer lifecycle flow:

1. open known Messenger peer;
2. write draft;
3. reload renderer using the same app data;
4. reopen same peer and verify draft restored;
5. send unique marker message;
6. in-conversation search finds exactly that message;
7. impossible query shows no-match state.

Existing Messenger Playwright coverage continues to verify navigation, self-hosted channel creation, reaction/edit/pin/delete/invoice, group Bot collaboration and Mini App opening.

## Completion gate

Do not promote M3 to TESTED/E2E_VERIFIED until current-head Rust tests/Clippy, Electron Messenger typecheck, Messenger Playwright, protected merge and canonical-main verification pass. M3.T07 unread also requires an explicit desktop E2E assertion before stage closure.
