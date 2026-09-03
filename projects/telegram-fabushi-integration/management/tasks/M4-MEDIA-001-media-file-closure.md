# M4-MEDIA-001 — Media and file closure

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M4-MEDIA-001`
- **Stage**: `M4 媒体与文件`
- **WBS**: `M4.T01`–`M4.T08`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-23`
- **Depends on**: M3 / PR #2022
- **Implementation PR**: #2037

## Objective

Close the M4 acceptance boundary on the existing Fabushi-owned Rust media stack without introducing Telegram API dependencies or a second messaging state machine.

## Existing implementation reused

- `native/mahayana-messaging/src/blob_store.rs`: resumable `.part` upload, exact offset validation, atomic finalization, bounded Range reads, delete, traversal-safe `BlobId`.
- `native/mahayana-messaging/src/protocol.rs` / `service.rs`: self-hosted begin/append/finish/delete blob commands and progress/ready events.
- `native/telegram-media`: deterministic upload/download transfer scheduler with priority/FIFO ordering, concurrency slots, pause/resume, exact-offset progress, retryable failures, retry counters, cancellation and SHA-256 integrity contracts.
- `MessageContent`: photo/video/animation/audio/voice/video-note/document/sticker payloads; `MediaRef.thumbnail_id` carries thumbnail linkage.

## Product gaps being closed

1. Blob metadata had `content_hash` but finalization did not verify it before making the blob visible.
2. Conversation send permissions existed in the domain model but canonical `QueueMessage` did not enforce membership, `can_send_messages`, `can_send_media`, or `can_send_polls`.
3. No shared bounded media cache index existed for desktop/mobile adapters.
4. `fabushi-telegram-media` transfer contracts were not part of the permanent Messaging Product Gate.
5. M4 had no stage-level acceptance contract tying resumable storage, Range reads, integrity, cache, thumbnail linkage and permission behavior together.

## Acceptance criteria

- interrupted upload resumes from the exact persisted offset;
- final blob publication rejects a mismatching SHA-256 and succeeds for a matching SHA-256;
- bounded Range read returns the requested completed bytes;
- media cache respects a byte budget, deterministically evicts oldest unpinned entries, and preserves `thumbnail_id` metadata;
- non-participants cannot send into a conversation;
- media and polls obey the same canonical conversation permission boundary as messages;
- `fabushi-messaging-core` M4 contract and all `fabushi-telegram-media` tests/clippy are green in GitHub Actions;
- PR #2037 is retargeted to canonical `main` only after M3 lands, merged through protected merge queue, then canonical `main` is re-read.

## Evidence

- Product: `native/mahayana-messaging/src/{blob_store.rs,engine.rs,media_cache.rs}`
- Acceptance: `native/mahayana-messaging/tests/m4_media_contract.rs`
- Existing transfer suite: `native/telegram-media/tests/transfer_queue.rs`
- CI: `.github/workflows/messaging-product-gate.yml`
- PR: #2037

## Completion rule

Code presence is not completion. Keep this task `IN_PROGRESS` until final-head CI, protected merge, canonical-main readback and M4 WBS/evidence closure are recorded.
