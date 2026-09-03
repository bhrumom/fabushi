# M3-DESKTOP-001 — Desktop Messenger complete interaction

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M3-DESKTOP-001`
- **Stage**: `M3 桌面聊天完整交互`
- **WBS**: `M3.T01`–`M3.T09`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-22`
- **Depends on**: M2-SYNC-001 / PR #2002

## Objective

Close the real desktop-chat gaps on the canonical Electron Messenger V2 and prove the existing Telegram-parity interaction surface with Playwright, without introducing a second desktop messaging state machine.

## Live implementation audit

Already implemented in `desktop/src/messaging-shell-v2.tsx` / `desktop/e2e/messenger.spec.ts` and therefore primarily needs acceptance expansion rather than reimplementation:

- navigation rail + peer list + chat workspace + info panel;
- global peer/contact/Bot search;
- pinned/muted/archive conversation controls;
- new groups/channels and saved messages;
- reply/forward/edit/delete;
- reaction/pin message;
- attachments/polls/location/scheduled/silent send;
- self-hosted payments/Mini Apps/story entry points;
- real Bot collaboration group flow.

## Confirmed product gaps

1. **M3.T03 message-list virtualization/windowing**: current UI renders the entire `messages` array with `messages.map`.
2. **M3.T07 in-conversation search**: the current search bar is visual-only; it has no query state/filter/highlight behavior.
3. **M3.T08 draft persistence**: composer state is one global React string and is not persisted/restored per conversation.
4. **M3.T09 typing semantics**: Protocol v2 defines `StartTyping`, `StopTyping`, and `TypingChanged`, but desktop client/service do not currently complete the end-to-end path.
5. **M3.T02 high-count peer list**: current peer list maps all visible peers; use lightweight windowing so large contact/channel lists do not render unbounded rows.
6. Existing M3.T01/T04/T05/T06 flows need explicit Playwright assertions before promotion to `TESTED`/`E2E_VERIFIED`.

## Acceptance criteria

- Peer/message lists cap rendered rows while preserving access to recent/current items.
- Current-conversation search filters matching visible messages and can be cleared without mutating the underlying message state.
- Draft text is stored per peer key and restored when switching back or reopening the workspace; successful send clears that peer draft; failed send restores it.
- Self-hosted composer emits Protocol v2 start/stop typing signals with bounded expiry; recipient-visible typing state is represented by `TypingChanged` and never becomes permanent message history.
- Existing reply/forward/edit/delete/reaction/pin/search/navigation flows have deterministic Playwright coverage.
- Messaging Product Gate typecheck and Rust product tests pass; desktop E2E relevant to Messenger passes in GitHub Actions.
- Final branch is rebased/retargeted onto landed M2 and merged through protected main before M3 closes.

## Expected code scope

- `desktop/src/messaging-shell-v2.tsx`
- `desktop/src/selfhosted-messaging-client-v2.ts`
- `desktop/e2e/messenger.spec.ts`
- canonical Rust service/protocol code only where typing semantics require server support
- M3 WBS/evidence/status records

## Completion rule

Code existence is insufficient. M3 remains `IN_PROGRESS` until final-head CI, Messenger Playwright evidence, protected merge, and canonical-main readback exist.
